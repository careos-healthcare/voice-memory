import '../../../../models/journal_entry.dart';
import '../../../../services/capture_pipeline_service.dart';
import '../../../../storage/journal_store.dart';

final class SavedMomentResult {
  const SavedMomentResult({
    required this.entry,
    required this.entries,
    required this.analysisSucceeded,
    required this.syncSucceeded,
  });

  final JournalEntry entry;
  final List<JournalEntry> entries;
  final bool analysisSucceeded;
  final bool syncSucceeded;
}

final class SaveMomentCoordinator {
  const SaveMomentCoordinator(this._journal);

  final JournalStore _journal;

  Future<SavedMomentResult> conclude(CapturePipelineResult result) async {
    final entries = await _journal.loadAll();
    var persisted = result.entry;
    for (final entry in entries) {
      if (entry.id == result.entry.id) {
        persisted = entry;
        break;
      }
    }
    return SavedMomentResult(
      entry: persisted,
      entries: entries,
      analysisSucceeded: result.analysisSucceeded,
      syncSucceeded: result.syncSucceeded,
    );
  }
}
