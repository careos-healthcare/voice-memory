import '../../models/journal_entry.dart';
import '../../security/private_data_service.dart';
import '../../services/app_services.dart';
import '../archive_history/archive_history_engine.dart';
import '../archive_history/archive_history_item.dart';
import 'archive_control_analytics.dart';

/// Result of deleting one saved archive moment.
class ArchiveMomentDeleteResult {
  const ArchiveMomentDeleteResult({
    required this.deleted,
    required this.entryCount,
    required this.wasEvidence,
  });

  final bool deleted;
  final int entryCount;
  final bool wasEvidence;
}

/// Deletes saved moments locally and tracks safe metadata only.
abstract final class ArchiveControlEngine {
  ArchiveControlEngine._();

  static bool wasUsedAsEvidence({
    required String entryId,
    required List<JournalEntry> entries,
  }) {
    for (final item in ArchiveHistoryEngine.build(entries: entries).items) {
      if (item.entryId == entryId &&
          item.status == ArchiveHistoryStatus.usedAsEvidence) {
        return true;
      }
    }
    return false;
  }

  static Future<ArchiveMomentDeleteResult> deleteMoment({
    required String entryId,
    required String source,
    PrivateDataService? privateDataService,
  }) async {
    if (!AppServices.isInitialized) {
      return const ArchiveMomentDeleteResult(
        deleted: false,
        entryCount: 0,
        wasEvidence: false,
      );
    }

    final entries = await AppServices.instance.journal.loadAll();
    final wasEvidence = wasUsedAsEvidence(entryId: entryId, entries: entries);

    final service =
        privateDataService ??
        PrivateDataService(
          journalStore: AppServices.instance.journalStore,
          audioVault: AppServices.instance.journalAudioVault,
        );
    final result = await service.deleteEntrySecurely(entryId);
    if (!result.deleted) {
      return ArchiveMomentDeleteResult(
        deleted: false,
        entryCount: entries.length,
        wasEvidence: wasEvidence,
      );
    }

    final remaining = await AppServices.instance.journal.loadAll();
    ArchiveControlAnalytics.deleted(
      source: source,
      entryCount: remaining.length,
      wasEvidence: wasEvidence,
    );

    return ArchiveMomentDeleteResult(
      deleted: true,
      entryCount: remaining.length,
      wasEvidence: wasEvidence,
    );
  }
}
