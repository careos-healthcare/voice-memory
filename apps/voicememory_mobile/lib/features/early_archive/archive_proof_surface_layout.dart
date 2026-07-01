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
    this.archiveSummaryVisible = false,
  });

  final bool confirmedRepeatCardVisible;
  final bool timelineVisible;
  final bool changeProofVisible;
  final bool proBridgeVisible;
  final bool whyMattersVisible;
  final bool thoughtMapVisible;
  final bool positivePatternVisible;
  final bool positiveReinforcementVisible;
  final bool archiveSummaryVisible;

  /// Supporting cards fold into Archive Summary when it is visible.
  bool get effectiveWhyMattersVisible =>
      whyMattersVisible && !archiveSummaryVisible;

  bool get effectiveThoughtMapVisible =>
      thoughtMapVisible && !archiveSummaryVisible;

  bool get effectivePositiveReinforcementVisible =>
      positiveReinforcementVisible && !archiveSummaryVisible;

  bool get effectivePositivePatternVisible =>
      positivePatternVisible &&
      !archiveSummaryVisible &&
      !positiveReinforcementVisible;

  bool get effectiveChangeProofVisible =>
      changeProofVisible && !archiveSummaryVisible;

  /// Timeline uses shorter nearby copy when confirmed repeat context is active.
  bool get timelineNearby =>
      confirmedRepeatCardVisible || (timelineVisible && changeProofVisible);

  /// Evidence phrase chips belong on the confirmed repeat card when both show.
  bool get suppressTimelineEvidencePhrases => confirmedRepeatCardVisible;

  /// Pro bridge shortens when change-over-time proof is already visible.
  bool get proBridgeCompact => changeProofVisible;
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
