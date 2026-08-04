import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/disaster_recovery/disaster_recovery.dart';
import 'package:voicememory_mobile/features/local_backup/local_backup_model.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_queue.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/local_capture_context.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'offline encrypted export restores fresh production stores exactly',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'disaster_recovery_fresh_stores_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final source = await _Stores.open(root, 'source', jobId: 'source-job');
      final destination = await _Stores.open(
        root,
        'destination',
        jobId: 'unused-destination-job',
      );
      addTearDown(destination.ledger.close);
      addTearDown(source.ledger.close);

      final entry = _entry(
        'offline-entry',
        transcript: 'Offline exact thought',
      );
      await source.journal.save(entry);
      final persistedSourceEntry = (await source.journal.loadAll()).single;
      final prefsKey = LocalArchiveBackupPrefsKeys.entryImportance;
      final prefsValue = {
        'offline-entry': {'importance': 'high', 'localOnly': true},
      };
      await source.prefs.writeJsonMap(prefsKey, prefsValue);
      final audioBytes = List<int>.generate(
        16384,
        (index) => (index * 31) % 256,
      );
      final recording = File('${root.path}/offline-recording.wav');
      await recording.writeAsBytes(audioBytes, flush: true);
      final sourceJob = await source.ledger.enqueue(
        recording,
        durationSeconds: 37,
        entryId: entry.id,
      );

      final core = DisasterRecoveryCore(
        zipCodec: const ArchiveDisasterRecoveryZipCodec(),
        random: Random(101),
      );
      final envelope = await core.export(
        passphrase: 'deterministic offline recovery phrase',
        source: AppDisasterRecoverySource(
          journal: source.journal,
          prefs: source.prefs,
          ledger: source.ledger,
        ),
      );

      expect(
        utf8.decode(envelope.toBytes()),
        isNot(contains(entry.transcript)),
      );
      expect(utf8.decode(envelope.toBytes()), isNot(contains('importance')));
      await core.import(
        envelopeBytes: envelope.toBytes(),
        passphrase: 'deterministic offline recovery phrase',
        sink: AppDisasterRecoverySink(
          journal: destination.journal,
          prefs: destination.prefs,
          ledger: destination.ledger,
        ),
      );

      final restoredEntry = (await destination.journal.loadAll()).single;
      expect(restoredEntry.toJson(), persistedSourceEntry.toJson());
      expect(await destination.prefs.readJsonMap(prefsKey), prefsValue);
      final restoredJob = destination.ledger.jobs.single;
      expect(restoredJob.id, sourceJob.id);
      expect(restoredJob.entryId, sourceJob.entryId);
      expect(restoredJob.sourceFileName, sourceJob.sourceFileName);
      expect(restoredJob.durationSeconds, sourceJob.durationSeconds);
      expect(restoredJob.status, sourceJob.status);
      expect(restoredJob.createdAt, sourceJob.createdAt);
      expect(restoredJob.updatedAt, sourceJob.updatedAt);
      expect(restoredJob.attemptCount, sourceJob.attemptCount);
      expect(await File(restoredJob.audioPath).readAsBytes(), audioBytes);
      expect(destination.ledger.checkIntegrity().isHealthy, isTrue);
    },
  );

  test(
    'wrong passphrase, tampering, and interrupted commit preserve destination',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'disaster_recovery_atomicity_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final source = await _Stores.open(root, 'source', jobId: 'source-job');
      final destination = await _Stores.open(
        root,
        'destination',
        jobId: 'destination-job',
      );
      addTearDown(destination.ledger.close);
      addTearDown(source.ledger.close);

      await source.journal.save(_entry('source-entry'));
      final sourceAudio = File('${root.path}/source.wav');
      await sourceAudio.writeAsBytes([1, 2, 3, 4], flush: true);
      await source.ledger.enqueue(sourceAudio, entryId: 'source-entry');

      final destinationEntry = _entry(
        'destination-entry',
        transcript: 'must survive every failed import',
      );
      await destination.journal.save(destinationEntry);
      final prefsKey = LocalArchiveBackupPrefsKeys.patternNames;
      const destinationPrefs = {'pattern': 'preserve-me'};
      await destination.prefs.writeJsonMap(prefsKey, destinationPrefs);
      final destinationAudioBytes = List<int>.generate(
        3072,
        (index) => (index * 13) % 256,
      );
      final destinationAudio = File('${root.path}/destination.wav');
      await destinationAudio.writeAsBytes(destinationAudioBytes, flush: true);
      await destination.ledger.enqueue(
        destinationAudio,
        durationSeconds: 19,
        entryId: destinationEntry.id,
      );
      final before = await _StoreSnapshot.capture(
        destination,
        prefsKey: prefsKey,
      );

      final core = DisasterRecoveryCore(
        zipCodec: const ArchiveDisasterRecoveryZipCodec(),
        random: Random(202),
      );
      final validEnvelope = await core.export(
        passphrase: 'correct recovery phrase',
        source: AppDisasterRecoverySource(
          journal: source.journal,
          prefs: source.prefs,
          ledger: source.ledger,
        ),
      );
      final sink = AppDisasterRecoverySink(
        journal: destination.journal,
        prefs: destination.prefs,
        ledger: destination.ledger,
      );

      await expectLater(
        core.import(
          envelopeBytes: validEnvelope.toBytes(),
          passphrase: 'wrong recovery phrase',
          sink: sink,
        ),
        throwsA(isA<DisasterRecoveryAuthenticationException>()),
      );
      await before.expectUnchanged(destination, prefsKey: prefsKey);

      final tamperedCiphertext = List<int>.from(validEnvelope.ciphertext);
      tamperedCiphertext[tamperedCiphertext.length ~/ 2] ^= 0x01;
      final tamperedEnvelope = DisasterRecoveryEnvelope(
        version: validEnvelope.version,
        cipher: validEnvelope.cipher,
        kdf: validEnvelope.kdf,
        salt: validEnvelope.salt,
        nonce: validEnvelope.nonce,
        ciphertext: tamperedCiphertext,
        mac: validEnvelope.mac,
      );
      await expectLater(
        core.import(
          envelopeBytes: tamperedEnvelope.toBytes(),
          passphrase: 'correct recovery phrase',
          sink: sink,
        ),
        throwsA(isA<DisasterRecoveryAuthenticationException>()),
      );
      await before.expectUnchanged(destination, prefsKey: prefsKey);

      final interruptedEnvelope = await core.export(
        passphrase: 'correct recovery phrase',
        source: _InvalidLedgerRecoverySource(),
      );
      await expectLater(
        core.import(
          envelopeBytes: interruptedEnvelope.toBytes(),
          passphrase: 'correct recovery phrase',
          sink: sink,
        ),
        throwsA(anything),
      );
      await before.expectUnchanged(destination, prefsKey: prefsKey);
    },
  );
}

