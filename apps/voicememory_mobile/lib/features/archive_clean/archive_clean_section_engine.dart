import '../archive_memory/archive_evolution_model.dart';
import '../archive_memory/archive_memory_summary_model.dart';
import '../archive_review/archive_range_review_model.dart';
import '../moments/key_moment_model.dart';
import '../pattern_memory/pattern_memory_model.dart';
import 'archive_clean_section_model.dart';

/// Builds the ordered archive clean sections from saved local data only.
List<ArchiveCleanSection> buildArchiveCleanSections({
  required List<KeyMoment> keyMoments,
  PatternMemory? memory,
  ArchiveMemorySummary? summary,
  ArchiveEvolutionTimeline? timeline,
  bool hasCheckInToday = false,
  bool hasCompressionGroups = false,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final weekAgo = clock.subtract(const Duration(days: 7));

  final todayCount =
      keyMoments.where((m) => _isSameDay(m.date, clock)).length;
  final weekCount =
      keyMoments.where((m) => m.date.isAfter(weekAgo)).length;
  final olderCount =
      keyMoments.where((m) => !m.date.isAfter(weekAgo)).length;

  final hasPattern =
      memory != null || summary != null || timeline != null;
  final patternSubtitle = _patternSubtitle(memory, summary, timeline);

  final sections = <ArchiveCleanSection>[];

  if (todayCount > 0 || hasCheckInToday) {
    sections.add(
      ArchiveCleanSection(
        type: ArchiveCleanSectionType.today,
        title: 'Today',
        subtitle: 'Moments and checks from today',
        primaryCtaLabel: 'Open today',
        route: '/moments',
        count: todayCount > 0 ? todayCount : null,
      ),
    );
  }

  if (weekCount > 0) {
    sections.add(
      ArchiveCleanSection(
        type: ArchiveCleanSectionType.thisWeek,
        title: 'This week',
        subtitle: 'Moments from the last 7 days',
        primaryCtaLabel: 'Open this week',
        route: '/moments',
        count: weekCount,
      ),
    );
  }

  if (hasPattern) {
    sections.add(
      ArchiveCleanSection(
        type: ArchiveCleanSectionType.thisPattern,
        title: 'This pattern',
        subtitle: patternSubtitle,
        primaryCtaLabel: 'Open pattern',
        route: '/pattern-profile',
      ),
    );
  }

  if (keyMoments.length >= ArchiveRangeReview.minMomentsForReview) {
    sections.add(
      const ArchiveCleanSection(
        type: ArchiveCleanSectionType.reviewPeriod,
        title: 'Review this period',
        subtitle: 'See what repeated, changed, or helped.',
        primaryCtaLabel: 'Open review',
        route: '/archive-review',
      ),
    );
  }

  if (keyMoments.isNotEmpty) {
    sections.add(
      const ArchiveCleanSection(
        type: ArchiveCleanSectionType.askArchive,
        title: 'Ask my Archive',
        subtitle: 'Find what ArchiveMe remembers.',
        primaryCtaLabel: 'Search moments',
        route: '/ask-archive',
      ),
    );
  }

  if (olderCount > 0) {
    sections.add(
      ArchiveCleanSection(
        type: ArchiveCleanSectionType.olderMoments,
        title: 'Older moments',
        subtitle: 'Moments from before this week',
        primaryCtaLabel: 'Find older moments',
        route: '/moments',
        count: olderCount,
      ),
    );
  }

  if (hasCompressionGroups) {
    sections.add(
      const ArchiveCleanSection(
        type: ArchiveCleanSectionType.cleanUpArchive,
        title: 'Clean up archive',
        subtitle: 'Group similar moments so your archive stays useful.',
        primaryCtaLabel: 'Open cleanup',
        route: '/archive-cleanup',
      ),
    );
  }

  return sections;
}

String _patternSubtitle(
  PatternMemory? memory,
  ArchiveMemorySummary? summary,
  ArchiveEvolutionTimeline? timeline,
) {
  final title = memory?.patternTitle ??
      timeline?.patternTitle ??
      summary?.patternTitle;
  if (title != null && title.trim().isNotEmpty) {
    return title.trim();
  }
  return 'What keeps showing up over time';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
