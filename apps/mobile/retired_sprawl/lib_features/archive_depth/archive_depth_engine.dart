import 'package:archiveme_mobile/features/archive_depth/archive_depth_copy.dart';
import 'package:archiveme_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds archive depth from saved entries — local and deterministic.
class ArchiveDepthEngine {
  const ArchiveDepthEngine();

  ArchiveDepthResult build({required List<JournalEntry> entries}) {
    final saved = _realEntries(entries);
    final eligible = ArchiveEvidenceGuard.eligibleEntries(saved);
    final savedCount = saved.length;
    final usableCount = eligible.length;
    final level = _levelFor(savedCount);
    final levelCopy = ArchiveDepthCopy.levelCopy(level);
    final untaggedEligible = _untaggedEligibleCount(eligible);

    return ArchiveDepthResult(
      level: level,
      levelLabel: levelCopy.label,
      explanation: levelCopy.explanation,
      progressLabel: ArchiveDepthCopy.progressLabel(
        savedCount: savedCount,
        usableCount: usableCount,
      ),
      nextStep: _nextStep(
        savedCount: savedCount,
        untaggedEligible: untaggedEligible,
      ),
      savedCount: savedCount,
      usableEvidenceCount: usableCount,
      showProLine: savedCount >= 10,
    );
  }

  static List<JournalEntry> _realEntries(List<JournalEntry> entries) => entries
      .where(
        (e) =>
            e.transcript.trim().isNotEmpty &&
            !e.transcript.startsWith('[draft]'),
      )
      .toList();

  static ArchiveDepthLevel _levelFor(int savedCount) {
    if (savedCount <= 0) return ArchiveDepthLevel.notStarted;
    if (savedCount == 1) return ArchiveDepthLevel.firstEvidence;
    if (savedCount == 2) return ArchiveDepthLevel.startingToCompare;
    if (savedCount <= 4) return ArchiveDepthLevel.cautiousBelief;
    if (savedCount <= 9) return ArchiveDepthLevel.weeklyReviewReady;
    return ArchiveDepthLevel.longTermBuilding;
  }

  static int _untaggedEligibleCount(List<JournalEntry> eligible) => eligible
      .where(
        (e) =>
            e.captureContextTag == null || e.captureContextTag!.trim().isEmpty,
      )
      .length;

  static String _nextStep({
    required int savedCount,
    required int untaggedEligible,
  }) {
    if (savedCount >= 2 && untaggedEligible > 0) {
      return ArchiveDepthCopy.nextStepTagUntagged;
    }
    if (savedCount >= 3) {
      return ArchiveDepthCopy.nextStepReviewChanges;
    }
    return ArchiveDepthCopy.nextStepAddMoment;
  }
}