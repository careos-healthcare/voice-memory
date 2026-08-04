/// Deterministic Patterns tab order after first proof (layout pass only).
abstract final class PatternsPostProofStackOrder {
  PatternsPostProofStackOrder._();

  static const archiveCurrentBelief = 'archive_current_belief';
  static const whatChangedSinceLastTime = 'what_changed_since_last_time';
  static const earlyEvidenceTimeline = 'early_evidence_timeline';
  static const earlyFirstSignalFallback = 'early_first_signal_fallback';
  static const archiveChangeTimeline = 'archive_change_timeline';
  static const patternChanged = 'pattern_changed';
  static const helpfulActionAppeared = 'helpful_action_appeared';
  static const archiveSummary = 'archive_summary';
  static const weeklyReview = 'weekly_review';
  static const privateArchiveReport = 'private_archive_report';
  static const proBridge = 'pro_bridge';

  static const primarySurfacesAfterFirstProof = [
    archiveCurrentBelief,
    whatChangedSinceLastTime,
    earlyEvidenceTimeline,
  ];
}

/// Which proof cards are visible together — drives de-duplicated copy.
class ArchiveProofSurfaceLayout {
  const ArchiveProofSurfaceLayout({
    required this.confirmedRepeatCardVisible,
    required this.timelineVisible,
    required this.changeProofVisible,
    required this.proBridgeVisible,
    this.whyMattersVisible = false,
    this.thoughtMapVisible = false,
    this.positivePatternVisible = false,
    this.positiveReinforcementVisible = false,
    this.patternChangedVisible = false,
    this.helpfulActionAppearedVisible = false,
    this.archiveSummaryVisible = false,
    this.archiveCurrentBeliefVisible = false,
    this.archiveChangeTimelineVisible = false,
    this.timelineShowsHelpfulAction = false,
    this.changeTimelineShowsHelpfulAction = false,
    this.changeTimelineShowsChanged = false,
  });

  final bool confirmedRepeatCardVisible;
  final bool timelineVisible;
  final bool changeProofVisible;
  final bool proBridgeVisible;
  final bool whyMattersVisible;
  final bool thoughtMapVisible;
  final bool positivePatternVisible;
  final bool positiveReinforcementVisible;
  final bool patternChangedVisible;
  final bool helpfulActionAppearedVisible;
  final bool archiveSummaryVisible;
  final bool archiveCurrentBeliefVisible;
  final bool archiveChangeTimelineVisible;
  final bool timelineShowsHelpfulAction;
  final bool changeTimelineShowsHelpfulAction;
  final bool changeTimelineShowsChanged;

  /// Current-belief surface replaces Archive Summary as the main overview.
  bool get effectiveArchiveSummaryVisible =>
      archiveSummaryVisible && !archiveCurrentBeliefVisible;

  /// Supporting cards fold into Archive Summary when it is visible.
  bool get effectiveWhyMattersVisible =>
      whyMattersVisible && !effectiveArchiveSummaryVisible;

  bool get effectiveThoughtMapVisible =>
      thoughtMapVisible && !effectiveArchiveSummaryVisible;

  bool get effectivePositiveReinforcementVisible =>
      positiveReinforcementVisible &&
      !effectiveArchiveSummaryVisible &&
      !helpfulActionAppearedVisible;

  bool get effectiveHelpfulActionAppearedVisible =>
      helpfulActionAppearedVisible &&
      !effectiveArchiveSummaryVisible &&
      !timelineShowsHelpfulAction &&
      !changeTimelineShowsHelpfulAction;

  bool get effectivePositivePatternVisible =>
      positivePatternVisible &&
      !effectiveArchiveSummaryVisible &&
      !positiveReinforcementVisible;

  bool get effectiveChangeProofVisible =>
      changeProofVisible &&
      !effectiveArchiveSummaryVisible &&
      !patternChangedVisible;

  bool get effectivePatternChangedVisible =>
      patternChangedVisible &&
      !effectiveArchiveSummaryVisible &&
      !changeTimelineShowsChanged;

  /// Confirmed-repeat card folds into Archive Summary or current belief.
  bool get effectiveConfirmedRepeatCardVisible =>
      confirmedRepeatCardVisible &&
      !effectiveArchiveSummaryVisible &&
      !archiveCurrentBeliefVisible;

  /// Full timeline stays on Patterns; Record folds it into Archive Summary.
  bool recordTimelineVisible({required bool surfaceIsRecord}) =>
      timelineVisible &&
      !(surfaceIsRecord && effectiveArchiveSummaryVisible) &&
      !archiveCurrentBeliefVisible;

  /// Pattern-changed celebration stays visible on Record above Archive Summary.
  bool get recordPatternChangedVisible => patternChangedVisible;

  /// Timeline uses shorter nearby copy when confirmed repeat context is active.
  bool get timelineNearby =>
      confirmedRepeatCardVisible || (timelineVisible && changeProofVisible);

  /// Evidence phrase chips belong on the confirmed repeat card when both show.
  bool get suppressTimelineEvidencePhrases => confirmedRepeatCardVisible;

  /// Pro bridge shortens when change-over-time proof is already visible.
  bool get proBridgeCompact => changeProofVisible || patternChangedVisible;
}

/// Counts repeated proof phrases across visible copy blocks (tests + guards).
abstract final class ArchiveProofCopyDedup {
  ArchiveProofCopyDedup._();

  static int countPhrase(String haystack, String phrase) {
    if (phrase.isEmpty) return 0;
    var count = 0;
    var start = 0;
    while (true) {
      final index = haystack.indexOf(phrase, start);
      if (index < 0) break;
      count++;
      start = index + phrase.length;
    }
    return count;
  }

  static bool phrasesWithinLimit({
    required Iterable<String> copyBlocks,
    required Iterable<String> onceOnlyPhrases,
    int maxCount = 1,
  }) {
    final joined = copyBlocks.join('\n');
    for (final phrase in onceOnlyPhrases) {
      if (countPhrase(joined, phrase) > maxCount) return false;
    }
    return true;
  }
}