final class _Stores {
  const _Stores({
    required this.journal,
    required this.prefs,
    required this.ledger,
  });

  final JournalStore journal;
  final MobilePrefsStore prefs;
  final TranscriptionLedger ledger;

  static Future<_Stores> open(
    Directory root,
    String name, {
    required String jobId,
  }) async {
    final directory = Directory('${root.path}/$name');
    final keyStore = InMemoryPrivateDataEncryptionKeyStore(
      seedKey: List<int>.generate(
        32,
        (index) => (index + name.length * 17) % 256,
      ),
    );
    return _Stores(
      journal: await JournalStore.open(
        '${directory.path}/journal.json',
        keyStore: keyStore,
      ),
      prefs: await MobilePrefsStore.open('${directory.path}/prefs.json'),
      ledger: await TranscriptionLedger.open(
        directory: Directory('${directory.path}/queue'),
        idFactory: () => jobId,
        clock: () => DateTime.utc(2026, 7, 25, 12),
      ),
    );
  }
}

final class _StoreSnapshot {
  const _StoreSnapshot({
    required this.journalJson,
    required this.prefs,
    required this.job,
    required this.audioBytes,
  });

  final List<Map<String, dynamic>> journalJson;
  final Map<String, dynamic>? prefs;
  final TranscriptionJob job;
  final List<int> audioBytes;

