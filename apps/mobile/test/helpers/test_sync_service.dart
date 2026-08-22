import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/data/repositories/sync_repository.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_journal_sync_coordinator.dart';
import 'package:archiveme_mobile/features/sync/application/sync_notifier.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'encrypted_sync_test_helpers.dart';

Future<SyncService> createTestSyncService({
  required SyncApiClient syncApi,
  required JournalStore journal,
  required MobilePrefsStore prefs,
  DeviceIdStore? deviceIds,
  SyncMasterKeyStore? keyStore,
}) async {
  await markLegacyMigrationComplete(prefs);
  final coordinator = EncryptedJournalSyncCoordinator(
    syncApi: syncApi,
    journal: journal,
    prefs: prefs,
    deviceIds: deviceIds ?? TestDeviceIdStore(),
    keyStore: keyStore ?? InMemorySyncMasterKeyStore(),
  );
  final holder = SyncRepositoryHolder()
    ..value = SyncRepository(coordinator: coordinator, prefs: prefs);
  final container = ProviderContainer(
    overrides: [syncRepositoryHolderProvider.overrideWithValue(holder)],
  );
  return SyncService(container.read(syncProvider.notifier));
}