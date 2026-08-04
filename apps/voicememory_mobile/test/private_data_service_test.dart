import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Reflection _reflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: 'You sounded tired.',
  repeatedSignal: '',
);

void main() {
  late Directory tempDir;
  late JournalStore journal;
  late MobilePrefsStore prefs;
  late PrivateDataService service;
  late AudioVaultService audioVault;
  late InMemoryAudioVaultKeyStore audioVaultKeyStore;
  late File audioFile;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_private_data_');
    journal = await JournalStore.open(
      '${tempDir.path}/entries.json',
      ownerArchiveId: 'local',
    );
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    audioFile = File('${tempDir.path}/recording.m4a');
    await audioFile.writeAsString('fake audio bytes');
    audioVaultKeyStore = InMemoryAudioVaultKeyStore();
    audioVault = AudioVaultService(
      keyStore: audioVaultKeyStore,
      vaultDirectory: () async => Directory('${tempDir.path}/vault'),
      temporaryDirectory: () async => tempDir,
    );
    service = PrivateDataService(
      journalStore: journal,
      prefs: prefs,
      audioVault: audioVault,
      tempDirProvider: () async => tempDir,
    );
  });

  test(
    'purgeRetryRecordings no-ops when temp directory is unavailable',
    () async {
      await expectLater(TempRecordingCleanup.purgeRetryRecordings(), completes);
      await expectLater(TempRecordingCleanup.purgeTempRecordings(), completes);
    },
  );

  test('deleteEntrySecurely removes entry and audio file', () async {
    await journal.save(
      JournalEntry(
        id: 'e1',
        createdAt: DateTime.utc(2026, 6, 1),
        transcript: 'Private reflection text',
        durationSeconds: 12,
        reflection: _reflection(),
        syncStatus: SyncStatus.localOnly,
        localAudioPath: audioFile.path,
      ),
    );
    expect(audioFile.existsSync(), isTrue);

    final result = await service.deleteEntrySecurely('e1');
    expect(result.deleted, isTrue);
    expect(result.audioFileRemoved, isTrue);
    expect(await journal.getById('e1'), isNull);
    expect(audioFile.existsSync(), isFalse);
  });

  test('deleteEntrySecurely removes encrypted vault audio', () async {
    final source = File('${tempDir.path}/recording.aac');
    await source.writeAsBytes(List<int>.filled(128, 7));
    final encrypted = await audioVault.sealCapture('encrypted-entry', source);
    await journal.save(
      JournalEntry(
        id: 'encrypted-entry',
        createdAt: DateTime.utc(2026, 6, 1),
        transcript: 'Encrypted recording',
        durationSeconds: 12,
        reflection: _reflection(),
        localAudioVaultRef: encrypted.reference,
      ),
    );
    await audioVault.secureDeletePlaintext(source);

    final result = await service.deleteEntrySecurely('encrypted-entry');

    expect(result.audioFileRemoved, isTrue);
    expect(await encrypted.file.exists(), isFalse);
  });

  test('wipeAllLocalArchive clears journal and temp recordings', () async {
    final tempRecording = File('${tempDir.path}/vm_rec_test.m4a');
    await tempRecording.writeAsString('temp');
    await journal.save(
      JournalEntry(
        id: 'e2',
        createdAt: DateTime.utc(2026, 6, 2),
        transcript: '[draft] offline capture',
        durationSeconds: 8,
        reflection: _reflection(),
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: tempRecording.path,
      ),
    );
    await prefs.writeMap('archiveCollections', {
      'packs': ['a'],
    });

    await service.wipeAllLocalArchive(
      confirmationPhrase: PrivateDataService.wipeConfirmationPhrase,
    );

    expect(await journal.loadAll(), isEmpty);
    expect(tempRecording.existsSync(), isFalse);
    expect(await prefs.readMap('archiveCollections'), isEmpty);
  });

  test('wipe destroys unreferenced vault files and the vault key', () async {
    final source = File('${tempDir.path}/orphan.m4a');
    await source.writeAsBytes(List<int>.filled(128, 9));
    final encrypted = await audioVault.sealRecording(source, vaultId: 'orphan');
    expect(audioVaultKeyStore.value, isNotNull);

    await service.wipeAllLocalArchive(
      confirmationPhrase: PrivateDataService.wipeConfirmationPhrase,
    );

    expect(await encrypted.exists(), isFalse);
    expect(audioVaultKeyStore.value, isNull);
  });

  test('wipe removes local model before clearing archive data', () async {
    var modelRemoved = false;
    final orderedService = PrivateDataService(
      journalStore: journal,
      prefs: prefs,
      tempDirProvider: () async => tempDir,
      modelWipe: () async {
        expect(await journal.loadAll(), isNotEmpty);
        modelRemoved = true;
      },
    );
    await journal.save(
      JournalEntry(
        id: 'model-wipe-entry',
        createdAt: DateTime.utc(2026, 7, 24),
        transcript: 'private archive evidence',
        durationSeconds: 1,
        reflection: _reflection(),
      ),
    );

    await orderedService.wipeAllLocalArchive(
      confirmationPhrase: PrivateDataService.wipeConfirmationPhrase,
    );

    expect(modelRemoved, isTrue);
    expect(await journal.loadAll(), isEmpty);
  });

  test('wipe purges auxiliary encrypted audio queues', () async {
    var auxiliaryAudioPurged = false;
    final wipeService = PrivateDataService(
      journalStore: journal,
      audioVault: audioVault,
      tempDirProvider: () async => tempDir,
      auxiliaryAudioWipe: () async {
        auxiliaryAudioPurged = true;
      },
    );

    await wipeService.wipeAllLocalArchive(
      confirmationPhrase: PrivateDataService.wipeConfirmationPhrase,
    );

    expect(auxiliaryAudioPurged, isTrue);
  });

  test('export uses sanitized user-owned data only', () async {
    await journal.save(
      JournalEntry(
        id: 'secret-id',
        createdAt: DateTime.utc(2026, 6, 3),
        transcript: 'My reflection',
        durationSeconds: 5,
        reflection: _reflection(),
        syncStatus: SyncStatus.synced,
        localAudioPath: '/tmp/secret.m4a',
      ),
    );

    final payload = await service.buildSanitizedExport();
    final json = payload.toJson();
    expect(json, contains('"app": "ArchiveMe"'));
    expect(json, contains('My reflection'));
    expect(json, isNot(contains('secret-id')));
    expect(json, isNot(contains('/tmp/secret.m4a')));
    expect(json, isNot(contains('syncStatus')));
  });
}
