/// Stable milestone share identifiers — ordered for primary selection.
enum MilestoneShareId {
  firstSavedMoment,
  threeMomentsSaved,
  firstWatchThemeChosen,
  firstWeekPathComplete,
  firstWeeklyReview,
  firstRepeatingTheme,
  firstThenVsNowAvailable,
  archiveCalendarActive,
}

/// One share-safe milestone card — fixed copy only, never journal text.
class MilestoneShareCard {
  const MilestoneShareCard({
    required this.milestoneId,
    required this.title,
    required this.body,
    required this.safeShareText,
    required this.proofLabel,
    required this.ctaLabel,
    required this.ctaRoute,
    required this.isShareable,
    required this.evidenceCountLabel,
    required this.createdFromCountsOnly,
    required this.rank,
  });

  final MilestoneShareId milestoneId;
  final String title;
  final String body;
  final String safeShareText;
  final String proofLabel;
  final String ctaLabel;
  final String ctaRoute;
  final bool isShareable;
  final String evidenceCountLabel;
  final bool createdFromCountsOnly;
  final int rank;
}

/// Metadata-only inputs for milestone share cards.
class MilestoneShareInput {
  const MilestoneShareInput({
    required this.realSavedMomentCount,
    required this.usableEvidenceCount,
    required this.firstWeekComplete,
    required this.hasWatchTheme,
    required this.weeklyReviewAvailable,
    required this.hasRepeatingTheme, required this.thenVsNowAvailable, required this.archiveCalendarActiveAcrossDays, this.weeklyReviewCompleted = false,
    this.sampleMode = false,
  });

  final int realSavedMomentCount;
  final int usableEvidenceCount;
  final bool firstWeekComplete;
  final bool hasWatchTheme;
  final bool weeklyReviewAvailable;
  final bool weeklyReviewCompleted;
  final bool hasRepeatingTheme;
  final bool thenVsNowAvailable;
  final bool archiveCalendarActiveAcrossDays;
  final bool sampleMode;
}

/// Engine output — available cards and Archive Home summary.
class MilestoneShareResult {
  const MilestoneShareResult({
    required this.cards,
    required this.primaryCard,
    required this.totalAvailableCount,
    required this.isEmpty,
    required this.showOnArchiveHome,
    required this.hasCard,
    required this.cardHeadline,
    required this.cardSummary,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.emptyTitle,
    required this.emptyBody,
    required this.emptyCtaLabel,
    required this.emptyCtaRoute,
  });

  static const empty = MilestoneShareResult(
    cards: [],
    primaryCard: null,
    totalAvailableCount: 0,
    isEmpty: true,
    showOnArchiveHome: false,
    hasCard: false,
    cardHeadline: '',
    cardSummary: '',
    primaryCtaLabel: '',
    primaryRoute: '',
    emptyTitle: '',
    emptyBody: '',
    emptyCtaLabel: '',
    emptyCtaRoute: '',
  );

  final List<MilestoneShareCard> cards;
  final MilestoneShareCard? primaryCard;
  final int totalAvailableCount;
  final bool isEmpty;
  final bool showOnArchiveHome;
  final bool hasCard;
  final String cardHeadline;
  final String cardSummary;
  final String primaryCtaLabel;
  final String primaryRoute;
  final String emptyTitle;
  final String emptyBody;
  final String emptyCtaLabel;
  final String emptyCtaRoute;
}