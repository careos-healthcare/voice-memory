import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/disaster_recovery/disaster_recovery.dart';
import 'package:voicememory_mobile/features/local_backup/local_backup_model.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_queue.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'production adapters restore journal, prefs, ledger, and audio',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'recovery_adapter_test_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final journal = await JournalStore.open(
        '${root.path}/journal.json',
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      );
      final prefs = await MobilePrefsStore.open('${root.path}/prefs.json');
      final ledger = await TranscriptionLedger.open(
        directory: Directory('${root.path}/queue'),
        idFactory: () => 'job-1',
      );
      addTearDown(ledger.close);
      await journal.save(_entry('entry-1'));
      final prefsKey = LocalArchiveBackupPrefsKeys.included.first;
      await prefs.writeJsonMap(prefsKey, {'portable': true});
      final recording = File('${root.path}/recording.wav');
      await recording.writeAsBytes(List<int>.filled(300, 9), flush: true);
      final queued = await ledger.enqueue(
        recording,
        durationSeconds: 17,
        entryId: 'queued-entry',
      );

      final core = DisasterRecoveryCore(
        zipCodec: const ArchiveDisasterRecoveryZipCodec(),
      );
      final envelope = await core.export(
        passphrase: 'a strong recovery phrase',
        source: AppDisasterRecoverySource(
          journal: journal,
          prefs: prefs,
          ledger: ledger,
        ),
      );
      await journal.replaceAll(const []);
      await prefs.writeJsonMap(prefsKey, {});
      ledger.replaceAll(const []);
      await File(queued.audioPath).delete();

      await core.import(
        envelopeBytes: envelope.toBytes(),
        passphrase: 'a strong recovery phrase',
        sink: AppDisasterRecoverySink(
          journal: journal,
          prefs: prefs,
          ledger: ledger,
        ),
      );

      expect((await journal.loadAll()).single.id, 'entry-1');
      expect(await prefs.readJsonMap(prefsKey), {'portable': true});
      expect(ledger.jobs.single.entryId, 'queued-entry');
      expect(await File(ledger.jobs.single.audioPath).exists(), isTrue);
      expect(ledger.checkIntegrity().isHealthy, isTrue);
    },
  );
}

JournalEntry _entry(String id) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 7, 24),
  transcript: 'Portable journal entry',
  durationSeconds: 10,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);
