import '../early_archive/early_first_signal_engine.dart';
import '../record/record_empty_archive_gates.dart';
import '../../models/journal_entry.dart';

/// Visibility gates for the archive journey explainer surfaces.
abstract final class ArchiveJourneyExplainerGates {
  ArchiveJourneyExplainerGates._();

  static bool hasFirstProof(List<JournalEntry> entries) =>
      EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);

  static bool showCompactOnRecord({
    required bool loaded,
    required int entryCount,
    required bool isPostSave,
    required List<JournalEntry> entries,
  }) =>
      loaded &&
      !isPostSave &&
      !hasFirstProof(entries) &&
      RecordEmptyArchiveGates.showFirstUseSimplifiedRecord(
        loaded: loaded,
        entryCount: entryCount,
      );

  static bool showFullOnPatternsEmpty({
    required bool hasFirstProof,
  }) =>
      !hasFirstProof;
}
