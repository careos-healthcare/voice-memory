import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../features/local_backup/local_backup_builder.dart';
import '../../features/local_backup/local_backup_model.dart';
import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';
import '../transcription_queue/transcription_job.dart';
import '../transcription_queue/transcription_ledger.dart';
import 'disaster_recovery_core.dart';

final class AppDisasterRecoverySource implements DisasterRecoverySource {
  const AppDisasterRecoverySource({
    required this.journal,
    required this.prefs,
    required this.ledger,
  });

  final JournalStore journal;
  final MobilePrefsStore prefs;
  final TranscriptionLedger ledger;

  @override
  Future<List<RecoveryInput>> readNormalizedInputs() async {
    final backupJson = await LocalBackupBuilder.buildJson(
      journal: journal,
      prefs: prefs,
    );
    final portable = jsonDecode(backupJson) as Map<String, dynamic>;
    final inputs = <RecoveryInput>[
      RecoveryInput(
        kind: RecoveryDataKind.journal,
        logicalPath: 'journal.json',
        bytes: utf8.encode(jsonEncode(portable['journal_entries'] ?? [])),
      ),
      RecoveryInput(
        kind: RecoveryDataKind.preferences,
        logicalPath: 'preferences.json',
        bytes: utf8.encode(jsonEncode(portable['prefs'] ?? {})),
      ),
    ];
    final jobs = <Map<String, dynamic>>[];
    for (final job in ledger.jobs) {
      final audio = File(job.audioPath);
      final audioName = path.basename(job.audioPath);
      final hasAudio = await audio.exists();
      jobs.add(_jobToJson(job, hasAudio ? audioName : null));
      if (hasAudio) {
        inputs.add(
          RecoveryInput(
            kind: RecoveryDataKind.audio,
            logicalPath: audioName,
            bytes: await audio.readAsBytes(),
          ),
        );
      }
    }
    inputs.add(
      RecoveryInput(
        kind: RecoveryDataKind.ledger,
        logicalPath: 'ledger.json',
        bytes: utf8.encode(jsonEncode(jobs)),
      ),
    );
    return inputs;
  }
}

final class AppDisasterRecoverySink implements DisasterRecoverySink {
  const AppDisasterRecoverySink({
    required this.journal,
    required this.prefs,
    required this.ledger,
  });

  final JournalStore journal;
  final MobilePrefsStore prefs;
  final TranscriptionLedger ledger;

  @override
  Future<DisasterRecoveryImportTransaction> beginStagedImport() async {
    return _AppRecoveryTransaction.create(
      journal: journal,
      prefs: prefs,
      ledger: ledger,
    );
  }
}

