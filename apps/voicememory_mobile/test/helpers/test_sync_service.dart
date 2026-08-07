import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/core/di/network_providers.dart';
import 'package:voicememory_mobile/data/network/api_client_sync_adapter.dart';
import 'package:voicememory_mobile/data/repositories/sync_repository.dart';
import 'package:voicememory_mobile/features/encrypted_sync/encrypted_journal_sync_coordinator.dart';
import 'package:voicememory_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:voicememory_mobile/features/sync/application/sync_notifier.dart';
import 'package:voicememory_mobile/services/sync_service.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

SyncService createTestSyncService({
  required ApiClient api,
  required JournalStore journal,
  required MobilePrefsStore prefs,
  DeviceIdStore? deviceIds,
  SyncMasterKeyStore? keyStore,
}) {
  final syncApi = ApiClientSyncAdapter(api);
  final coordinator = EncryptedJournalSyncCoordinator(
    syncApi: syncApi,
    api: api,
    journal: journal,
    prefs: prefs,
    deviceIds: deviceIds ?? DeviceIdStore(),
    keyStore:
        keyStore ?? SecureSyncMasterKeyStore(accountNamespace: 'guest'),
  );
  final holder = SyncRepositoryHolder()
    ..value = SyncRepository(
      coordinator: coordinator,
      prefs: prefs,
    );
  final container = ProviderContainer(
    overrides: [syncRepositoryHolderProvider.overrideWithValue(holder)],
  );
  return SyncService(container.read(syncProvider.notifier));
}
