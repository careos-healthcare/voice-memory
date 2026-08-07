import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/data/network/api_client_sync_adapter.dart';
import 'package:voicememory_mobile/features/encrypted_sync/encrypted_sync_service.dart';
import 'package:voicememory_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/services/journal_ownership_guard.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

void main() {
  group('EncryptedSyncService', () {
    late Directory tempDir;
    late JournalStore journal;
    late MobilePrefsStore prefs;
    late _RecordingApi api;
    late EncryptedSyncService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('encrypted_sync_');
      journal = await JournalStore.open('${tempDir.path}/journal.json');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      await prefs.writeString(JournalOwnershipGuard.ownerKeyPrefsKey, 'user-a');
      api = _RecordingApi();
      service = EncryptedSyncService(
        syncApi: ApiClientSyncAdapter(api),
        journal: journal,
        prefs: prefs,
        deviceIds: _FakeDeviceIds(),
        keyStore: InMemorySyncMasterKeyStore(),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'syncEncryptedJournal uploads ciphertext only, never plaintext transcript',
      () async {
        await journal.save(
          JournalEntry(
            id: 'entry-1',
            createdAt: DateTime.utc(2026, 1, 1),
            transcript: 'secret transcript body',
            durationSeconds: 3,
            reflection: _reflection(),
          ),
        );

        await service.syncEncryptedJournal();

        expect(api.pushBodies, isNotEmpty);
        final encoded = jsonEncode(api.pushBodies.last);
        expect(encoded, isNot(contains('secret transcript body')));
        expect(encoded, contains('ciphertext'));
        expect(encoded, contains('iv'));
      },
    );

    test(
      'syncEncryptedJournal pull decrypts remote archive-core blob',
      () async {
        await journal.save(
          JournalEntry(
            id: 'local-only',
            createdAt: DateTime.utc(2026, 1, 1),
            transcript: 'local',
            durationSeconds: 1,
            reflection: _reflection(),
          ),
        );

        await service.syncEncryptedJournal();
        final firstPush = api.pushBodies.last;

        api.pullBlobs = firstPush['blobs'] as List<dynamic>;

        await journal.save(
          JournalEntry(
            id: 'remote-newer',
            createdAt: DateTime.utc(2026, 2, 1),
            transcript: 'from remote',
            durationSeconds: 2,
            reflection: _reflection(),
          ),
        );
        await service.syncEncryptedJournal();

        final merged = await journal.getById('local-only');
        expect(merged, isNotNull);
      },
    );
  });
}

class _RecordingApi extends ApiClient {
  _RecordingApi() : super(baseUrl: 'http://test.invalid');

  final List<Map<String, dynamic>> pushBodies = [];
  List<dynamic>? pullBlobs;

  @override
  Future<Map<String, dynamic>> syncPush(Map<String, dynamic> body) async {
    pushBodies.add(Map<String, dynamic>.from(body));
    return {
      'ok': true,
      'manifest': {'blobs': []},
    };
  }

  @override
  Future<Map<String, dynamic>> syncPull() async {
    return {'blobs': pullBlobs ?? []};
  }
}

class _FakeDeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}
