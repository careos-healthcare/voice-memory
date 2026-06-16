import '../archive_memory/archive_evolution_model.dart';
import '../moments/key_moment_model.dart';
import '../moments/moment_tag_model.dart';
import '../pattern_map/pattern_map_model.dart';
import '../pattern_memory/pattern_memory_model.dart';
import 'archive_range_review_model.dart';

const int kArchiveRangeReviewMinMoments = 3;
const int kArchiveRangeReviewKeyMomentCap = 10;

/// Resolves inclusive start/end day boundaries for a preset range.
(DateTime start, DateTime end) resolveArchiveReviewRange({
  required ArchiveReviewRangePreset preset,
  required DateTime now,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final endOfToday = DateTime(
    today.year,
    today.month,
    today.day,
    23,
    59,
    59,
    999,
  );

  switch (preset) {
    case ArchiveReviewRangePreset.thisWeek:
      final start = today.subtract(const Duration(days: 6));
      return (start, endOfToday);
    case ArchiveReviewRangePreset.lastWeek:
      final lastWeekEnd = today.subtract(const Duration(days: 7));
      final start = today.subtract(const Duration(days: 13));
      return (
        DateTime(start.year, start.month, start.day),
        DateTime(
          lastWeekEnd.year,
          lastWeekEnd.month,
          lastWeekEnd.day,
          23,
          59,
          59,
          999,
        ),
      );
    case ArchiveReviewRangePreset.thisMonth:
      return (DateTime(now.year, now.month, 1), endOfToday);
    case ArchiveReviewRangePreset.last30Days:
      final start = today.subtract(const Duration(days: 29));
      return (start, endOfToday);
    case ArchiveReviewRangePreset.custom:
      final cs = customStart ?? today.subtract(const Duration(days: 6));
      final ce = customEnd ?? endOfToday;
      return (
        DateTime(cs.year, cs.month, cs.day),
        DateTime(ce.year, ce.month, ce.day, 23, 59, 59, 999),
      );
  }
}

String presetTitle(ArchiveReviewRangePreset preset) => switch (preset) {
  ArchiveReviewRangePreset.thisWeek => 'This week',
  ArchiveReviewRangePreset.lastWeek => 'Last week',
  ArchiveReviewRangePreset.thisMonth => 'This month',
  ArchiveReviewRangePreset.last30Days => 'Last 30 days',
  ArchiveReviewRangePreset.custom => 'Custom range',
};

/// Builds a period review from saved moments in the chosen date range.
ArchiveRangeReview buildArchiveRangeReview({
  required List<KeyMoment> moments,
  required DateTime now,
  ArchiveReviewRangePreset preset = ArchiveReviewRangePreset.thisWeek,
  DateTime? customStart,
  DateTime? customEnd,
  PatternMemory? memory,
  PatternMap? map,
  ArchiveEvolutionTimeline? timeline,
}) {
  final (start, end) = resolveArchiveReviewRange(
    preset: preset,
    now: now,
    customStart: customStart,
    customEnd: customEnd,
  );

  final filtered = moments.where((m) => _inRange(m.date, start, end)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final momentCount = filtered.length;
  final patternCount = _distinctPatternCount(filtered);

  if (momentCount < kArchiveRangeReviewMinMoments) {
    return ArchiveRangeReview(
      id: _reviewId(preset, start, end),
      preset: preset,
      startDate: start,
      endDate: end,
      title: presetTitle(preset),
      type: ArchiveRangeReviewType.notEnoughYet,
      momentCount: momentCount,
      patternCount: patternCount,
      keyMomentIds: filtered
          .map((m) => m.id)
          .take(kArchiveRangeReviewKeyMomentCap)
          .toList(),
    );
  }

  final lighterCount = _countLighter(filtered);
  final heavierCount = _countHeavier(filtered);
  final changedCount = _countChanged(filtered);
  final repeatedCount = _countRepeated(filtered);
  final topPattern = _topRepeatedPattern(filtered);

  final type = _resolveType(
    lighterCount: lighterCount,
    heavierCount: heavierCount,
    changedCount: changedCount,
    repeatedCount: repeatedCount,
    topPatternCount: topPattern?.$2 ?? 0,
  );

  final repeatedLine = _repeatedLine(repeatedCount, topPattern);
  final lighterLine = lighterCount >= 2
      ? 'It felt lighter in $lighterCount moments.'
      : null;
  final heavierLine = heavierCount >= 2
      ? 'It felt heavier in $heavierCount moments.'
      : null;
  final changedLine = changedCount >= 2
      ? 'Something changed in $changedCount moments.'
      : null;
  final helpedLine = _helpedLine(filtered);

  return ArchiveRangeReview(
    id: _reviewId(preset, start, end),
    preset: preset,
    startDate: start,
    endDate: end,
    title: presetTitle(preset),
    type: type,
    momentCount: momentCount,
    patternCount: patternCount,
    repeatedLine: repeatedLine,
    lighterLine: lighterLine,
    heavierLine: heavierLine,
    changedLine: changedLine,
    helpedLine: helpedLine,
    nextCheck: _nextCheck(map: map, memory: memory, timeline: timeline),
    keyMomentIds: filtered
        .map((m) => m.id)
        .take(kArchiveRangeReviewKeyMomentCap)
        .toList(),
  );
}

String _reviewId(
  ArchiveReviewRangePreset preset,
  DateTime start,
  DateTime end,
) => 'arr_${preset.id}_${start.toIso8601String()}_${end.toIso8601String()}';

bool _inRange(DateTime date, DateTime start, DateTime end) {
  final d = DateTime(date.year, date.month, date.day);
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return !d.isBefore(s) && !d.isAfter(e);
}

int _distinctPatternCount(List<KeyMoment> moments) {
  final titles = moments
      .map((m) => (m.patternTitle ?? '').trim())
      .where((t) => t.isNotEmpty)
      .toSet();
  return titles.length;
}

bool _isLighter(KeyMoment m) =>
    m.resultHint == 'lighter' || m.hasTag(MomentTag.lighter);

bool _isHeavier(KeyMoment m) =>
    m.resultHint == 'heavier' || m.hasTag(MomentTag.heavier);

bool _isChanged(KeyMoment m) =>
    m.resultHint == 'changed' ||
    m.resultHint == 'not_today' ||
    m.resultHint == 'none_fit' ||
    m.hasTag(MomentTag.changed);

bool _isRepeated(KeyMoment m) =>
    m.resultHint == 'same' || m.resultHint == 'showed_up_again';

int _countLighter(List<KeyMoment> moments) => moments.where(_isLighter).length;

int _countHeavier(List<KeyMoment> moments) => moments.where(_isHeavier).length;

int _countChanged(List<KeyMoment> moments) => moments.where(_isChanged).length;

int _countRepeated(List<KeyMoment> moments) =>
    moments.where(_isRepeated).length;

(String title, int count)? _topRepeatedPattern(List<KeyMoment> moments) {
  final counts = <String, int>{};
  for (final m in moments) {
    final title = (m.patternTitle ?? '').trim();
    if (title.isEmpty) continue;
    counts[title] = (counts[title] ?? 0) + 1;
  }
  String? top;
  var topCount = 0;
  counts.forEach((title, count) {
    if (count > topCount) {
      topCount = count;
      top = title;
    }
  });
  if (top == null || topCount < 2) return null;
  return (top!, topCount);
}

ArchiveRangeReviewType _resolveType({
  required int lighterCount,
  required int heavierCount,
  required int changedCount,
  required int repeatedCount,
  required int topPatternCount,
}) {
  if (heavierCount >= 2 && heavierCount > lighterCount) {
    return ArchiveRangeReviewType.heavier;
  }
  if (lighterCount >= 2) {
    return ArchiveRangeReviewType.lighter;
  }
  if (changedCount >= 2) {
    return ArchiveRangeReviewType.changed;
  }
  if (repeatedCount >= 2 || topPatternCount >= 2) {
    return ArchiveRangeReviewType.repeated;
  }
  return ArchiveRangeReviewType.notEnoughYet;
}

String? _repeatedLine(int repeatedCount, (String, int)? topPattern) {
  if (topPattern != null) {
    return 'This pattern showed up ${topPattern.$2} times.';
  }
  if (repeatedCount >= 2) {
    return 'This pattern showed up $repeatedCount times.';
  }
  return null;
}

String? _helpedLine(List<KeyMoment> moments) {
  final helpedMoments = moments
      .where((m) => m.hasTag(MomentTag.helped))
      .toList();
  if (helpedMoments.isEmpty) return null;
  for (final m in helpedMoments) {
    final summary = m.shortSummary.trim();
    if (summary.isNotEmpty) return summary;
  }
  return null;
}

String? _nextCheck({
  PatternMap? map,
  PatternMemory? memory,
  ArchiveEvolutionTimeline? timeline,
}) {
  final fromMap = (map?.nextCheck ?? '').trim();
  if (fromMap.isNotEmpty) return fromMap;
  final fromMemory = (memory?.nextBestQuestion ?? '').trim();
  if (fromMemory.isNotEmpty) return fromMemory;
  final fromTimeline = (timeline?.nextCheck ?? '').trim();
  if (fromTimeline.isNotEmpty) return fromTimeline;
  return 'What happens right before it shows up?';
}
