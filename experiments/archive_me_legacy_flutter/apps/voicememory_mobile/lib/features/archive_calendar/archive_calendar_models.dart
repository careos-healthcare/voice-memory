/// Local inputs for Archive Calendar — metadata only.
class ArchiveCalendarInput {
  const ArchiveCalendarInput({
    required this.realSavedMomentCount,
    required this.now,
    this.sampleMode = false,
    this.weeklyReviewAvailable = false,
    this.hasWatchTheme = false,
    this.thenVsNowAvailable = false,
    this.daySummaries = const [],
  });

  final int realSavedMomentCount;
  final DateTime now;
  final bool sampleMode;
  final bool weeklyReviewAvailable;
  final bool hasWatchTheme;
  final bool thenVsNowAvailable;
  final List<ArchiveCalendarDaySummary> daySummaries;
}

/// Safe day summary — counts and marker labels only.
class ArchiveCalendarDaySummary {
  const ArchiveCalendarDaySummary({
    required this.date,
    required this.dayLabel,
    required this.momentCount,
    required this.markerLabels,
    required this.isToday,
    required this.isMostActiveDay,
  });

  final DateTime date;
  final String dayLabel;
  final int momentCount;
  final List<String> markerLabels;
  final bool isToday;
  final bool isMostActiveDay;
}

/// Archive Calendar output — activity counts only, no journal text.
class ArchiveCalendarResult {
  const ArchiveCalendarResult({
    required this.isEmpty,
    required this.hasCard,
    required this.showOnArchiveHome,
    required this.totalMomentCount,
    required this.activeDayCount,
    required this.monthLabel,
    required this.days,
    required this.weekSummaryLabel,
    required this.monthlyTotalLabel,
    required this.mostActiveDayLabel,
    required this.helperText,
    required this.privacyLine,
    required this.cardHeadline,
    required this.cardSummary,
    required this.emptyTitle,
    required this.emptyBody,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.recordRoute,
    required this.archiveHomeRoute,
    required this.dayDetailArchiveHomeCta,
    required this.dayDetailRecordCta,
  });

  final bool isEmpty;
  final bool hasCard;
  final bool showOnArchiveHome;
  final int totalMomentCount;
  final int activeDayCount;
  final String monthLabel;
  final List<ArchiveCalendarDaySummary> days;
  final String weekSummaryLabel;
  final String monthlyTotalLabel;
  final String mostActiveDayLabel;
  final String helperText;
  final String privacyLine;
  final String cardHeadline;
  final String cardSummary;
  final String emptyTitle;
  final String emptyBody;
  final String primaryCtaLabel;
  final String primaryRoute;
  final String recordRoute;
  final String archiveHomeRoute;
  final String dayDetailArchiveHomeCta;
  final String dayDetailRecordCta;

  static const empty = ArchiveCalendarResult(
    isEmpty: true,
    hasCard: false,
    showOnArchiveHome: false,
    totalMomentCount: 0,
    activeDayCount: 0,
    monthLabel: '',
    days: [],
    weekSummaryLabel: '',
    monthlyTotalLabel: '',
    mostActiveDayLabel: '',
    helperText: '',
    privacyLine: '',
    cardHeadline: '',
    cardSummary: '',
    emptyTitle: '',
    emptyBody: '',
    primaryCtaLabel: '',
    primaryRoute: '',
    recordRoute: '',
    archiveHomeRoute: '',
    dayDetailArchiveHomeCta: '',
    dayDetailRecordCta: '',
  );
}
