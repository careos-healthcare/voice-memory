import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../../api/api_client.dart';
import '../../api/api_exceptions.dart';
import '../../models/journal_entry.dart';
import '../../storage/encrypted_json_file_store.dart';
import '../../storage/journal_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import '../../services/capture_attest_service.dart';
import '../../services/privacy/audio_vault_service.dart';
import '../explainable_conclusion/explainability_history_store.dart';
import '../explainable_conclusion/explainable_conclusion_validator.dart';

typedef CaptureApiRetryClock = DateTime Function();
typedef CaptureApiRetryIdFactory = String Function();
typedef CaptureApiRetryOnlineCheck = Future<bool> Function();
typedef CaptureApiRetryAuthorizationCheck =
    Future<bool> Function(CaptureApiRetryOperation operation);

enum CaptureApiRetryOperation { transcribe, analyze }

enum CaptureApiRetryFailure { retryable, backendNotConfigured, permanent }

final class CaptureApiRetryJob {
  const CaptureApiRetryJob({
    required this.id,
    required this.operation,
    required this.entryId,
    required this.idempotencyKey,
    required this.attempts,
    required this.nextAttemptAt,
    required this.enqueuedAt,
    this.audioBase64,
    this.audioVaultRef,
    this.audioExtension,
    this.durationSeconds,
    this.transcript,
    this.priorEvidence = const [],
  });

  final String id;
  final CaptureApiRetryOperation operation;
  final String entryId;
  final String idempotencyKey;
  final int attempts;
  final DateTime? nextAttemptAt;
  final DateTime enqueuedAt;
  final String? audioBase64;
  final String? audioVaultRef;
  final String? audioExtension;
  final int? durationSeconds;
  final String? transcript;
  final List<Map<String, dynamic>> priorEvidence;

  CaptureApiRetryJob copyWith({
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
  }) => CaptureApiRetryJob(
    id: id,
    operation: operation,
    entryId: entryId,
    idempotencyKey: idempotencyKey,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: clearNextAttemptAt
        ? null
        : (nextAttemptAt ?? this.nextAttemptAt),
    enqueuedAt: enqueuedAt,
    audioBase64: audioBase64,
    audioVaultRef: audioVaultRef,
    audioExtension: audioExtension,
    durationSeconds: durationSeconds,
    transcript: transcript,
    priorEvidence: priorEvidence,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'operation': operation.name,
    'entryId': entryId,
    'idempotencyKey': idempotencyKey,
    'attempts': attempts,
    'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
    'enqueuedAt': enqueuedAt.toUtc().toIso8601String(),
    if (audioBase64 != null) 'audioBase64': audioBase64,
    if (audioVaultRef != null) 'audioVaultRef': audioVaultRef,
    if (audioExtension != null) 'audioExtension': audioExtension,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (transcript != null) 'transcript': transcript,
    if (priorEvidence.isNotEmpty) 'priorEvidence': priorEvidence,
  };

