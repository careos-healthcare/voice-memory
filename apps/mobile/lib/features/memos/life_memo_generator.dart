import 'package:archiveme_mobile/features/analytics/timeline_day_stats.dart';
import 'package:archiveme_mobile/features/memos/life_memo_schedule.dart';

/// Weekly window or the longer monthly window.
enum LifeMemoPeriod {
  weekly(7),
  monthly(30);

  const LifeMemoPeriod(this.days);

  final int days;
}

/// A saved moment used to write a memo.
class MemoSourceEntry {
  const MemoSourceEntry({
    required this.id,
    required this.createdAt,
    required this.transcript,
  });

  final String id;
  final DateTime createdAt;
  final String transcript;

  double get tone => entrySentiment(transcript);
}

/// A graph entity first saved inside the memo window.
class MemoSourceEntity {
  const MemoSourceEntity({
    required this.name,
    required this.category,
    required this.createdAt,
  });

  final String name;
  final String category;
  final DateTime createdAt;
}

/// One stored executive memo.
class LifeMemo {
  const LifeMemo({
    required this.id,
    required this.period,
    required this.windowStart,
    required this.windowEnd,
    required this.title,
    required this.markdown,
    required this.evidenceEntryIds,
    required this.createdAt,
  });

  final String id;
  final LifeMemoPeriod period;
  final DateTime windowStart;
  final DateTime windowEnd;
  final String title;
  final String markdown;
  final List<String> evidenceEntryIds;
  final DateTime createdAt;
}

/// Turns a week or month of moments into the four memo sections.
abstract final class LifeMemoGenerator {
  static LifeMemo generate({
    required DateTime windowEnd,
    required LifeMemoPeriod period,
    required List<MemoSourceEntry> entries,
    required List<MemoSourceEntity> entities,
    DateTime? createdAt,
  }) {
    final end = windowEnd.toLocal();
    final start = end.subtract(Duration(days: period.days));
    final inWindow = [
      for (final entry in entries)
        if (!entry.createdAt.isBefore(start) && !entry.createdAt.isAfter(end))
          entry,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final newEntities = [
      for (final entity in entities)
        if (!entity.createdAt.isBefore(start) && !entity.createdAt.isAfter(end))
          entity,
    ];
    final title = period == LifeMemoPeriod.weekly
        ? 'Week ending ${_dateLabel(end)}'
        : 'Month ending ${_dateLabel(end)}';
    final achievements = _achievements(inWindow);
    final themes = _themes(inWindow, newEntities);
    final health = _health(inWindow);
    final actions = _actions(inWindow, newEntities);
    final markdown =
        '''
# $title

## Key Achievements
$achievements

## Recurring Themes & Triggers
$themes

## Emotional Health Summary
$health

## Open Action Items
$actions
'''
            .trim();
    return LifeMemo(
      id: '${period.name}-${end.millisecondsSinceEpoch}',
      period: period,
      windowStart: start,
      windowEnd: end,
      title: title,
      markdown: markdown,
      evidenceEntryIds: [for (final entry in inWindow) entry.id],
      createdAt: createdAt ?? end,
    );
  }

  /// Writes the weekly memo, and the monthly memo on the first Sunday.
  static List<LifeMemo> generateDue({
    required DateTime now,
    required List<MemoSourceEntry> entries,
    required List<MemoSourceEntity> entities,
  }) {
    final slot = LifeMemoSchedule.currentSlot(now);
    final memos = [
      generate(
        windowEnd: slot,
        period: LifeMemoPeriod.weekly,
        entries: entries,
        entities: entities,
        createdAt: now,
      ),
    ];
    if (LifeMemoSchedule.isMonthlySlot(slot)) {
      memos.add(
        generate(
          windowEnd: slot,
          period: LifeMemoPeriod.monthly,
          entries: entries,
          entities: entities,
          createdAt: now,
        ),
      );
    }
    return memos;
  }

  static String _achievements(List<MemoSourceEntry> entries) {
    final lines = <String>[];
    for (final entry in entries) {
      if (entry.tone <= 0) continue;
      final preview = _preview(entry.transcript);
      if (preview.isEmpty) continue;
      lines.add('- $preview');
      if (lines.length == 5) break;
    }
    if (lines.isEmpty) return '- No highlighted moments in this window.';
    return lines.join('\n');
  }

  static String _themes(
    List<MemoSourceEntry> entries,
    List<MemoSourceEntity> entities,
  ) {
    final lines = <String>[];
    for (final entity in entities) {
      final name = entity.name.trim();
      if (name.isEmpty) continue;
      lines.add('- ${entity.category}: $name');
    }
    final counts = <String, int>{};
    for (final entry in entries) {
      final tokens = entry.transcript
          .toLowerCase()
          .split(RegExp('[^a-z]+'))
          .where((token) => token.length > 4)
          .toSet();
      for (final token in tokens) {
        counts[token] = (counts[token] ?? 0) + 1;
      }
    }
    final repeated = [
      for (final item in counts.entries)
        if (item.value >= 2) item.key,
    ]..sort();
    for (final token in repeated.take(5)) {
      lines.add('- repeated: $token');
    }
    if (lines.isEmpty) return '- No repeated themes in this window.';
    return lines.join('\n');
  }

  static String _health(List<MemoSourceEntry> entries) {
    if (entries.isEmpty) {
      return 'No moments in this window, so there is no tone to summarize.';
    }
    final average = _mean(entries.map((entry) => entry.tone));
    final midpoint = entries.length ~/ 2;
    final early = entries.take(midpoint == 0 ? 1 : midpoint);
    final late = entries.skip(midpoint == 0 ? 0 : midpoint);
    final delta =
        _mean(late.map((entry) => entry.tone)) -
        _mean(early.map((entry) => entry.tone));
    final direction = delta > 0.05
        ? 'Tone rose across these moments.'
        : delta < -0.05
        ? 'Tone fell across these moments.'
        : 'Tone stayed steady across these moments.';
    return 'Average tone ${average.toStringAsFixed(2)}. $direction';
  }

  static String _actions(
    List<MemoSourceEntry> entries,
    List<MemoSourceEntity> entities,
  ) {
    final lines = <String>[];
    for (final entity in entities) {
      if (entity.category != 'goals') continue;
      final name = entity.name.trim();
      if (name.isEmpty) continue;
      lines.add('- $name');
    }
    final want = RegExp(
      r'\bI want to\s+(.+?)(?=\s+when\b|\s+after\b|[.;]|$)',
      caseSensitive: false,
    );
    for (final entry in entries) {
      final match = want.firstMatch(entry.transcript);
      final phrase = match?.group(1)?.trim();
      if (phrase == null || phrase.isEmpty) continue;
      final line = '- $phrase';
      if (!lines.contains(line)) lines.add(line);
    }
    if (lines.isEmpty) return '- No open actions in this window.';
    return lines.join('\n');
  }

  static String _preview(String transcript) {
    final words = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (words.length <= 80) return words;
    return '${words.substring(0, 80)}…';
  }

  static String _dateLabel(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }

  static double _mean(Iterable<double> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return 0;
    var total = 0.0;
    for (final value in list) {
      total += value;
    }
    return total / list.length;
  }
}
