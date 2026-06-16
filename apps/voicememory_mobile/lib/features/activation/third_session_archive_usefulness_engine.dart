import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../retention/second_session_signal_engine.dart';
import 'first_three_session_gates.dart';
import 'third_session_archive_usefulness_model.dart';

/// Builds session-3 archive usefulness copy from local entry evidence only.
class ThirdSessionArchiveUsefulnessEngine {
  const ThirdSessionArchiveUsefulnessEngine();

  static const _comparisonEngine = SecondSessionSignalEngine();

  ThirdSessionArchiveUsefulness build(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < FirstThreeSessionGates.minEntriesForUsefulArchive) {
      return ThirdSessionArchiveUsefulness.insufficient;
    }

    final comparison = _comparisonEngine.build(eligible);
    final keepsReturning = comparison.whatRepeated?.trim().isNotEmpty == true
        ? comparison.whatRepeated!.trim()
        : (comparison.possibleRepeat
              ? 'Similar themes may be showing up across your recent moments.'
              : 'ArchiveMe is still gathering enough to name what keeps returning.');

    final changedSince = comparison.whatChanged?.trim().isNotEmpty == true
        ? comparison.whatChanged!.trim()
        : 'Your latest moment may sit differently from the one before it.';

    return ThirdSessionArchiveUsefulness(
      hasEnoughData: true,
      whatKeepsReturning: keepsReturning,
      whatChangedSince: changedSince,
    );
  }
}