final class _AppRecoveryTransaction
    implements DisasterRecoveryImportTransaction {
  _AppRecoveryTransaction._({
    required this.journal,
    required this.prefs,
    required this.ledger,
    required this.staging,
    required this.originalEntries,
    required this.originalPrefs,
    required this.originalJobs,
  });

  final JournalStore journal;
  final MobilePrefsStore prefs;
  final TranscriptionLedger ledger;
  final Directory staging;
  final List<JournalEntry> originalEntries;
  final Map<String, dynamic> originalPrefs;
  final List<TranscriptionJob> originalJobs;
  final Map<RecoveryDataKind, List<RecoveryInput>> _staged = {};
  bool _committed = false;

  static Future<_AppRecoveryTransaction> create({
    required JournalStore journal,
    required MobilePrefsStore prefs,
    required TranscriptionLedger ledger,
  }) async {
    final portable =
        jsonDecode(
              await LocalBackupBuilder.buildJson(
                journal: journal,
                prefs: prefs,
              ),
            )
            as Map<String, dynamic>;
    final staging = await Directory.systemTemp.createTemp('archive_recovery_');
    final rollbackAudio = Directory(path.join(staging.path, 'rollback_audio'));
    await rollbackAudio.create(recursive: true);
    for (final job in ledger.jobs) {
      final source = File(job.audioPath);
      if (await source.exists()) {
        await source.copy(
          path.join(rollbackAudio.path, path.basename(job.audioPath)),
        );
      }
    }
    return _AppRecoveryTransaction._(
      journal: journal,
      prefs: prefs,
      ledger: ledger,
      staging: staging,
      originalEntries: await journal.loadAll(),
      originalPrefs: Map<String, dynamic>.from(portable['prefs'] as Map? ?? {}),
      originalJobs: List<TranscriptionJob>.from(ledger.jobs),
    );
  }

  @override
  Future<void> stage(RecoveryInput input) async {
    (_staged[input.kind] ??= []).add(input);
  }

  @override
  Future<void> commit() async {
    final journalInput = _single(RecoveryDataKind.journal);
    final prefsInput = _single(RecoveryDataKind.preferences);
    final ledgerInput = _single(RecoveryDataKind.ledger);
    final entries = (jsonDecode(utf8.decode(journalInput.bytes)) as List)
        .map((value) => JournalEntry.fromJson(Map<String, dynamic>.from(value)))
        .toList(growable: false);
    final restoredPrefs = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(prefsInput.bytes)) as Map,
    );

    await _clearQueueAudio();
    for (final audio in _staged[RecoveryDataKind.audio] ?? const []) {
      await File(
        path.join(ledger.audioDirectory.path, audio.logicalPath),
      ).writeAsBytes(audio.bytes, flush: true);
    }
    final restoredJobs = (jsonDecode(utf8.decode(ledgerInput.bytes)) as List)
        .map(
          (value) => _jobFromJson(
            Map<String, dynamic>.from(value),
            ledger.audioDirectory.path,
          ),
        )
        .toList(growable: false);

    await journal.replaceAll(entries);
    await _replacePrefs(restoredPrefs);
    ledger.replaceAll(restoredJobs);
    if (!ledger.checkIntegrity().isHealthy) {
      throw StateError('Restored transcription ledger failed integrity check.');
    }
    await staging.delete(recursive: true);
    _committed = true;
  }

  @override
  Future<void> rollback() async {
    if (_committed) return;
    await journal.replaceAll(originalEntries);
    await _replacePrefs(originalPrefs);
    ledger.replaceAll(originalJobs);
    await _clearQueueAudio();
    final rollbackAudio = Directory(path.join(staging.path, 'rollback_audio'));
    if (await rollbackAudio.exists()) {
      await for (final entity in rollbackAudio.list()) {
        if (entity is File) {
          await entity.copy(
            path.join(ledger.audioDirectory.path, path.basename(entity.path)),
          );
        }
      }
    }
    if (await staging.exists()) await staging.delete(recursive: true);
  }

  RecoveryInput _single(RecoveryDataKind kind) {
    final values = _staged[kind] ?? const [];
    if (values.length != 1) throw StateError('Missing staged ${kind.name}.');
    return values.single;
  }

  Future<void> _replacePrefs(Map<String, dynamic> values) async {
    for (final key in LocalArchiveBackupPrefsKeys.included) {
      final value = values[key];
      if (value is Map) {
        await prefs.writeJsonMap(key, Map<String, dynamic>.from(value));
      } else {
        await prefs.writeJsonMap(key, {});
      }
    }
  }

  Future<void> _clearQueueAudio() async {
    if (!await ledger.audioDirectory.exists()) return;
    await for (final entity in ledger.audioDirectory.list()) {
      if (entity is File) await entity.delete();
    }
  }
}

Map<String, dynamic> _jobToJson(TranscriptionJob job, String? audioName) => {
  'id': job.id,
  'entryId': job.entryId,
  'audioName': audioName,
  'sourceFileName': job.sourceFileName,
  'durationSeconds': job.durationSeconds,
  'status': job.status.storageValue,
  'createdAt': job.createdAt.toIso8601String(),
  'updatedAt': job.updatedAt.toIso8601String(),
  'attemptCount': job.attemptCount,
  'nextAttemptAt': job.nextAttemptAt?.toIso8601String(),
  'lastError': job.lastError,
  'transcript': job.transcript,
  'completedAt': job.completedAt?.toIso8601String(),
};

TranscriptionJob _jobFromJson(Map<String, dynamic> json, String audioRoot) {
  final audioName = json['audioName'] as String?;
  final status = TranscriptionJobStatus.fromStorage(json['status'] as String);
  final restoredStatus =
      status == TranscriptionJobStatus.processing && audioName != null
      ? TranscriptionJobStatus.queued
      : status;
  return TranscriptionJob(
    id: json['id'] as String,
    entryId: json['entryId'] as String,
    audioPath: path.join(audioRoot, audioName ?? '${json['id']}.missing'),
    sourceFileName: json['sourceFileName'] as String,
    durationSeconds: json['durationSeconds'] as int,
    status: restoredStatus,
    createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    attemptCount: json['attemptCount'] as int,
    nextAttemptAt: _date(json['nextAttemptAt']),
    lastError: json['lastError'] as String?,
    transcript: json['transcript'] as String?,
    completedAt: _date(json['completedAt']),
  );
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value).toUtc() : null;
