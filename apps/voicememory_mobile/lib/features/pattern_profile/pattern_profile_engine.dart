import '../archive_memory/archive_evolution_model.dart';
import '../archive_memory/archive_memory_summary_model.dart';
import '../moments/key_moment_model.dart';
import '../pattern_map/pattern_map_model.dart';
import '../pattern_memory/pattern_memory_model.dart';
import 'pattern_profile_model.dart';

const _conservativeResultHints = {
  'same',
  'showed_up_again',
  'lighter',
  'heavier',
  'changed',
  'not_today',
  'none_fit',
};

/// Builds a [PatternProfile] from saved local data only — nothing invented.
PatternProfile? buildPatternProfile({
  PatternMemory? memory,
  ArchiveMemorySummary? summary,
  PatternMap? map,
  ArchiveEvolutionTimeline? timeline,
  required List<KeyMoment> keyMoments,
}) {
  if (memory == null && summary == null && map == null && timeline == null) {
    return null;
  }

  final patternTitle = _patternTitle(summary, memory, map, timeline);
  if (patternTitle == null || patternTitle.trim().isEmpty) {
    return null;
  }

  final related = _relatedMoments(keyMoments, patternTitle);
  final previewMoments = related.take(5).toList();

  return PatternProfile(
    patternTitle: patternTitle.trim(),
    archiveMemorySummary: summary,
    patternMap: map,
    archiveEvolutionTimeline: timeline,
    keyMoments: previewMoments,
    nextCheck: _nextCheck(summary, map, timeline, memory),
    clarityLabel: _clarityLabel(summary, map, memory, related.length),
  );
}

String? _patternTitle(
  ArchiveMemorySummary? summary,
  PatternMemory? memory,
  PatternMap? map,
  ArchiveEvolutionTimeline? timeline,
) {
  final fromSummary = summary?.patternTitle.trim();
  if (fromSummary != null && fromSummary.isNotEmpty) return fromSummary;

  final fromMemory = memory?.patternTitle.trim();
  if (fromMemory != null && fromMemory.isNotEmpty) return fromMemory;

  final fromMap = map?.patternTitle.trim();
  if (fromMap != null && fromMap.isNotEmpty) return fromMap;

  final fromTimeline = timeline?.patternTitle.trim();
  if (fromTimeline != null && fromTimeline.isNotEmpty) return fromTimeline;

  return null;
}

List<KeyMoment> _relatedMoments(List<KeyMoment> all, String patternTitle) {
  final lower = patternTitle.trim().toLowerCase();
  final matched = all.where((m) {
    final title = (m.patternTitle ?? '').trim().toLowerCase();
    if (title.isNotEmpty) return title == lower;
    return m.resultHint != null &&
        _conservativeResultHints.contains(m.resultHint);
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
  return matched;
}

String? _nextCheck(
  ArchiveMemorySummary? summary,
  PatternMap? map,
  ArchiveEvolutionTimeline? timeline,
  PatternMemory? memory,
) {
  final fromSummary = summary?.nextCheck?.trim();
  if (fromSummary != null && fromSummary.isNotEmpty) return fromSummary;

  final fromMap = map?.nextCheck?.trim();
  if (fromMap != null && fromMap.isNotEmpty) return fromMap;

  final fromTimeline = timeline?.nextCheck?.trim();
  if (fromTimeline != null && fromTimeline.isNotEmpty) return fromTimeline;

  final fromMemory = memory?.nextBestQuestion?.trim();
  if (fromMemory != null && fromMemory.isNotEmpty) return fromMemory;

  return null;
}

String? _clarityLabel(
  ArchiveMemorySummary? summary,
  PatternMap? map,
  PatternMemory? memory,
  int relatedMomentCount,
) {
  final fromSummary = summary?.clarityLabel.trim();
  if (fromSummary != null && fromSummary.isNotEmpty) return fromSummary;

  final fromMap = map?.confidenceLabel.trim();
  if (fromMap != null && fromMap.isNotEmpty) return fromMap;

  final checkIns = memory?.checkInCount ?? 0;
  if (relatedMomentCount < 3 && checkIns < 3) {
    return 'Early read';
  }

  return null;
}
