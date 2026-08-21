import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

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
  }) => showFirstProofJourneyStripOnRecord(
    loaded: loaded,
    entryCount: entryCount,
    isPostSave: isPostSave,
    entries: entries,
  );

  /// First-proof journey strip — early/low evidence only, not after first proof.
  static bool showFirstProofJourneyStripOnRecord({
    required bool loaded,
    required int entryCount,
    required bool isPostSave,
    required List<JournalEntry> entries,
  }) => loaded && !isPostSave && !hasFirstProof(entries) && entryCount <= 3;

  static bool showFullOnPatternsEmpty({required bool hasFirstProof}) =>
      !hasFirstProof;
}