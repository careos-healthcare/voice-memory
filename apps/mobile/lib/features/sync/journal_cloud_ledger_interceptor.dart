import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/features/sync/plain_text_ledger_consent.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Uploads a saved entry to the plain-text ledger after ledger opt-in and a
/// signed plain-text AI processing consent. A local save still stands if the
/// request fails.
class JournalCloudLedgerInterceptor implements JournalSaveInterceptor {
  const JournalCloudLedgerInterceptor({this.service, this.mayIngest});

  final CloudSyncService? service;

  /// Test stand-in for the opt-in and consent check.
  final Future<bool> Function()? mayIngest;

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    final allowed = mayIngest ?? ledgerIngestAllowed;
    if (!await allowed()) return;
    final cloud = service ?? CloudSyncService();
    try {
      if (entry.isDeleted) {
        await cloud.deleteEntryFromLedger(entry.id);
        return;
      }
      final edited =
          entry.revision > 1 ||
          !entry.updatedAt.toUtc().isAtSameMomentAs(entry.createdAt.toUtc());
      if (edited) {
        await cloud.updateEntryOnLedger(entry);
      } else {
        await cloud.uploadEntryToLedger(entry);
      }
    } on Object {
      return;
    }
  }
}

/// True only when this build allows the ledger, the person opted in, and they
/// signed the plain-text AI processing consent.
Future<bool> ledgerIngestAllowed() async {
  if (!V1CapabilityRegistry.isLedgerOptInEnabled) return false;
  if (!AppServices.isInitialized) return false;
  final preferences = await UserPreferences.load(AppServices.instance.prefs);
  if (!preferences.isLedgerOptInEnabled) return false;
  return PlainTextLedgerConsent.isSigned(AppServices.instance.prefs);
}
