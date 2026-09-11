import 'dart:io';

import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/belief_evidence/provenance_recovery/provenance_recovery_port.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcript_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Re-reads saved audio and restamps [TranscriptProvenance.speechToText]
/// when the new reading matches the stored transcript.
///
/// This does **not** call `ProvisionalTranscriptReconciler.reconcileEntry`.
/// That path rewrites transcript text and status for provisional rows; this
/// one only attributes an already-stored transcript when a fresh STT pass
/// agrees with it.
class ProvenanceRecoveryAdapter implements ProvenanceRecoveryPort {
  ProvenanceRecoveryAdapter({
    required this.journalStore,
    required this.captureRepository,
    required this.attest,
    required this.usageGuard,
    required this.consentGate,
  });

  /// Production composition: journal / attest / gate from [AppServices],
  /// [CaptureRepository] from [boundAppProviderContainer] when bound,
  /// otherwise from the capture pipeline already held on AppServices.
  ///
  /// Returns null when the composition root is not up so callers can fall
  /// back to [UnwiredProvenanceRecoveryPort].
  static ProvenanceRecoveryAdapter? tryFromBoundServices() {
    try {
      if (!AppServices.isInitialized) return null;
      final services = AppServices.instance;
      final container = boundAppProviderContainer;
      final captureRepository = container != null
          ? container.read(captureRepositoryProvider)
          : services.pipeline.dependencies.captureRepository;
      return ProvenanceRecoveryAdapter(
        journalStore: services.journalStore,
        captureRepository: captureRepository,
        attest: services.attest,
        usageGuard: services.pipeline.dependencies.usageGuard,
        consentGate: services.remoteProcessingConsentGate,
      );
    } on Object {
      // ignore: silent_catch_audit — missing composition root must fail
      // closed rather than throw into a confirm tap.
      return null;
    }
  }

  final JournalStore journalStore;
  final CaptureRepository captureRepository;
  final CaptureAttestService attest;
  final ApiUsageGuard usageGuard;
  final RemoteProcessingConsentGate consentGate;

  @override
  Future<ProvenanceRecoveryOutcome> recover(List<String> entryIds) async {
    var recoveredCount = 0;
    for (final entryId in entryIds) {
      try {
        if (await _recoverEntry(entryId)) {
          recoveredCount++;
        }
      } on Object {
        // ignore: silent_catch_audit — one entry must not abort the batch
        // or leave a half-applied restamp behind a thrown error.
      }
    }
    return ProvenanceRecoveryOutcome(
      requestedCount: entryIds.length,
      recoveredCount: recoveredCount,
    );
  }

  Future<bool> _recoverEntry(String entryId) async {
    final entry = await journalStore.getById(entryId);
    if (entry == null) return false;

    // User-authored text is already attributed. Never re-transcribe it and
    // never overwrite that stamp with a server reading.
    if (entry.transcriptProvenance == TranscriptProvenance.userEdited) {
      return false;
    }

    if (entry.transcriptProvenance == TranscriptProvenance.speechToText) {
      return false;
    }

    final audioFile = await _resolveAudioFile(entry.localAudioPath);
    if (audioFile == null) return false;

    final fresh = await _transcribe(entry, audioFile);
    if (fresh == null) return false;
    if (!_transcriptsMatch(entry.transcript, fresh)) return false;

    final updated = entry.copyWith(
      transcriptProvenance: TranscriptProvenance.speechToText,
    );
    await journalStore.save(updated, first25Source: 'provenance_recovery');
    return true;
  }

  /// Both gates that stand between stored audio and a third-party transcriber.
  ///
  /// Copied from the reconciler's time-of-use check so this path cannot
  /// drift from `RemoteProcessingConsentGate` / the on-device-only switch.
  Future<bool> _remoteTranscriptionAllowed() => consentGate
      .isPurposePermittedNow(RemoteProcessingPurpose.remoteTranscription);

  Future<String?> _transcribe(JournalEntry entry, File audioFile) async {
    if (!await _remoteTranscriptionAllowed()) return null;

    final scopeKey = 'provenance_recovery:${entry.id}';
    final guard = usageGuard.checkAttempt(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.transcribe,
    );
    if (!guard.allowed) return null;

    final idempotencyKey = usageGuard.idempotencyKey(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.transcribe,
    );

    try {
      var token = await attest.ensureCaptureToken();
      var result = await captureRepository.postTranscribe(
        audioFile: audioFile,
        durationSeconds: entry.durationSeconds,
        captureToken: token,
        idempotencyKey: idempotencyKey,
      );

      if (result case ApiFailureResult(
        :final failure,
      ) when failure is ApiFailureAuthRequired) {
        token = await attest.ensureCaptureToken(forceRefresh: true);
        result = await captureRepository.postTranscribe(
          audioFile: audioFile,
          durationSeconds: entry.durationSeconds,
          captureToken: token,
          idempotencyKey: idempotencyKey,
        );
      }

      if (result is ApiSuccess<String>) {
        final trimmed = result.value.trim();
        final quality = TranscriptQuality.evaluate(trimmed);
        if (!quality.isValid) return null;
        usageGuard.recordAttempt(
          scopeKey: scopeKey,
          operation: ApiUsageOperation.transcribe,
          success: true,
        );
        return trimmed;
      }

      usageGuard.recordAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.transcribe,
        success: false,
      );
      return null;
    } on Object {
      // ignore: silent_catch_audit — token or transport failure leaves the
      // entry untouched and the batch continues.
      return null;
    }
  }

  Future<File?> _resolveAudioFile(String? path) async {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final file = File(trimmed);
    if (!file.existsSync()) return null;
    return file;
  }

  /// STT commonly drifts in capitalization and whitespace around the same
  /// words. Normalize those so a genuine re-read can restamp. Do not strip
  /// punctuation or use edit-distance: that could promote contaminated
  /// model text as a match.
  static bool _transcriptsMatch(String stored, String fresh) {
    return _normalizeForCompare(stored) == _normalizeForCompare(fresh);
  }

  static String _normalizeForCompare(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}
