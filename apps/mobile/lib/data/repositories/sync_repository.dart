import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/archive_me_demo_state.dart';
import 'package:archiveme_mobile/config/creator_demo_mode.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_journal_sync_coordinator.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Orchestrates encrypted journal sync with typed [ApiResult] boundaries.
class SyncRepository {
  SyncRepository({
    required this._coordinator,
    required this._prefs,
  });

  final EncryptedJournalSyncCoordinator _coordinator;
  final MobilePrefsStore _prefs;

  Future<ApiResult<SyncResult>> syncNow() async {
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) {
      return const ApiSuccess(
        SyncResult(
          cloudSyncSucceeded: false,
          message: 'Your moments stay on this device.',
          pushed: 0,
          pulled: 0,
        ),
      );
    }
    if (!AppConfig.isBackendConfigured) {
      return const ApiSuccess(
        SyncResult(
          cloudSyncSucceeded: false,
          message: 'Your moments stay on this device.',
          syncNote: CaptureSaveMessages.syncNotAvailableTestFlight,
          pushed: 0,
          pulled: 0,
        ),
      );
    }

    final result = await _coordinator.syncNow();
    return result.when(
      success: (encrypted) => ApiSuccess(
        SyncResult(
          cloudSyncSucceeded: true,
          message:
              'Sync complete. If anything looks duplicated, newer copies were kept.',
          syncNote: encrypted.blocked > 0
              ? '${encrypted.blocked} entr${encrypted.blocked == 1 ? 'y' : 'ies'} from a different '
                    'account stayed private on this device and were not '
                    'uploaded.'
              : encrypted.migratedLegacy
              ? 'Legacy plaintext archive was encrypted on this device. Server plaintext rows remain until audited deletion.'
              : null,
          pushed: encrypted.pushed,
          pulled: encrypted.pulled,
        ),
      ),
      onFailure: ApiFailureResult.new,
    );
  }

  Future<String> lastSyncLabel() async {
    if (!AppConfig.isBackendConfigured) {
      return ConsumerUiCopy.syncNotAvailableTestFlight;
    }
    final raw = await _prefs.lastSyncAt;
    if (raw == null) return ConsumerUiCopy.syncOnDeviceOnly;
    final at = DateTime.tryParse(raw);
    if (at == null) return ConsumerUiCopy.syncOnDeviceOnly;
    return 'Last sync ${at.toLocal()}';
  }
}