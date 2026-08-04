import '../../models/journal_entry.dart';
import '../demo/sample_archive_mode.dart';
import 'archive_calendar_copy.dart';
import 'archive_calendar_gates.dart';
import 'archive_calendar_models.dart';

/// Deterministic local calendar builder — counts and marker labels only.
class ArchiveCalendarEngine {
  const ArchiveCalendarEngine();

  ArchiveCalendarResult buildFromJournal({
    required List<JournalEntry> entries,
    DateTime? now,
    bool weeklyReviewAvailable = false,
    bool hasWatchTheme = false,
    bool thenVsNowAvailable = false,
    bool sampleMode = false,
  }) {
    final realEntries = _realEntries(entries);
    final daySummaries = _buildDaySummaries(
      entries: realEntries,
      now: now ?? DateTime.now(),
      weeklyReviewAvailable: weeklyReviewAvailable,
      hasWatchTheme: hasWatchTheme,
      thenVsNowAvailable: thenVsNowAvailable,
    );
    return build(
      ArchiveCalendarInput(
        realSavedMomentCount: realEntries.length,
        now: now ?? DateTime.now(),
        sampleMode: sampleMode,
        weeklyReviewAvailable: weeklyReviewAvailable,
        hasWatchTheme: hasWatchTheme,
        thenVsNowAvailable: thenVsNowAvailable,
        daySummaries: daySummaries,
      ),
    );
  }