  static Future<_StoreSnapshot> capture(
    _Stores stores, {
    required String prefsKey,
  }) async {
    final job = stores.ledger.jobs.single;
    return _StoreSnapshot(
      journalJson: (await stores.journal.loadAll())
          .map((entry) => entry.toJson())
          .toList(growable: false),
      prefs: await stores.prefs.readJsonMap(prefsKey),
      job: job,
      audioBytes: await File(job.audioPath).readAsBytes(),
    );
  }

  Future<void> expectUnchanged(
    _Stores stores, {
    required String prefsKey,
  }) async {
    expect(
      (await stores.journal.loadAll()).map((entry) => entry.toJson()).toList(),
      journalJson,
    );
    expect(await stores.prefs.readJsonMap(prefsKey), prefs);
    expect(stores.ledger.jobs.single, job);
    expect(
      await File(stores.ledger.jobs.single.audioPath).readAsBytes(),
      audioBytes,
    );
    expect(stores.ledger.checkIntegrity().isHealthy, isTrue);
  }
}

final class _InvalidLedgerRecoverySource implements DisasterRecoverySource {
  @override
  Future<List<RecoveryInput>> readNormalizedInputs() async {
    final now = DateTime.utc(2026, 7, 25, 12).toIso8601String();
    return [
      RecoveryInput(
        kind: RecoveryDataKind.journal,
        logicalPath: 'journal.json',
        bytes: utf8.encode(jsonEncode([_entry('replacement').toJson()])),
      ),
      RecoveryInput(
        kind: RecoveryDataKind.preferences,
        logicalPath: 'preferences.json',
        bytes: utf8.encode(
          jsonEncode({
            LocalArchiveBackupPrefsKeys.patternNames: {'replacement': true},
          }),
        ),
      ),
      RecoveryInput(
        kind: RecoveryDataKind.ledger,
        logicalPath: 'ledger.json',
        bytes: utf8.encode(
          jsonEncode([
            {
              'id': 'duplicate-job',
              'entryId': 'replacement',
              'audioName': null,
              'sourceFileName': 'first.wav',
              'durationSeconds': 3,
              'status': 'queued',
              'createdAt': now,
              'updatedAt': now,
              'attemptCount': 0,
              'nextAttemptAt': null,
              'lastError': null,
              'transcript': null,
              'completedAt': null,
            },
            {
              'id': 'duplicate-job',
              'entryId': 'replacement',
              'audioName': null,
              'sourceFileName': 'second.wav',
              'durationSeconds': 4,
              'status': 'queued',
              'createdAt': now,
              'updatedAt': now,
              'attemptCount': 0,
              'nextAttemptAt': null,
              'lastError': null,
              'transcript': null,
              'completedAt': null,
            },
          ]),
        ),
      ),
    ];
  }
}

JournalEntry _entry(
  String id, {
  String transcript = 'Portable journal entry',
}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 7, 24),
  transcript: transcript,
  durationSeconds: 10,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['integrity'],
    exactLanguagePattern: 'exact wording',
    concreteObservation: 'preserve metadata',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
  isPinned: true,
  pinnedAt: DateTime.utc(2026, 7, 24, 1),
  keepExactDetails: true,
  preserveOriginal: true,
  localCaptureContext: LocalCaptureContext(
    capturedAt: DateTime.utc(2026, 7, 24, 2),
    locationLabel: 'Offline',
  ),
);
