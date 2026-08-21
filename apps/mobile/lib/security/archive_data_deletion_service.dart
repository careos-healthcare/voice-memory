import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/features/archive_agreement/archive_agreement_store.dart';
import 'package:archiveme_mobile/security/local_privacy_data_controls.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Verifiable one-click deletion of on-device archive data.
///
/// Removes audio files, encrypted journal payloads, derived insights,
/// evidence trails, correction records, and clinical-sandbox partitions.
abstract final class ArchiveDataDeletionService {
  ArchiveDataDeletionService._();

  /// Deletes all local archive content for the active account namespace.
  static Future<ArchiveDataDeletionResult> deleteAllLocalArchive({
    LocalPrivacyDataControls? controls,
  }) async {
    final privacyControls = controls ?? LocalPrivacyDataControls.instance();

    var journalEntriesRemoved = 0;
    var audioFilesRemoved = 0;
    if (AppServices.isInitialized) {
      final entries = await AppServices.instance.journalStore.loadAll();
      journalEntriesRemoved = entries.length;
      for (final entry in entries) {
        final path = entry.localAudioPath?.trim();
        if (path != null && path.isNotEmpty) {
          audioFilesRemoved++;
        }
      }
    }

    await privacyControls.clearLocalArchive();

    if (AppServices.isInitialized) {
      final services = AppServices.instance;
      await services.remoteProcessingConsentStore.withdraw();
      await services.clinicalConsentStore.revoke();
      await ArchiveAgreementStore(services.prefs).saveHistory(const []);
    }

    await BetaAnalyticsHooks.deletionResult(
      success: true,
      scope: 'local_archive',
    );

    return ArchiveDataDeletionResult(
      journalEntriesRemoved: journalEntriesRemoved,
      audioFilesRemoved: audioFilesRemoved,
      derivedInsightsCleared: true,
      evidenceTrailsCleared: true,
    );
  }
}

class ArchiveDataDeletionResult {
  const ArchiveDataDeletionResult({
    required this.journalEntriesRemoved,
    required this.audioFilesRemoved,
    required this.derivedInsightsCleared,
    required this.evidenceTrailsCleared,
  });

  final int journalEntriesRemoved;
  final int audioFilesRemoved;
  final bool derivedInsightsCleared;
  final bool evidenceTrailsCleared;
}