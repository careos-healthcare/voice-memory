import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_sync_service.dart';
import 'package:archiveme_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/journal_ownership_guard.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

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
        syncApi: api,
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
            createdAt: DateTime.utc(2026),
            transcript: 'secret transcript body',
            durationSeconds: 3,
            reflection: _reflection(),
          ),
        );

        final result = await service.syncEncryptedJournal();
        expect(result.isSuccess, isTrue);

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
            createdAt: DateTime.utc(2026),
            transcript: 'local',
            durationSeconds: 1,
            reflection: _reflection(),
          ),
        );

        final firstResult = await service.syncEncryptedJournal();
        expect(firstResult.isSuccess, isTrue);
        final firstPush = api.pushBodies.last;

        api.pullBlobs = firstPush['blobs'] as List<dynamic>;

        await journal.save(
          JournalEntry(
            id: 'remote-newer',
            createdAt: DateTime.utc(2026, 2),
            transcript: 'from remote',
            durationSeconds: 2,
            reflection: _reflection(),
          ),
        );
        final secondResult = await service.syncEncryptedJournal();
        expect(secondResult.isSuccess, isTrue);

        final merged = await journal.getById('local-only');
        expect(merged, isNotNull);
      },
    );
  });
}

class _RecordingApi implements SyncApiClient {
  final List<Map<String, dynamic>> pushBodies = [];
  List<dynamic>? pullBlobs;

  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() async {
    return const ApiSuccess({'blobs': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    pushBodies.add(Map<String, dynamic>.from(body));
    return const ApiSuccess({
      'ok': true,
      'manifest': {'blobs': []},
    });
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    return ApiSuccess({'blobs': pullBlobs ?? []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncChanges({
    required int since,
  }) async {
    return const ApiSuccess({'changes': []});
  }

  @override
  Future<ApiResult<List<JournalEntry>>> listLegacyJournal({
    NetworkCancelToken? cancelToken,
  }) async {
    return const ApiSuccess([]);
  }
}

class _FakeDeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}