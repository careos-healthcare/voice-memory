/// Stage of the calm 2-day activation path.
enum TwoDayActivationStage {
  /// Nothing to show — activated, enough entries, or mid-path moment.
  none,

  /// Brand-new user, before the first save: the 2-day plan.
  dayOneIntro,

  /// Right after the very first save: day 1 closure.
  dayOneComplete,

  /// The user came back with day 1 saved: the return moment.
  dayTwoReturn,
}

/// One stage of the 2-day path, with its exact copy. Never a streak, never
/// an obligation — the path quietly disappears once it has done its job.
class TwoDayActivationPath {
  const TwoDayActivationPath({
    required this.stage,
    this.title = '',
    this.lines = const [],
  });

  factory TwoDayActivationPath.none() =>
      const TwoDayActivationPath(stage: TwoDayActivationStage.none);

  final TwoDayActivationStage stage;
  final String title;
  final List<String> lines;

  bool get show => stage != TwoDayActivationStage.none;

  /// Hidden once the archive holds this many entries — the loop is running.
  static const int hiddenEntryCount = 3;

  // Day 1 — first session, before anything is saved.
  static const String dayOneTitle = 'Try ArchiveMe for 2 days';
  static const List<String> dayOneLines = [
    'Today: record one small thing.',
    'Tomorrow: check whether it returned, faded, or changed.',
    'That is enough.',
  ];

  // Day 1 — right after the first save.
  static const String dayOneCompleteTitle = 'Day 1 complete';
  static const String dayOneCompleteLine =
      'Tomorrow, ArchiveMe can compare this with what shows up next.';

  /// Concrete reason to return — makes tomorrow's check feel small and
  /// specific before the user leaves day 1. Never a streak or obligation.
  static const String dayOneReturnReasonLine =
      'Tomorrow\u2019s check is simple: did this return, fade, or change?';

  // Day 2 — the return moment.
  static const String dayTwoTitle = 'Day 2: check what changed';
  static const String dayTwoLine =
      'See whether yesterday\u2019s thread returned, faded, or changed.';

  /// Used when the last save was not literally yesterday, or when entry
  /// dates look unreliable — never claims "yesterday" it cannot back up.
  static const String dayTwoCautiousLine =
      'See whether an earlier recording returned, faded, or changed.';
}

/// Decides which stage of the 2-day path to show. Pure and deterministic —
/// built only from the entry count and saved entry dates, no AI, no stored
/// path state, no streak tracking. Missing a day changes nothing except
/// which honest line is shown.
class TwoDayActivationEngine {
  const TwoDayActivationEngine();

  /// Pre-recording stage for the ready screen.
  ///
  /// - 0 entries → the 2-day plan.
  /// - 3+ entries → nothing; the loop is already running.
  /// - Entries on 2+ distinct days → nothing; the return moment happened.
  /// - Newest entry today → nothing; today is already done.
  /// - Otherwise → the day-2 return moment. The "yesterday" line is used
  ///   only when the newest save was genuinely yesterday; unreliable dates
  ///   (missing or in the future) fall back to count-only cautious copy.
  TwoDayActivationPath build({
    required int entryCount,
    List<DateTime> entryDates = const [],
    DateTime? now,
  }) {
    if (entryCount >= TwoDayActivationPath.hiddenEntryCount) {
      return TwoDayActivationPath.none();
    }
    if (entryCount == 0) {
      return const TwoDayActivationPath(
        stage: TwoDayActivationStage.dayOneIntro,
        title: TwoDayActivationPath.dayOneTitle,
        lines: TwoDayActivationPath.dayOneLines,
      );
    }

    final clock = now ?? DateTime.now();
    final datesReliable =
        entryDates.isNotEmpty && !entryDates.any((d) => d.isAfter(clock));
    if (!datesReliable) {
      // Count-only fallback: 1-2 entries exist, so a comparison is possible,
      // but no day claims are made.
      return const TwoDayActivationPath(
        stage: TwoDayActivationStage.dayTwoReturn,
        title: TwoDayActivationPath.dayTwoTitle,
        lines: [TwoDayActivationPath.dayTwoCautiousLine],
      );
    }

    final days = entryDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    if (days.length >= 2) {
      // Recorded on two different days — the return moment already happened.
      return TwoDayActivationPath.none();
    }
    final newest = entryDates.reduce((a, b) => a.isAfter(b) ? a : b);
    if (_sameDay(newest, clock)) {
      // Day 1 is done today; the post-save receipt owns that moment.
      return TwoDayActivationPath.none();
    }

    final yesterday = clock.subtract(const Duration(days: 1));
    final line = _sameDay(newest, yesterday)
        ? TwoDayActivationPath.dayTwoLine
        : TwoDayActivationPath.dayTwoCautiousLine;
    return TwoDayActivationPath(
      stage: TwoDayActivationStage.dayTwoReturn,
      title: TwoDayActivationPath.dayTwoTitle,
      lines: [line],
    );
  }

  /// Post-save stage: day 1 closure after the very first save only — with
  /// the concrete reason tomorrow matters.
  TwoDayActivationPath buildPostSave({required int entryCount}) {
    if (entryCount != 1) return TwoDayActivationPath.none();
    return const TwoDayActivationPath(
      stage: TwoDayActivationStage.dayOneComplete,
      title: TwoDayActivationPath.dayOneCompleteTitle,
      lines: [
        TwoDayActivationPath.dayOneCompleteLine,
        TwoDayActivationPath.dayOneReturnReasonLine,
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
