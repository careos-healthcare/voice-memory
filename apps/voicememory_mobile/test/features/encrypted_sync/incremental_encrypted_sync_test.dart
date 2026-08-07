import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/data/network/api_client_sync_adapter.dart';
import 'package:voicememory_mobile/features/encrypted_sync/encrypted_sync_service.dart';
import 'package:voicememory_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/account_session_scope.dart';
import 'package:voicememory_mobile/services/journal_ownership_guard.dart';
import 'package:voicememory_mobile/storage/account_namespace.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

import '../../support/test_storage_sandbox.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

void main() {
  late TestStorageSandbox sandbox;
  late JournalStore journal;
  late MobilePrefsStore prefs;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    journal = await JournalStore.open(sandbox.journalPath);
    prefs = await MobilePrefsStore.open(sandbox.prefsPath);
    await prefs.writeString(JournalOwnershipGuard.ownerKeyPrefsKey, 'user-a');
  });

  tearDown(() => sandbox.dispose());

  test('uses incremental changes pull when lastSyncSequence is set', () async {
    await prefs.setLastSyncSequence(1);
    final api = _IncrementalApi();
    final service = EncryptedSyncService(
      syncApi: ApiClientSyncAdapter(api),
      journal: journal,
      prefs: prefs,
      deviceIds: _FakeDeviceIds(),
      keyStore: InMemorySyncMasterKeyStore(),
    );

    await journal.save(
      JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026, 1, 1),
        transcript: 'local',
        durationSeconds: 1,
        reflection: _reflection(),
      ),
    );

    final result = await service.syncEncryptedJournal();
    expect(result.isSuccess, isTrue);

    expect(api.syncChangesCalls, 1);
    expect(api.lastSince, 1);
    expect(api.syncPullCalls, 0);
    expect(await prefs.lastSyncSequence, 2);
  });

  test('aborts sync when account session changes mid-flight', () async {
    final registry = AccountSessionRegistry.instance;
    registry.activate(
      namespace: AccountNamespace.forUserId('user-a'),
      userId: 'user-a',
    );
    final service = EncryptedSyncService(
      syncApi: ApiClientSyncAdapter(_StaleMidFlightApi()),
      journal: journal,
      prefs: prefs,
      deviceIds: _FakeDeviceIds(),
      keyStore: InMemorySyncMasterKeyStore(),
    );

    await journal.save(
      JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026, 1, 1),
        transcript: 'local',
        durationSeconds: 1,
        reflection: _reflection(),
      ),
    );

    await expectLater(
      service.syncEncryptedJournal(),
      throwsA(isA<StaleAccountSessionException>()),
    );
  });
}

class _IncrementalApi extends ApiClient {
  _IncrementalApi() : super(baseUrl: 'http://test.invalid');

  var syncChangesCalls = 0;
  var syncPullCalls = 0;
  int? lastSince;

  @override
  Future<Map<String, dynamic>> syncPush(Map<String, dynamic> body) async {
    return {
      'manifest': {'latestSequence': 2, 'blobs': []},
    };
  }

  @override
  Future<Map<String, dynamic>> syncChanges({required int since}) async {
    syncChangesCalls++;
    lastSince = since;
    return {
      'latestSequence': 2,
      'changes': [
        {
          'sequence': 2,
          'blobType': 'journal_snapshot',
          'blobId': 'archive-core',
          'changeKind': 'upsert',
          'updatedAt': '2026-01-15T12:00:00.000Z',
          'tombstone': false,
        },
      ],
      'blobs': [],
    };
  }

  @override
  Future<Map<String, dynamic>> syncPull() async {
    syncPullCalls++;
    return {'blobs': []};
  }
}

class _StaleMidFlightApi extends ApiClient {
  _StaleMidFlightApi() : super(baseUrl: 'http://test.invalid');

  @override
  Future<Map<String, dynamic>> syncPush(Map<String, dynamic> body) async {
    AccountSessionRegistry.instance.activate(
      namespace: AccountNamespace.forUserId('user-b'),
      userId: 'user-b',
    );
    return {
      'manifest': {'latestSequence': 1, 'blobs': []},
    };
  }

  @override
  Future<Map<String, dynamic>> syncPull() async => {'blobs': []};
}

class _FakeDeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}
