import 'dart:math' as math;

import '../moments/key_moment_model.dart';
import '../pattern_map/pattern_map_model.dart';
import '../pattern_memory/pattern_memory_model.dart';
import '../pattern_memory/pattern_progress_model.dart';
import 'archive_evolution_model.dart';
import 'archive_memory_summary_model.dart';
import 'memory_quality_model.dart';

/// Builds a conservative memory-quality read from saved local data only.
MemoryQuality buildMemoryQuality({
  ArchiveMemorySummary? summary,
  PatternMemory? memory,
  List<KeyMoment> keyMoments = const [],
  ArchiveEvolutionTimeline? timeline,
  PatternProgressMoment? progress,
  PatternMap? map,
}) {
  final momentCount = math.max(
    summary?.basedOnMomentCount ?? 0,
    math.max(
      memory?.checkInCount ?? 0,
      math.max(
        keyMoments.length,
        math.max(timeline?.eventCount ?? 0, map?.seenCount ?? 0),
      ),
    ),
  );

  final checkInCount = memory?.checkInCount ?? 0;

  final weekCount = summary != null && summary.basedOnWeekCount > 0
      ? summary.basedOnWeekCount
      : _weekCountFromMoments(keyMoments);

  final hasChangedRecently = _hasChangedRecently(
    summary: summary,
    memory: memory,
    progress: progress,
    timeline: timeline,
  );

  final baseLevel = _levelForCount(momentCount);
  final level = hasChangedRecently && momentCount >= 3
      ? MemoryQualityLevel.changingPattern
      : baseLevel;

  return MemoryQuality(
    level: level,
    label: _labelForLevel(level),
    helperText: _helperForLevel(level),
    momentCount: momentCount,
    checkInCount: checkInCount,
    weekCount: weekCount,
    hasChangedRecently: hasChangedRecently,
  );
}

MemoryQualityLevel _levelForCount(int count) {
  if (count < 3) return MemoryQualityLevel.earlyRead;
  if (count <= 4) return MemoryQualityLevel.gettingClearer;
  if (count <= 9) return MemoryQualityLevel.clearPattern;
  return MemoryQualityLevel.strongPattern;
}

String _labelForLevel(MemoryQualityLevel level) {
  switch (level) {
    case MemoryQualityLevel.earlyRead:
      return 'Early read';
    case MemoryQualityLevel.gettingClearer:
      return 'Getting clearer';
    case MemoryQualityLevel.clearPattern:
      return 'Clear pattern';
    case MemoryQualityLevel.strongPattern:
      return 'Strong pattern';
    case MemoryQualityLevel.changingPattern:
      return 'Changing pattern';
  }
}

String _helperForLevel(MemoryQualityLevel level) {
  switch (level) {
    case MemoryQualityLevel.earlyRead:
      return 'Record a few more moments to make this clearer.';
    case MemoryQualityLevel.gettingClearer:
      return 'This pattern is starting to repeat across days.';
    case MemoryQualityLevel.clearPattern:
      return 'This pattern is clear enough to check tomorrow.';
    case MemoryQualityLevel.strongPattern:
      return 'This pattern has shown up across weeks.';
    case MemoryQualityLevel.changingPattern:
      return 'This pattern has changed recently.';
  }
}

int _weekCountFromMoments(List<KeyMoment> moments) {
  if (moments.isEmpty) return 0;
  final dates = moments.map((m) => m.date).toList()..sort();
  final first = dates.first;
  final last = dates.last;
  final spanDays = last.difference(first).inDays;
  if (spanDays <= 0) return 1;
  return (spanDays / 7).ceil().clamp(1, 52);
}

bool _hasChangedRecently({
  ArchiveMemorySummary? summary,
  PatternMemory? memory,
  PatternProgressMoment? progress,
  ArchiveEvolutionTimeline? timeline,
}) {
  if (summary?.changedLine != null && summary!.changedLine!.trim().isNotEmpty) {
    return true;
  }
  if (progress?.type == PatternProgressType.changing) return true;
  if (memory?.status == PatternMemoryStatus.changing) return true;
  if (memory != null && memory.changedCount >= 2) return true;
  if (timeline != null) {
    for (final event in timeline.events) {
      if (event.type == ArchiveEvolutionEventType.changed ||
          event.type == ArchiveEvolutionEventType.feltLighter ||
          event.type == ArchiveEvolutionEventType.feltHeavier) {
        return true;
      }
    }
  }
  return false;
}
