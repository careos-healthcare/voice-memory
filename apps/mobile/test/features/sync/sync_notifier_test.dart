import 'dart:io';

import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/data/repositories/sync_repository.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_journal_sync_coordinator.dart';
import 'package:archiveme_mobile/features/sync/application/sync_notifier.dart';
import 'package:archiveme_mobile/features/sync/application/sync_state.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/journal_ownership_guard.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/encrypted_sync_test_helpers.dart';

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
    await markLegacyMigrationComplete(prefs);
    final syncApi = _NoopSyncApi();
    final holder = SyncRepositoryHolder()
      ..value = SyncRepository(
        coordinator: EncryptedJournalSyncCoordinator(
          syncApi: syncApi,
          journal: journal,
          prefs: prefs,
          deviceIds: TestDeviceIdStore(),
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
        createdAt: DateTime.utc(2026),
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
          syncApi: _AuthRequiredSyncApi(),
          journal: journal,
          prefs: prefs,
          deviceIds: TestDeviceIdStore(),
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
    expect(result.message, 'Sign in to sync your archive to the server.');
  });
}

class _NoopSyncApi implements SyncApiClient {
  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() async {
    return const ApiSuccess({'blobs': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    return const ApiSuccess({
      'ok': true,
      'manifest': {'latestSequence': 1, 'blobs': []},
    });
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    return const ApiSuccess({'blobs': []});
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

class _AuthRequiredSyncApi implements SyncApiClient {
  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() async {
    return const ApiSuccess({'blobs': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    return const ApiFailureResult(ApiFailureAuthRequired('Sign in required.'));
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    return const ApiSuccess({'blobs': []});
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