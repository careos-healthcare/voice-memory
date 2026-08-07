import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/core/di/network_providers.dart';
import 'package:voicememory_mobile/core/network/api_failure.dart';
import 'package:voicememory_mobile/data/network/api_client_sync_adapter.dart';
import 'package:voicememory_mobile/data/repositories/sync_repository.dart';
import 'package:voicememory_mobile/features/encrypted_sync/encrypted_journal_sync_coordinator.dart';
import 'package:voicememory_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:voicememory_mobile/features/sync/application/sync_notifier.dart';
import 'package:voicememory_mobile/features/sync/application/sync_state.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/journal_ownership_guard.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

void main() {
  late Directory tempDir;
  late JournalStore journal;
  late MobilePrefsStore prefs;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_notifier_');
    journal = await JournalStore.open('${tempDir.path}/journal.json');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    await prefs.writeString(JournalOwnershipGuard.ownerKeyPrefsKey, 'user-a');
    final api = _NoopSyncApi();
    final holder = SyncRepositoryHolder()
      ..value = SyncRepository(
        coordinator: EncryptedJournalSyncCoordinator(
          syncApi: ApiClientSyncAdapter(api),
          api: api,
          journal: journal,
          prefs: prefs,
          deviceIds: _FakeDeviceIds(),
          keyStore: InMemorySyncMasterKeyStore(),
        ),
        prefs: prefs,
      );
    container = ProviderContainer(
      overrides: [syncRepositoryHolderProvider.overrideWithValue(holder)],
    );
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('syncNow updates immutable sync state on success', () async {
    await journal.save(
      JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026, 1, 1),
        transcript: 'hello',
        durationSeconds: 1,
        reflection: _reflection(),
      ),
    );

    final notifier = container.read(syncProvider.notifier);
    final result = await notifier.syncNow();

    expect(result.cloudSyncSucceeded, isTrue);
    expect(container.read(syncProvider).phase, SyncPhase.completed);
    expect(container.read(syncProvider).lastResult?.pushed, 1);
  });

  test('syncNow records typed failure in immutable sync state', () async {
    final holder = SyncRepositoryHolder()
      ..value = SyncRepository(
        coordinator: EncryptedJournalSyncCoordinator(
          syncApi: ApiClientSyncAdapter(_AuthRequiredSyncApi()),
          api: _AuthRequiredSyncApi(),
          journal: journal,
          prefs: prefs,
          deviceIds: _FakeDeviceIds(),
          keyStore: InMemorySyncMasterKeyStore(),
        ),
        prefs: prefs,
      );
    final failingContainer = ProviderContainer(
      overrides: [syncRepositoryHolderProvider.overrideWithValue(holder)],
    );
    addTearDown(failingContainer.dispose);

    final notifier = failingContainer.read(syncProvider.notifier);
    final result = await notifier.syncNow();

    expect(result.cloudSyncSucceeded, isFalse);
    expect(failingContainer.read(syncProvider).phase, SyncPhase.failed);
    expect(
      failingContainer.read(syncProvider).lastFailure,
      isA<ApiFailureAuthRequired>(),
    );
    expect(
      result.message,
      'Sign in to sync your archive to the server.',
    );
  });
}

class _NoopSyncApi extends ApiClient {
  _NoopSyncApi() : super(baseUrl: 'http://test.invalid');

  @override
  Future<Map<String, dynamic>> syncPush(Map<String, dynamic> body) async {
    return {
      'ok': true,
      'manifest': {'latestSequence': 1, 'blobs': []},
    };
  }

  @override
  Future<Map<String, dynamic>> syncPull() async => {'blobs': []};
}

class _AuthRequiredSyncApi extends ApiClient {
  _AuthRequiredSyncApi() : super(baseUrl: 'http://test.invalid');

  @override
  Future<Map<String, dynamic>> syncPush(Map<String, dynamic> body) async {
    throw AuthRequiredException('Sign in required.');
  }
}

class _FakeDeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}
