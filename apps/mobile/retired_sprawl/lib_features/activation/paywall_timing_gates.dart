import 'package:archiveme_mobile/billing/magic_moments_counter.dart';
import 'package:archiveme_mobile/features/early_archive/early_evidence_timeline_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// When the Pro bridge may appear — only after the user has seen real value.
abstract class PaywallTimingGates {
  PaywallTimingGates._();

  static const minEvidenceMilestonesForPaywall =
      MagicMomentsCounter.paywallThreshold;

  /// @deprecated Prefer [minEvidenceMilestonesForPaywall].
  static const minMagicMomentsForPaywall = minEvidenceMilestonesForPaywall;

  /// @deprecated Prefer [minEvidenceMilestonesForPaywall].
  static const minFullArchiveHistoryEntryCount = minEvidenceMilestonesForPaywall;

  /// Soft Pro bridge: never on first save, never without archive proof.
  static bool showSoftProBridge({
    int? magicMomentsCount,
    int? entryCount,
    required bool resolved,
    required bool isPro,
    required bool hasArchiveProof,
  }) {
    final moments = magicMomentsCount ?? entryCount ?? 0;
    return moments >= minEvidenceMilestonesForPaywall &&
        hasArchiveProof &&
        !resolved &&
        !isPro;
  }

  /// Full archive history Pro boundary — after confirmed repeat, Archive Summary,
  /// Weekly Review, Private Report preview, or Pattern Changed; never on first save.
  static bool showFullArchiveHistoryProBoundary({
    int? magicMomentsCount,
    int? entryCount,
    required bool resolved,
    required bool isPro,
    required bool isPostSave,
    required bool hasConfirmedRepeat,
    required bool hasArchiveSummary,
    required bool hasWeeklyArchiveReview,
    bool hasPatternChanged = false,
    bool hasPrivateArchiveReportPreview = false,
    bool hasReturnCheckAnswered = false,
  }) {
    final moments = magicMomentsCount ?? entryCount ?? 0;
    if (isPro || resolved || isPostSave) return false;
    if (moments < minEvidenceMilestonesForPaywall) return false;
    return hasConfirmedRepeat ||
        hasArchiveSummary ||
        hasWeeklyArchiveReview ||
        hasPatternChanged ||
        hasPrivateArchiveReportPreview ||
        hasReturnCheckAnswered;
  }

  /// Pro bridge after a real value surface — never on first save, never blocking recording.
  static bool showPostProofProBridge({
    int? magicMomentsCount,
    int? entryCount,
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
    bool hasReturnCheckAnswered = false,
  }) => showFullArchiveHistoryProBoundary(
    magicMomentsCount: magicMomentsCount,
    entryCount: entryCount,
    resolved: resolved,
    isPro: isPro,
    isPostSave: isPostSave,
    hasConfirmedRepeat:
        viewingConfirmedRepeatOrTimeline &&
        (hasConfirmedRepeatProof(
              hasArchiveProof: hasArchiveProof,
              hasChangeOverTimeProof: hasChangeOverTimeProof,
            ) ||
            hasArchiveProof),
    hasArchiveSummary: hasArchiveSummary,
    hasWeeklyArchiveReview: hasWeeklyArchiveReview,
    hasPatternChanged: hasPatternChanged,
    hasPrivateArchiveReportPreview: hasPrivateArchiveReportPreview,
    hasReturnCheckAnswered: hasReturnCheckAnswered,
  );

  static bool hasConfirmedRepeatProof({
    required bool hasArchiveProof,
    required bool hasChangeOverTimeProof,
  }) => hasArchiveProof || hasChangeOverTimeProof;

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