  factory CaptureApiRetryJob.fromJson(Map<String, dynamic> json) {
    final operation = CaptureApiRetryOperation.values
        .where((value) => value.name == json['operation'])
        .firstOrNull;
    final enqueuedAt = DateTime.tryParse(json['enqueuedAt'] as String? ?? '');
    final nextValue = json['nextAttemptAt'];
    final nextAttemptAt = nextValue is String
        ? DateTime.tryParse(nextValue)
        : null;
    final evidenceValue = json['priorEvidence'];
    if (operation == null ||
        json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['entryId'] is! String ||
        (json['entryId'] as String).isEmpty ||
        json['idempotencyKey'] is! String ||
        (json['idempotencyKey'] as String).isEmpty ||
        json['attempts'] is! int ||
        (json['attempts'] as int) < 0 ||
        enqueuedAt == null ||
        (nextValue != null && nextAttemptAt == null)) {
      throw const FormatException('Invalid capture API retry job.');
    }
    final evidence = evidenceValue is List
        ? evidenceValue
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final job = CaptureApiRetryJob(
      id: json['id'] as String,
      operation: operation,
      entryId: json['entryId'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      attempts: json['attempts'] as int,
      nextAttemptAt: nextAttemptAt?.toUtc(),
      enqueuedAt: enqueuedAt.toUtc(),
      audioBase64: json['audioBase64'] as String?,
      audioVaultRef: json['audioVaultRef'] as String?,
      audioExtension: json['audioExtension'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      transcript: json['transcript'] as String?,
      priorEvidence: evidence,
    );
    job._validatePayload();
    return job;
  }

  void _validatePayload() {
    if (operation == CaptureApiRetryOperation.transcribe) {
      final hasEncryptedInlineAudio =
          audioBase64 != null && audioBase64!.isNotEmpty;
      final hasVaultAudio =
          audioVaultRef != null && audioVaultRef!.trim().isNotEmpty;
      if (hasEncryptedInlineAudio == hasVaultAudio ||
          durationSeconds == null ||
          durationSeconds! < 1) {
        throw const FormatException('Invalid transcription retry payload.');
      }
      if (hasEncryptedInlineAudio) base64Decode(audioBase64!);
    } else if (transcript == null || transcript!.trim().isEmpty) {
      throw const FormatException('Invalid analysis retry payload.');
    }
  }
}

/// Durable encrypted queue for capture API requests only.
///
/// Capture tokens are intentionally absent from [CaptureApiRetryJob] and are
/// minted immediately before each execution.
class CaptureApiRetryQueue {
  CaptureApiRetryQueue({
    required File manifestFile,
    required PrivateDataEncryptionKeyStore keyStore,
    required VoiceCaptureApiClient api,
    required CaptureAttestService attest,
    required JournalStore journalStore,
    ExplainabilityHistoryStore? explainabilityHistoryStore,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    CaptureApiRetryOnlineCheck? isOnline,
    Future<bool> Function()? canDrain,
    CaptureApiRetryAuthorizationCheck? isRemoteOperationAuthorized,
    CaptureApiRetryClock? clock,
    CaptureApiRetryIdFactory? idFactory,
    Future<void> Function()? onRetryScheduled,
    AudioVaultService? audioVault,
    Random? random,
    this.baseBackoff = const Duration(seconds: 5),
    this.maxBackoff = const Duration(hours: 1),
  }) : _store = EncryptedJsonFileStore(file: manifestFile, keyStore: keyStore),
       // Public named parameters cannot use private field names.
       // ignore: prefer_initializing_formals
       _api = api,
       // ignore: prefer_initializing_formals
       _attest = attest,
       // ignore: prefer_initializing_formals
       _journalStore = journalStore,
       // Public named parameters cannot use private field names.
       // ignore: prefer_initializing_formals
       _explainabilityHistoryStore = explainabilityHistoryStore,
       _isOnline =
           isOnline ??
           (() async {
             final values = await Connectivity().checkConnectivity();
             return values.any((value) => value != ConnectivityResult.none);
           }),
       _canDrain = canDrain ?? (() async => true),
       _isRemoteOperationAuthorized =
           isRemoteOperationAuthorized ?? ((_) async => false),
       _clock = clock ?? DateTime.now,
       // ignore: prefer_initializing_formals
       _idFactory = idFactory,
       // ignore: prefer_initializing_formals
       _onRetryScheduled = onRetryScheduled,
       // Public named parameters cannot expose a private field name.
       // ignore: prefer_initializing_formals
       _audioVault = audioVault,
       _random = random ?? Random.secure() {
    _connectivitySubscription = connectivityChanges?.listen(
      _onConnectivityChanged,
    );
  }

  static const manifestVersion = 1;
  static const maxAudioBytes = 25 * 1024 * 1024;

  final EncryptedJsonFileStore _store;
  final VoiceCaptureApiClient _api;
  final CaptureAttestService _attest;
  final JournalStore _journalStore;
  final ExplainabilityHistoryStore? _explainabilityHistoryStore;
  final CaptureApiRetryOnlineCheck _isOnline;
  final Future<bool> Function() _canDrain;
  final CaptureApiRetryAuthorizationCheck _isRemoteOperationAuthorized;
  final CaptureApiRetryClock _clock;
  final CaptureApiRetryIdFactory? _idFactory;
  final Future<void> Function()? _onRetryScheduled;
  final AudioVaultService? _audioVault;
  final Random _random;
  final Duration baseBackoff;
  final Duration maxBackoff;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<CaptureApiRetryJob>? _jobs;
  Future<void> _stateTail = Future<void>.value();
  Future<void>? _drainFuture;
  bool _disposed = false;

  Future<List<CaptureApiRetryJob>> get jobs async =>
      List<CaptureApiRetryJob>.unmodifiable(
        await _withStateLock(() async {
          await _ensureLoaded();
          return List<CaptureApiRetryJob>.from(_jobs!);
        }),
      );

  /// Irreversibly removes all pending encrypted retry payloads.
  Future<void> clear() => _withStateLock(() async {
    _checkNotDisposed();
    await _ensureLoaded();
    _jobs!.clear();
    await _persist();
  });

  Future<bool> enqueueTranscribe({
    required String entryId,
    required File audioFile,
    required int durationSeconds,
    required String idempotencyKey,
  }) async {
    _checkNotDisposed();
    final size = await audioFile.length();
    if (size <= 0 || size > maxAudioBytes) {
      throw ArgumentError.value(
        size,
        'audioFile',
        'retry audio must be 1-$maxAudioBytes bytes',
      );
    }
    final bytes = await audioFile.readAsBytes();
    final extension = audioFile.path.contains('.')
        ? audioFile.path.split('.').last.toLowerCase()
        : 'm4a';
    return _enqueue(
      CaptureApiRetryJob(
        id: _newId(),
        operation: CaptureApiRetryOperation.transcribe,
        entryId: entryId,
        idempotencyKey: idempotencyKey,
        attempts: 0,
        nextAttemptAt: null,
        enqueuedAt: _clock().toUtc(),
        audioBase64: base64Encode(bytes),
        audioExtension: extension,
        durationSeconds: durationSeconds,
      ),
    );
  }

  Future<bool> enqueueTranscribeVault({
    required String entryId,
    required String vaultReference,
    required int durationSeconds,
    required String idempotencyKey,
  }) {
    if (vaultReference.trim().isEmpty) {
      throw ArgumentError.value(
        vaultReference,
        'vaultReference',
        'must not be empty',
      );
    }
    return _enqueue(
      CaptureApiRetryJob(
        id: _newId(),
        operation: CaptureApiRetryOperation.transcribe,
        entryId: entryId,
        idempotencyKey: idempotencyKey,
        attempts: 0,
        nextAttemptAt: null,
        enqueuedAt: _clock().toUtc(),
        audioVaultRef: vaultReference,
        durationSeconds: durationSeconds,
      ),
    );
  }

  Future<bool> enqueueAnalyze({
    required String entryId,
    required String transcript,
    required String idempotencyKey,
    List<Map<String, dynamic>> priorEvidence = const [],
  }) => _enqueue(
    CaptureApiRetryJob(
      id: _newId(),
      operation: CaptureApiRetryOperation.analyze,
      entryId: entryId,
      idempotencyKey: idempotencyKey,
      attempts: 0,
      nextAttemptAt: null,
      enqueuedAt: _clock().toUtc(),
      transcript: transcript.trim(),
      priorEvidence: priorEvidence
          .map((value) => Map<String, dynamic>.from(value))
          .toList(growable: false),
    ),
  );

  Future<bool> _enqueue(CaptureApiRetryJob job) async {
    final added = await _withStateLock(() async {
      _checkNotDisposed();
      job._validatePayload();
      await _ensureLoaded();
      final duplicate = _jobs!.any(
        (existing) =>
            existing.operation == job.operation &&
            existing.entryId == job.entryId &&
            existing.idempotencyKey == job.idempotencyKey,
      );
      if (duplicate) return false;
      _jobs!.add(job);
      await _persist();
      return true;
    });
    if (added) {
      try {
        await _onRetryScheduled?.call();
      } on Object {
        // The encrypted manifest remains authoritative if OS scheduling fails.
      }
    }
    return added;
  }

  /// Processes each currently eligible job once. Concurrent drains coalesce.
  Future<void> drain() {
    if (_disposed) return Future<void>.value();
    final active = _drainFuture;
    if (active != null) return active;
    final future = _runDrain();
    _drainFuture = future;
    return future.whenComplete(() {
      if (identical(_drainFuture, future)) _drainFuture = null;
    });
  }

  Future<void> _runDrain() async {
    if (!await _canDrain() || !await _isOnline()) return;
    final attemptedIds = <String>{};
    while (!_disposed) {
      final now = _clock().toUtc();
      final eligible = (await jobs)
          .where(
            (job) =>
                !attemptedIds.contains(job.id) &&
                (job.nextAttemptAt == null || !job.nextAttemptAt!.isAfter(now)),
          )
          .firstOrNull;
      if (eligible == null) return;
      attemptedIds.add(eligible.id);
      final entry = await _journalStore.getById(eligible.entryId);
      if (entry == null) {
        await _remove(eligible.id);
        continue;
      }
      if (eligible.operation == CaptureApiRetryOperation.analyze &&
          (eligible.transcript != entry.transcript ||
              entry.reflection.explainableConclusion != null)) {
        // Transcript edits invalidate the queued evidence offsets and a
        // foreground success makes the retry redundant. Drop either payload
        // before authorization or network execution.
        await _remove(eligible.id);
        continue;
      }
      if (!await _isAuthorized(eligible.operation)) {
        // Consent was withdrawn or the active archive changed. The encrypted
        // retry payload is discarded, but the already-saved original remains
        // authoritative in the journal.
        await _remove(eligible.id);
        continue;
      }
      try {
        await _execute(eligible, entry);
        await _remove(eligible.id);
      } on Object catch (error) {
        final failure = classifyCaptureApiRetryFailure(error);
        if (failure == CaptureApiRetryFailure.permanent) {
          await _remove(eligible.id);
          continue;
        }
        final attempts = eligible.attempts + 1;
        await _reschedule(
          eligible.id,
          attempts: attempts,
          nextAttemptAt: _clock().toUtc().add(_backoff(attempts)),
        );
      }
    }
  }

  Future<bool> _isAuthorized(CaptureApiRetryOperation operation) async {
    try {
      return await _isRemoteOperationAuthorized(operation);
    } on Object {
      return false;
    }
  }

  Future<void> _execute(CaptureApiRetryJob job, JournalEntry entry) async {
    var token = await _attest.ensureCaptureToken();
    try {
      await _executeWithToken(job, entry, token);
    } on AuthRequiredException {
      token = await _attest.ensureCaptureToken(forceRefresh: true);
      await _executeWithToken(job, entry, token);
    }
  }

  Future<void> _executeWithToken(
    CaptureApiRetryJob job,
    JournalEntry entry,
    String token,
  ) async {
    switch (job.operation) {
      case CaptureApiRetryOperation.transcribe:
        final vaultReference = job.audioVaultRef?.trim();
        if (vaultReference != null && vaultReference.isNotEmpty) {
          final vault = _audioVault;
          if (vault == null) {
            throw const AudioVaultException('Audio vault is unavailable.');
          }
          await vault.withDecryptedFile(vaultReference, (file) async {
            await _transcribeAndPersist(job, entry, token, file);
          });
          break;
        }
        final tempDirectory = await Directory.systemTemp.createTemp(
          'capture_api_retry_',
        );
        final file = File(
          '${tempDirectory.path}/recording.${job.audioExtension ?? 'm4a'}',
        );
        try {
          await file.writeAsBytes(base64Decode(job.audioBase64!), flush: true);
          await _transcribeAndPersist(job, entry, token, file);
          break;
        } finally {
          if (await file.exists()) {
            final vault = _audioVault;
            if (vault != null) {
              await vault.secureDeletePlaintext(file);
            } else {
              await _overwriteAndDelete(file);
            }
          }
          if (await tempDirectory.exists()) {
            await tempDirectory.delete(recursive: true);
          }
        }
      case CaptureApiRetryOperation.analyze:
        final reflection = await _api.postAnalyze(
          transcript: job.transcript!,
          captureToken: token,
          priorEvidence: job.priorEvidence,
          idempotencyKey: job.idempotencyKey,
          entryId: entry.id,
        );
        final latest = await _journalStore.getById(entry.id);
        if (latest == null ||
            latest.ownerArchiveId != _journalStore.ownerArchiveId ||
            latest.isDeleted ||
            latest.isArchived ||
            latest.transcript != job.transcript ||
            latest.updatedAt != entry.updatedAt ||
            latest.reflection.explainableConclusion != null) {
          // Authorization and evidence validity can change while the request
          // is in flight. Never attach a response to a different revision,
          // owner, lifecycle state, or already-completed moment.
          break;
        }
        final validatedReflection = reflection.validatedForPersistence(
          transcript: latest.transcript,
          entryId: latest.id,
        );
        final updated = JournalEntry.fromJson({
          ...latest.toJson(),
          'reflection': validatedReflection.toJson(),
        });
        await _journalStore.save(
          updated,
          first25Source: 'capture_api_retry_analyze',
        );
        final conclusion = updated.reflection.explainableConclusion;
        final historyStore = _explainabilityHistoryStore;
        if (conclusion != null &&
            conclusion.provenance.generatedBy == 'model' &&
            historyStore != null) {
          final gated = ExplainableConclusionRenderGate.visible(
            conclusion,
            canonicalTranscripts: {updated.id: updated.transcript},
          );
          if (gated != null) {
            try {
              await historyStore.appendIfAbsent(gated);
            } on Object {
              // The enriched journal entry is already durable. History can
              // be reconstructed idempotently from that persisted proof.
            }
          }
        }
        break;
    }
    _attest.clearToken();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (results.any((value) => value != ConnectivityResult.none)) {
      unawaited(drain());
    }
  }

  Future<void> _transcribeAndPersist(
    CaptureApiRetryJob job,
    JournalEntry entry,
    String token,
    File file,
  ) async {
    final transcript = await _api.postTranscribe(
      audioFile: file,
      durationSeconds: job.durationSeconds!,
      captureToken: token,
      idempotencyKey: job.idempotencyKey,
    );
    final updated = JournalEntry.fromJson({
      ...entry.toJson(),
      'transcript': transcript,
    });
    await _journalStore.save(
      updated,
      first25Source: 'capture_api_retry_transcribe',
    );
    // Interpretation is deliberately not chained here. A recovered transcript
    // must be reviewed before the canonical interpretation coordinator may
    // obtain its separate choice and disclosure.
  }

  Duration _backoff(int attempts) {
    final exponent = min(attempts - 1, 20);
    final jitter = 0.75 + (_random.nextDouble() * 0.5);
    final milliseconds = baseBackoff.inMilliseconds * (1 << exponent) * jitter;
    return Duration(
      milliseconds: min(milliseconds.round(), maxBackoff.inMilliseconds),
    );
  }

  Future<void> _remove(String id) => _withStateLock(() async {
    await _ensureLoaded();
    final previousLength = _jobs!.length;
    _jobs!.removeWhere((job) => job.id == id);
    if (_jobs!.length != previousLength) await _persist();
  });

  Future<void> _reschedule(
    String id, {
    required int attempts,
    required DateTime nextAttemptAt,
  }) => _withStateLock(() async {
    await _ensureLoaded();
    final index = _jobs!.indexWhere((job) => job.id == id);
    if (index < 0) return;
    _jobs![index] = _jobs![index].copyWith(
      attempts: attempts,
      nextAttemptAt: nextAttemptAt,
    );
    await _persist();
  });

  Future<void> _ensureLoaded() async {
    if (_jobs != null) return;
    try {
      final value = await _store.readJson();
      if (value == null) {
        _jobs = <CaptureApiRetryJob>[];
        return;
      }
      final manifest = Map<String, dynamic>.from(value as Map);
      if (manifest['version'] != manifestVersion || manifest['jobs'] is! List) {
        throw const FormatException();
      }
      final loaded = (manifest['jobs'] as List)
          .map(
            (value) => CaptureApiRetryJob.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: true);
      final dedupeKeys = <String>{};
      final ids = <String>{};
      for (final job in loaded) {
        final key =
            '${job.operation.name}\u0000${job.entryId}\u0000${job.idempotencyKey}';
        if (!ids.add(job.id) || !dedupeKeys.add(key)) {
          throw const FormatException();
        }
      }
      _jobs = loaded;
    } on Object {
      throw const FormatException('Invalid encrypted capture retry manifest.');
    }
  }

  Future<void> _persist() => _store.writeJson(<String, Object>{
    'version': manifestVersion,
    'jobs': _jobs!.map((job) => job.toJson()).toList(growable: false),
  });

  Future<T> _withStateLock<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _stateTail = _stateTail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  String _newId() {
    final supplied = _idFactory?.call();
    if (supplied != null) {
      if (supplied.isEmpty) throw StateError('Queue id cannot be empty.');
      return supplied;
    }
    return List<String>.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('Capture API retry queue is disposed.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _connectivitySubscription?.cancel();
    await _drainFuture;
  }

  static Future<void> _overwriteAndDelete(File file) async {
    try {
      final length = await file.length();
      final handle = await file.open(mode: FileMode.write);
      try {
        const zeros = <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        var remaining = length;
        while (remaining > 0) {
          final count = min(remaining, zeros.length);
          await handle.writeFrom(zeros, 0, count);
          remaining -= count;
        }
        await handle.flush();
      } finally {
        await handle.close();
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}

CaptureApiRetryFailure classifyCaptureApiRetryFailure(Object error) {
  if (error is BackendNotConfiguredException) {
    return CaptureApiRetryFailure.backendNotConfigured;
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is NetworkOfflineException ||
      error is ConnectivityException ||
      error is RequestTimeoutException ||
      error is http.ClientException) {
    return CaptureApiRetryFailure.retryable;
  }
  if (error is ApiException) {
    final status = error.statusCode;
    if (status == 408 ||
        status == 429 ||
        (status != null && status >= 500 && status <= 599)) {
      return CaptureApiRetryFailure.retryable;
    }
  }
  return CaptureApiRetryFailure.permanent;
}
