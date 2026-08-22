import 'dart:math' as math;

import 'package:archiveme_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/result_next_check_model.dart';

/// Builds a single, plain-language summary of what ArchiveMe remembers about a
/// pattern — pulling only from what is already stored.
///
/// Everything is conservative: lines are omitted when their source is unknown,
/// counts never overstate, and the summary is withheld until there are at least
/// three usable moments/check-ins. Returns null when there is not yet enough.
ArchiveMemorySummary? buildArchiveMemorySummary({
  PatternMemory? memory,
  PatternMap? patternMap,
  List<KeyMoment> keyMoments = const [],
  PatternProgressMoment? progress,
  WeeklyPatternRecap? weeklyRecap,
  ResultNextCheck? nextCheck,
}) {
  final patternTitle = _firstNonEmpty([
    memory?.patternTitle,
    patternMap?.patternTitle,
    weeklyRecap?.patternTitle,
    _firstMomentTitle(keyMoments),
  ]);

  final related = _relatedMoments(keyMoments, patternTitle);

  // Conservative: never sum sources that overlap. Use the strongest single
  // count so a check-in that also created a key moment is not double-counted.
  final basedOnMomentCount = math.max(
    memory?.checkInCount ?? 0,
    math.max(related.length, patternMap?.seenCount ?? 0),
  );

  if (basedOnMomentCount < 3) return null;

  final firstSeen = _firstSeen(memory, related);
  final lastSeen = _lastSeen(memory, patternMap, related);
  final basedOnWeekCount = _weeksBetween(firstSeen, lastSeen);

  final primaryMemoryLine = patternTitle == null
      ? 'One pattern keeps showing up.'
      : 'You often ${_naturalPatternPhrase(patternTitle)}.';

  final startsBefore = _firstNonEmpty([
    patternMap?.usuallyStartsBefore,
    _first(memory?.commonBeforeMoments),
  ]);
  final helped = _firstNonEmpty([
    patternMap?.getsLighterWhen,
    _first(memory?.helpedMoments),
  ]);
  final heavier = _firstNonEmpty([
    patternMap?.getsHeavierWhen,
    _first(memory?.harderMoments),
  ]);

  final changed = _hasChanged(progress, weeklyRecap, memory);

  final resolvedNextCheck = _firstNonEmpty([
    nextCheck?.nextQuestion,
    patternMap?.nextCheck,
    memory?.nextBestQuestion,
  ]);

  return ArchiveMemorySummary(
    id: memory?.id ?? 'memory-summary',
    patternTitle: patternTitle ?? '',
    primaryMemoryLine: primaryMemoryLine,
    startsBeforeLine: startsBefore == null
        ? null
        : 'It often starts before: ${_stripLeadingBefore(startsBefore)}.',
    helpedLine: helped == null ? null : 'It has felt lighter when: $helped.',
    heavierLine: heavier == null ? null : 'It has felt heavier when: $heavier.',
    changedLine: changed ? 'This pattern has changed recently.' : null,
    basedOnMomentCount: basedOnMomentCount,
    basedOnWeekCount: basedOnWeekCount,
    firstSeenDate: firstSeen,
    lastSeenDate: lastSeen,
    clarityLabel: _clarityLabel(basedOnMomentCount),
    nextCheck: resolvedNextCheck,
  );
}

String _clarityLabel(int count) {
  if (count >= 10) return 'Strong pattern';
  if (count >= 5) return 'Clear pattern';
  return 'Getting clearer';
}

bool _hasChanged(
  PatternProgressMoment? progress,
  WeeklyPatternRecap? weeklyRecap,
  PatternMemory? memory,
) {
  if (progress?.type == PatternProgressType.changing) return true;
  if (weeklyRecap?.type == WeeklyPatternRecapType.changing) return true;
  if (memory?.status == PatternMemoryStatus.changing) return true;
  return false;
}

List<KeyMoment> _relatedMoments(List<KeyMoment> moments, String? patternTitle) {
  if (patternTitle == null) return moments;
  final target = patternTitle.trim().toLowerCase();
  final matched = moments
      .where((m) => (m.patternTitle ?? '').trim().toLowerCase() == target)
      .toList();
  // Fall back to all moments when none are tagged with this pattern yet.
  return matched.isNotEmpty ? matched : moments;
}

String? _firstMomentTitle(List<KeyMoment> moments) {
  for (final m in moments) {
    final t = (m.patternTitle ?? '').trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

DateTime? _firstSeen(PatternMemory? memory, List<KeyMoment> moments) {
  var earliest = memory?.createdAt;
  for (final m in moments) {
    if (earliest == null || m.date.isBefore(earliest)) earliest = m.date;
  }
  return earliest;
}

DateTime? _lastSeen(
  PatternMemory? memory,
  PatternMap? patternMap,
  List<KeyMoment> moments,
) {
  var latest = memory?.updatedAt;
  final mapDate = patternMap?.lastSeenDate;
  if (mapDate != null && (latest == null || mapDate.isAfter(latest))) {
    latest = mapDate;
  }
  for (final m in moments) {
    if (latest == null || m.date.isAfter(latest)) latest = m.date;
  }
  return latest;
}

int _weeksBetween(DateTime? first, DateTime? last) {
  if (first == null || last == null) return 1;
  final days = last.difference(first).inDays;
  if (days <= 0) return 1;
  return math.max(1, (days / 7).ceil());
}

String? _first(List<String>? values) {
  if (values == null) return null;
  for (final v in values) {
    if (v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

String? _firstNonEmpty(List<String?> values) {
  for (final v in values) {
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

/// Avoids "before: before saying yes" when a source already leads with "before".
String _stripLeadingBefore(String value) {
  final v = value.trim();
  final lower = v.toLowerCase();
  if (lower.startsWith('before ')) return v.substring(7).trim();
  return v;
}

String _lowerFirst(String value) {
  final v = value.trim();
  if (v.isEmpty) return v;
  return v[0].toLowerCase() + v.substring(1);
}

/// Common gerund pattern titles read awkwardly after "You often" (e.g. "You
/// often taking responsibility"). Convert the leading verb to its base form so
/// the line reads naturally; fall back to lower-casing the first letter.
const Map<String, String> _gerundToBaseVerb = {
  'Taking ': 'take ',
  'Trying ': 'try ',
  'Carrying ': 'carry ',
  'Avoiding ': 'avoid ',
  'Putting ': 'put ',
  'Running ': 'run ',
  'Feeling ': 'feel ',
  'Worrying ': 'worry ',
  'Replaying ': 'replay ',
  'Saying ': 'say ',
};

String _naturalPatternPhrase(String title) {
  final v = title.trim();
  if (v.isEmpty) return v;
  for (final entry in _gerundToBaseVerb.entries) {
    if (v.startsWith(entry.key)) {
      return entry.value + v.substring(entry.key.length);
    }
  }
  return _lowerFirst(v);
}