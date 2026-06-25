import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Reflection _reflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: const [],
  exactLanguagePattern: '',
  concreteObservation: 'You sounded tired.',
  repeatedSignal: '',
);

void main() {
  late Directory tempDir;
  late JournalStore journal;
  late MobilePrefsStore prefs;
  late PrivateDataService service;
  late File audioFile;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_private_data_');
    journal = await JournalStore.open('${tempDir.path}/entries.json');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    audioFile = File('${tempDir.path}/recording.m4a');
    await audioFile.writeAsString('fake audio bytes');
    service = PrivateDataService(
      journalStore: journal,
      prefs: prefs,
      tempDirProvider: () async => tempDir,
    );
  });

  test('purgeRetryRecordings no-ops when temp directory is unavailable', () async {
    await expectLater(
      TempRecordingCleanup.purgeRetryRecordings(),
      completes,
    );
    await expectLater(
      TempRecordingCleanup.purgeTempRecordings(),
      completes,
    );
  });

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
    await prefs.writeMap('archiveCollections', {'packs': ['a']});

    await service.wipeAllLocalArchive(
      confirmationPhrase: PrivateDataService.wipeConfirmationPhrase,
    );

    expect(await journal.loadAll(), isEmpty);
    expect(tempRecording.existsSync(), isFalse);
    expect(await prefs.readMap('archiveCollections'), isEmpty);
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
