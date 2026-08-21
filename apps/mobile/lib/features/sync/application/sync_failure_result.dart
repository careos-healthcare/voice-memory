import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/services/sync_service.dart';

/// Maps typed [ApiFailure] values to user-facing [SyncResult] copy.
SyncResult syncResultForFailure(
  ApiFailure failure, {
  required int partialPushed,
}) {
  if (failure is ApiFailureAuthRequired) {
    return SyncResult(
      cloudSyncSucceeded: false,
      message: 'Sign in to sync your archive to the server.',
      pushed: partialPushed,
      pulled: 0,
    );
  }
  if (failure is ApiFailureBackendNotConfigured) {
    return SyncResult(
      cloudSyncSucceeded: false,
      message: 'Your moments stay on this device.',
      syncNote: CaptureSaveMessages.syncNotAvailableTestFlight,
      pushed: partialPushed,
      pulled: 0,
    );
  }
  return SyncResult(
    cloudSyncSucceeded: false,
    message: 'Sync did not complete.',
    syncNote: CaptureSaveMessages.syncNoteFor(failure),
    pushed: partialPushed,
    pulled: 0,
  );
}