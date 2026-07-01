import '../../models/journal_entry.dart';
import '../early_archive/early_evidence_timeline_engine.dart';
import '../early_archive/early_first_signal_engine.dart';

/// When the Pro bridge may appear — only after the user has seen real value.
abstract class PaywallTimingGates {
  PaywallTimingGates._();

  static const minFullArchiveHistoryEntryCount = 3;

  /// Soft Pro bridge: never on first save, never without archive proof.
  static bool showSoftProBridge({
    required int entryCount,
    required bool resolved,
    required bool isPro,
    required bool hasArchiveProof,
  }) =>
      entryCount >= 2 && hasArchiveProof && !resolved && !isPro;

  /// Full archive history Pro boundary — after confirmed repeat, Archive Summary,
  /// Weekly Review, Private Report preview, or Pattern Changed; never on first save.
  static bool showFullArchiveHistoryProBoundary({
    required int entryCount,
    required bool resolved,
    required bool isPro,
    required bool isPostSave,
    required bool hasConfirmedRepeat,
    required bool hasArchiveSummary,
    required bool hasWeeklyArchiveReview,
    bool hasPatternChanged = false,
    bool hasPrivateArchiveReportPreview = false,
  }) {
    if (isPro || resolved || isPostSave) return false;
    if (entryCount < minFullArchiveHistoryEntryCount) return false;
    return hasConfirmedRepeat ||
        hasArchiveSummary ||
        hasWeeklyArchiveReview ||
        hasPatternChanged ||
        hasPrivateArchiveReportPreview;
  }

  /// Pro bridge after a real value surface — never on first save, never blocking recording.
  static bool showPostProofProBridge({
    required int entryCount,
    required bool resolved,
    required bool isPro,
    required bool hasArchiveProof,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool hasChangeOverTimeProof,
    bool isPostSave = false,
    bool hasArchiveSummary = false,
    bool hasWeeklyArchiveReview = false,
    bool hasPatternChanged = false,
    bool hasPrivateArchiveReportPreview = false,
  }) =>
      showFullArchiveHistoryProBoundary(
        entryCount: entryCount,
        resolved: resolved,
        isPro: isPro,
        isPostSave: isPostSave,
        hasConfirmedRepeat: viewingConfirmedRepeatOrTimeline &&
            (hasConfirmedRepeatProof(
                  hasArchiveProof: hasArchiveProof,
                  hasChangeOverTimeProof: hasChangeOverTimeProof,
                ) ||
                hasArchiveProof),
        hasArchiveSummary: hasArchiveSummary,
        hasWeeklyArchiveReview: hasWeeklyArchiveReview,
        hasPatternChanged: hasPatternChanged,
        hasPrivateArchiveReportPreview: hasPrivateArchiveReportPreview,
      );

  static bool hasConfirmedRepeatProof({
    required bool hasArchiveProof,
    required bool hasChangeOverTimeProof,
  }) =>
      hasArchiveProof || hasChangeOverTimeProof;

  /// True when the archive has shown confirmed repeat, timeline, belief, or
  /// grounded pattern insight — not merely a second unrelated save.
  static bool hasArchiveProofFromEntries({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    bool hasBeliefProof = false,
    bool hasWeeklyReview = false,
    bool hasOhWowMoment = false,
    bool hasChangeOverTimeProof = false,
  }) {
    if (hasChangeOverTimeProof) return true;
    if (entries.isEmpty) return false;

    final earlySignal = EarlyFirstSignalEngine.build(entries: entries);
    if (earlySignal?.kind == EarlyFirstSignalKind.twoEntryFirstSignal ||
        earlySignal?.kind == EarlyFirstSignalKind.threeEntryConfirmedRepeat) {
      return true;
    }

    if (EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return true;
    }

    if (EarlyEvidenceTimelineEngine.build(
          entries: entries,
          triggerCapturedMilestone: triggerCapturedMilestone,
          helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
        ) !=
        null) {
      return true;
    }

    return hasBeliefProof || hasWeeklyReview || hasOhWowMoment;
  }
}
