import '../../config/app_config.dart';
import '../../config/archive_me_demo_state.dart';
import '../../config/creator_demo_mode.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../features/encrypted_sync/encrypted_journal_sync_coordinator.dart';
import '../../product/consumer_ui_copy.dart';
import '../../services/capture_save_messages.dart';
import '../../services/sync_service.dart';
import '../../storage/mobile_prefs_store.dart';

/// Orchestrates encrypted journal sync with typed [ApiResult] boundaries.
class SyncRepository {
  SyncRepository({
    required EncryptedJournalSyncCoordinator coordinator,
    required MobilePrefsStore prefs,
  }) : _coordinator = coordinator,
       _prefs = prefs;

  final EncryptedJournalSyncCoordinator _coordinator;
  final MobilePrefsStore _prefs;

  Future<ApiResult<SyncResult>> syncNow() async {
    if (ArchiveMeDemoState.isActive || CreatorDemoMode.isActive) {
      return ApiSuccess(
        const SyncResult(
          cloudSyncSucceeded: false,
          message: 'Your moments stay on this device.',
          pushed: 0,
          pulled: 0,
        ),
      );
    }
    if (!AppConfig.isBackendConfigured) {
      return ApiSuccess(
        const SyncResult(
          cloudSyncSucceeded: false,
          message: 'Your moments stay on this device.',
          syncNote: CaptureSaveMessages.syncNotAvailableTestFlight,
          pushed: 0,
          pulled: 0,
        ),
      );
    }

    var pushed = 0;
    try {
      final encrypted = await _coordinator.syncNow();
      pushed = encrypted.pushed;
      return ApiSuccess(
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
          pushed: pushed,
          pulled: encrypted.pulled,
        ),
      );
    } on Object catch (error) {
      final failure = ApiFailureMapper.fromException(error);
      return ApiSuccess(_failureResult(failure, pushed: pushed));
    }
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

  SyncResult _failureResult(ApiFailure failure, {required int pushed}) {
    if (failure is ApiFailureAuthRequired) {
      return SyncResult(
        cloudSyncSucceeded: false,
        message: 'Sign in to sync your archive to the server.',
        pushed: pushed,
        pulled: 0,
      );
    }
    if (failure is ApiFailureBackendNotConfigured) {
      return SyncResult(
        cloudSyncSucceeded: false,
        message: 'Your moments stay on this device.',
        syncNote: CaptureSaveMessages.syncNotAvailableTestFlight,
        pushed: pushed,
        pulled: 0,
      );
    }
    return SyncResult(
      cloudSyncSucceeded: false,
      message: 'Sync did not complete.',
      syncNote: CaptureSaveMessages.syncNoteFor(failure),
      pushed: pushed,
      pulled: 0,
    );
  }
}