  ArchiveCalendarResult build(ArchiveCalendarInput input) {
    if (input.sampleMode) {
      return _sampleResult(input.now);
    }

    if (input.realSavedMomentCount <= 0 || input.daySummaries.isEmpty) {
      return _emptyResult();
    }

    final days = input.daySummaries;
    final monthLabel = _monthYearLabel(input.now);
    final weekStart = _startOfWeek(input.now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekDays = days.where((day) {
      final local = day.date;
      return !local.isBefore(weekStart) && local.isBefore(weekEnd);
    }).toList();
    final weekCount = weekDays.fold<int>(
      0,
      (sum, day) => sum + day.momentCount,
    );
    final monthCount = days
        .where(
          (day) =>
              day.date.year == input.now.year &&
              day.date.month == input.now.month,
        )
        .fold<int>(0, (sum, day) => sum + day.momentCount);
    final mostActive = days.reduce(
      (current, next) =>
          next.momentCount > current.momentCount ? next : current,
    );
    final showOnArchiveHome = ArchiveCalendarGates.showOnArchiveHome(
      realSavedMomentCount: input.realSavedMomentCount,
      sampleMode: input.sampleMode,
    );

    return ArchiveCalendarResult(
      isEmpty: false,
      hasCard: true,
      showOnArchiveHome: showOnArchiveHome,
      totalMomentCount: input.realSavedMomentCount,
      activeDayCount: days.length,
      monthLabel: monthLabel,
      days: days,
      weekSummaryLabel: ArchiveCalendarCopy.weekSummaryLabel(
        count: weekCount,
        dayCount: weekDays.length,
      ),
      monthlyTotalLabel: ArchiveCalendarCopy.monthlyTotalLabel(
        count: monthCount,
        monthLabel: monthLabel,
      ),
      mostActiveDayLabel: ArchiveCalendarCopy.mostActiveDayLabel(
        mostActive.dayLabel,
        mostActive.momentCount,
      ),
      helperText: weekCount <= 1
          ? ArchiveCalendarCopy.weekCompareHelper
          : ArchiveCalendarCopy.helperText,
      privacyLine: ArchiveCalendarCopy.privacyLine,
      cardHeadline: ArchiveCalendarCopy.cardHeadlineActive,
      cardSummary: ArchiveCalendarCopy.cardSummaryActive,
      emptyTitle: ArchiveCalendarCopy.emptyTitle,
      emptyBody: ArchiveCalendarCopy.emptyBody,
      primaryCtaLabel: ArchiveCalendarCopy.openCalendarCta,
      primaryRoute: ArchiveCalendarCopy.route,
      recordRoute: ArchiveCalendarCopy.recordRoute,
      archiveHomeRoute: ArchiveCalendarCopy.archiveHomeRoute,
      dayDetailArchiveHomeCta: ArchiveCalendarCopy.dayDetailArchiveHomeCta,
      dayDetailRecordCta: ArchiveCalendarCopy.dayDetailRecordCta,
    );
  }

  static List<JournalEntry> _realEntries(List<JournalEntry> entries) {
    return SampleArchiveMode.excludeSampleEntries(entries)
        .where(
          (entry) =>
              entry.transcript.trim().isNotEmpty &&
              !entry.transcript.startsWith('[draft]'),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static List<ArchiveCalendarDaySummary> _buildDaySummaries({
    required List<JournalEntry> entries,
    required DateTime now,
    required bool weeklyReviewAvailable,
    required bool hasWatchTheme,
    required bool thenVsNowAvailable,
  }) {
    if (entries.isEmpty) return const [];

    final grouped = <DateTime, List<JournalEntry>>{};
    for (final entry in entries) {
      final local = entry.createdAt.toLocal();
      final dayKey = DateTime(local.year, local.month, local.day);
      grouped.putIfAbsent(dayKey, () => []).add(entry);
    }

    final newerHalfStart = entries.length <= 1
        ? entries.last.createdAt
        : entries[(entries.length / 2).ceil()].createdAt;
    final weeklyWindowStart = weeklyReviewAvailable
        ? entries.last.createdAt.toLocal().subtract(const Duration(days: 6))
        : null;
    final maxCount = grouped.values
        .map((dayEntries) => dayEntries.length)
        .fold<int>(0, (max, count) => count > max ? count : max);

    return grouped.entries.map((entry) {
      final day = entry.key;
      final dayEntries = entry.value;
      final count = dayEntries.length;
      final markers = <String>[
        if (count == 1)
          ArchiveCalendarCopy.markerOneMoment
        else
          ArchiveCalendarCopy.markerMultipleMoments,
      ];

      if (weeklyWindowStart != null &&
          !day.isBefore(
            DateTime(
              weeklyWindowStart.year,
              weeklyWindowStart.month,
              weeklyWindowStart.day,
            ),
          )) {
        markers.add(ArchiveCalendarCopy.markerWeeklyReview);
      }

      if (hasWatchTheme &&
          dayEntries.any(
            (entry) => entry.reflection.recurringThemes.isNotEmpty,
          )) {
        markers.add(ArchiveCalendarCopy.markerWatchTheme);
      }

      if (thenVsNowAvailable &&
          dayEntries.any(
            (entry) => !entry.createdAt.isBefore(newerHalfStart),
          )) {
        markers.add(ArchiveCalendarCopy.markerThenVsNow);
      }

      final localNow = now.toLocal();
      final isToday =
          day.year == localNow.year &&
          day.month == localNow.month &&
          day.day == localNow.day;

      return ArchiveCalendarDaySummary(
        date: day,
        dayLabel: _dayLabel(day),
        momentCount: count,
        markerLabels: markers,
        isToday: isToday,
        isMostActiveDay: count == maxCount && maxCount > 0,
      );
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static ArchiveCalendarResult _emptyResult() {
    return ArchiveCalendarResult(
      isEmpty: true,
      hasCard: false,
      showOnArchiveHome: false,
      totalMomentCount: 0,
      activeDayCount: 0,
      monthLabel: '',
      days: const [],
      weekSummaryLabel: '',
      monthlyTotalLabel: '',
      mostActiveDayLabel: ArchiveCalendarCopy.noMostActiveDayLabel(),
      helperText: ArchiveCalendarCopy.helperText,
      privacyLine: ArchiveCalendarCopy.privacyLine,
      cardHeadline: '',
      cardSummary: '',
      emptyTitle: ArchiveCalendarCopy.emptyTitle,
      emptyBody: ArchiveCalendarCopy.emptyBody,
      primaryCtaLabel: ArchiveCalendarCopy.saveMomentCta,
      primaryRoute: ArchiveCalendarCopy.recordRoute,
      recordRoute: ArchiveCalendarCopy.recordRoute,
      archiveHomeRoute: ArchiveCalendarCopy.archiveHomeRoute,
      dayDetailArchiveHomeCta: ArchiveCalendarCopy.dayDetailArchiveHomeCta,
      dayDetailRecordCta: ArchiveCalendarCopy.dayDetailRecordCta,
    );
  }

  static ArchiveCalendarResult _sampleResult(DateTime now) {
    final sampleDay = DateTime(now.year, now.month, now.day);
    final day = ArchiveCalendarDaySummary(
      date: sampleDay,
      dayLabel: _dayLabel(sampleDay),
      momentCount: 2,
      markerLabels: const [ArchiveCalendarCopy.markerMultipleMoments],
      isToday: true,
      isMostActiveDay: true,
    );
    return ArchiveCalendarResult(
      isEmpty: false,
      hasCard: true,
      showOnArchiveHome: false,
      totalMomentCount: 2,
      activeDayCount: 1,
      monthLabel: _monthYearLabel(now),
      days: [day],
      weekSummaryLabel: ArchiveCalendarCopy.weekSummaryLabel(
        count: 2,
        dayCount: 1,
      ),
      monthlyTotalLabel: ArchiveCalendarCopy.monthlyTotalLabel(
        count: 2,
        monthLabel: _monthYearLabel(now),
      ),
      mostActiveDayLabel: ArchiveCalendarCopy.mostActiveDayLabel(
        day.dayLabel,
        2,
      ),
      helperText: ArchiveCalendarCopy.helperText,
      privacyLine: ArchiveCalendarCopy.privacyLine,
      cardHeadline: ArchiveCalendarCopy.screenshotHeadline,
      cardSummary: ArchiveCalendarCopy.screenshotSummary,
      emptyTitle: ArchiveCalendarCopy.emptyTitle,
      emptyBody: ArchiveCalendarCopy.emptyBody,
      primaryCtaLabel: ArchiveCalendarCopy.openCalendarCta,
      primaryRoute: ArchiveCalendarCopy.route,
      recordRoute: ArchiveCalendarCopy.recordRoute,
      archiveHomeRoute: ArchiveCalendarCopy.archiveHomeRoute,
      dayDetailArchiveHomeCta: ArchiveCalendarCopy.dayDetailArchiveHomeCta,
      dayDetailRecordCta: ArchiveCalendarCopy.dayDetailRecordCta,
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final local = date.toLocal();
    final weekday = local.weekday;
    return DateTime(
      local.year,
      local.month,
      local.day,
    ).subtract(Duration(days: weekday - DateTime.monday));
  }

  static String _dayLabel(DateTime day) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }

  static String _monthYearLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.year}';
  }
}
