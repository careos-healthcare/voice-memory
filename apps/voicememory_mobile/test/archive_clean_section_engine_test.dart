import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_clean/archive_clean_section_engine.dart';
import 'package:voicememory_mobile/features/archive_clean/archive_clean_section_model.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';

KeyMoment _moment(String id, DateTime date) => KeyMoment(
      id: id,
      date: date,
      title: 'Moment $id',
      originalText: 'text',
      shortSummary: 'text',
    );

ArchiveMemorySummary _summary() => const ArchiveMemorySummary(
      id: 's1',
      patternTitle: 'Pressure before yes',
      primaryMemoryLine: 'You often say yes before checking in.',
      basedOnMomentCount: 4,
      basedOnWeekCount: 2,
      clarityLabel: 'Clear pattern',
    );

void main() {
  final now = DateTime(2026, 6, 6, 12);

  test('returns sections only when available', () {
    final sections = buildArchiveCleanSections(
      keyMoments: const [],
      now: now,
    );
    expect(sections, isEmpty);
  });

  test('order includes review period when enough moments', () {
    final sections = buildArchiveCleanSections(
      keyMoments: [
        _moment('a', DateTime(2026, 6, 6)),
        _moment('b', DateTime(2026, 6, 5)),
        _moment('c', DateTime(2026, 6, 4)),
      ],
      now: now,
    );
    expect(
      sections.any((s) => s.type == ArchiveCleanSectionType.reviewPeriod),
      isTrue,
    );
    final review = sections.firstWhere(
      (s) => s.type == ArchiveCleanSectionType.reviewPeriod,
    );
    expect(review.title, 'Review this period');
    expect(review.route, '/archive-review');
  });

  test('order is Today, This week, This pattern, Ask Archive, Older moments',
      () {
    final sections = buildArchiveCleanSections(
      keyMoments: [
        _moment('today', DateTime(2026, 6, 6, 9)),
        _moment('week', DateTime(2026, 6, 3)),
        _moment('old', DateTime(2026, 5, 20)),
      ],
      memory: PatternMemory(
        id: 'p1',
        patternTitle: 'Test pattern',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 6, 6),
      ),
      now: now,
    );
    expect(
      sections.map((s) => s.type),
      [
        ArchiveCleanSectionType.today,
        ArchiveCleanSectionType.thisWeek,
        ArchiveCleanSectionType.thisPattern,
        ArchiveCleanSectionType.askArchive,
        ArchiveCleanSectionType.olderMoments,
      ],
    );
  });

  test('counts are conservative and grounded', () {
    final sections = buildArchiveCleanSections(
      keyMoments: [
        _moment('today', DateTime(2026, 6, 6, 9)),
        _moment('week', DateTime(2026, 6, 4)),
        _moment('old', DateTime(2026, 5, 20)),
      ],
      now: now,
    );
    final today = sections.firstWhere((s) => s.type == ArchiveCleanSectionType.today);
    final week = sections.firstWhere((s) => s.type == ArchiveCleanSectionType.thisWeek);
    final older =
        sections.firstWhere((s) => s.type == ArchiveCleanSectionType.olderMoments);

    expect(today.count, 1);
    expect(week.count, 2);
    expect(older.count, 1);
  });

  test('Ask Archive appears when at least one moment exists', () {
    final sections = buildArchiveCleanSections(
      keyMoments: [_moment('a', DateTime(2026, 6, 6))],
      now: now,
    );
    expect(
      sections.any((s) => s.type == ArchiveCleanSectionType.askArchive),
      isTrue,
    );
  });

  test('older moments appears only when older than 7 days exist', () {
    final recentOnly = buildArchiveCleanSections(
      keyMoments: [_moment('a', DateTime(2026, 6, 6))],
      now: now,
    );
    expect(
      recentOnly.any((s) => s.type == ArchiveCleanSectionType.olderMoments),
      isFalse,
    );

    final withOlder = buildArchiveCleanSections(
      keyMoments: [
        _moment('a', DateTime(2026, 6, 6)),
        _moment('b', DateTime(2026, 5, 20)),
      ],
      now: now,
    );
    expect(
      withOlder.any((s) => s.type == ArchiveCleanSectionType.olderMoments),
      isTrue,
    );
  });

  test('this pattern available from summary or timeline without memory', () {
    final fromSummary = buildArchiveCleanSections(
      keyMoments: [_moment('a', DateTime(2026, 6, 6))],
      summary: _summary(),
      now: now,
    );
    expect(
      fromSummary.any((s) => s.type == ArchiveCleanSectionType.thisPattern),
      isTrue,
    );

    final fromTimeline = buildArchiveCleanSections(
      keyMoments: [_moment('a', DateTime(2026, 6, 6))],
      timeline: ArchiveEvolutionTimeline(
        patternTitle: 'Timeline pattern',
        events: const [],
        eventCount: 0,
      ),
      now: now,
    );
    expect(
      fromTimeline.any((s) => s.type == ArchiveCleanSectionType.thisPattern),
      isTrue,
    );
  });

  test('today available from check-in even without moments today', () {
    final sections = buildArchiveCleanSections(
      keyMoments: [_moment('old', DateTime(2026, 5, 20))],
      hasCheckInToday: true,
      now: now,
    );
    expect(
      sections.any((s) => s.type == ArchiveCleanSectionType.today),
      isTrue,
    );
    final today =
        sections.firstWhere((s) => s.type == ArchiveCleanSectionType.today);
    expect(today.count, isNull);
  });

  test('adds clean up archive section when compression groups exist', () {
    final sections = buildArchiveCleanSections(
      keyMoments: [
        _moment('old1', DateTime(2026, 4, 1)),
        _moment('old2', DateTime(2026, 4, 2)),
      ],
      hasCompressionGroups: true,
      now: now,
    );
    expect(
      sections.any((s) => s.type == ArchiveCleanSectionType.cleanUpArchive),
      isTrue,
    );
    final cleanup = sections
        .firstWhere((s) => s.type == ArchiveCleanSectionType.cleanUpArchive);
    expect(cleanup.route, '/archive-cleanup');
    expect(cleanup.title, 'Clean up archive');
  });
}
