import 'package:archiveme_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/moments/moment_tag_model.dart';
import 'package:archiveme_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';

/// Local search over saved moments, patterns, and checks. No cloud, no invented
/// results — only what ArchiveMe already remembers.
List<ArchiveSearchResult> searchArchive({
  required ArchiveSearchQuery query,
  required List<KeyMoment> moments,
  PatternMemory? memory,
  PatternMap? patternMap,
  ArchiveEvolutionTimeline? timeline,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final sorted = [...moments]..sort((a, b) => b.date.compareTo(a.date));

  switch (query.intent) {
    case ArchiveSearchIntent.lastSeen:
      return _lastSeen(query, sorted, patternMap, timeline);
    case ArchiveSearchIntent.helpedBefore:
      return _helpedBefore(sorted, memory, timeline);
    case ArchiveSearchIntent.momentsAbout:
      return _momentsAbout(query, sorted);
    case ArchiveSearchIntent.feltLighter:
      return _feltLighter(sorted);
    case ArchiveSearchIntent.feltHeavier:
      return _feltHeavier(sorted);
    case ArchiveSearchIntent.changed:
      return _changed(query, sorted, clock);
    case ArchiveSearchIntent.thisWeek:
      return _thisWeek(sorted, clock);
    case ArchiveSearchIntent.freeText:
      return _freeText(query, sorted, patternMap);
  }
}

const _changedHints = {'changed', 'not_today', 'none_fit'};
const _showedUpHints = {'same', 'showed_up_again'};

List<ArchiveSearchResult> _lastSeen(
  ArchiveSearchQuery query,
  List<KeyMoment> sorted,
  PatternMap? patternMap,
  ArchiveEvolutionTimeline? timeline,
) {
  final results = <ArchiveSearchResult>[];

  for (final m in sorted) {
    if (!_showedUpHints.contains(m.resultHint)) continue;
    results.add(_fromMoment(m));
  }

  if (patternMap?.lastSeenDate case final date?) {
    results.add(
      ArchiveSearchResult(
        id: 'pattern-map-last-seen',
        title: patternMap!.patternTitle,
        body: 'This pattern showed up on ${_dayLabel(date)}.',
        date: date,
        patternTitle: patternMap.patternTitle,
        nextCheck: patternMap.nextCheck,
      ),
    );
  }

  if (timeline != null) {
    for (final event in timeline.events) {
      if (event.type != ArchiveEvolutionEventType.showedAgain &&
          event.type != ArchiveEvolutionEventType.firstSeen) {
        continue;
      }
      results.add(_fromTimelineEvent(event));
    }
  }

  results.sort((a, b) => b.date.compareTo(a.date));
  return results;
}

List<ArchiveSearchResult> _helpedBefore(
  List<KeyMoment> sorted,
  PatternMemory? memory,
  ArchiveEvolutionTimeline? timeline,
) {
  final results = <ArchiveSearchResult>[];

  for (final m in sorted) {
    if (!m.hasTag(MomentTag.helped) && m.resultHint != 'lighter') continue;
    results.add(_fromMoment(m));
  }

  if (memory != null) {
    for (final text in memory.helpedMoments) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;
      results.add(
        ArchiveSearchResult(
          id: 'memory-helped-${trimmed.hashCode}',
          title: memory.patternTitle,
          body: trimmed,
          date: memory.updatedAt,
          patternTitle: memory.patternTitle,
          resultHint: 'lighter',
          tags: const ['helped', 'lighter'],
          nextCheck: memory.nextBestQuestion,
        ),
      );
    }
  }

  if (timeline != null) {
    for (final event in timeline.events) {
      if (event.type != ArchiveEvolutionEventType.feltLighter) continue;
      results.add(_fromTimelineEvent(event, resultHint: 'lighter'));
    }
  }

  results.sort((a, b) => b.date.compareTo(a.date));
  return results;
}

List<ArchiveSearchResult> _momentsAbout(
  ArchiveSearchQuery query,
  List<KeyMoment> sorted,
) {
  final term = query.normalizedTerm?.toLowerCase();
  if (term == null || term.isEmpty) {
    return _freeText(query, sorted, null);
  }

  return sorted.where((m) => _matchesTerm(m, term)).map(_fromMoment).toList();
}

List<ArchiveSearchResult> _feltLighter(List<KeyMoment> sorted) =>
    sorted.where((m) => m.resultHint == 'lighter').map(_fromMoment).toList();

List<ArchiveSearchResult> _feltHeavier(List<KeyMoment> sorted) =>
    sorted.where((m) => m.resultHint == 'heavier').map(_fromMoment).toList();

List<ArchiveSearchResult> _changed(
  ArchiveSearchQuery query,
  List<KeyMoment> sorted,
  DateTime now,
) {
  final weekOnly = query.rawText.toLowerCase().contains('this week');
  final weekAgo = now.subtract(const Duration(days: 7));

  return sorted
      .where((m) {
        if (!_changedHints.contains(m.resultHint)) return false;
        if (weekOnly && !m.date.isAfter(weekAgo)) return false;
        return true;
      })
      .map(_fromMoment)
      .toList();
}

List<ArchiveSearchResult> _thisWeek(List<KeyMoment> sorted, DateTime now) {
  final weekAgo = now.subtract(const Duration(days: 7));
  return sorted.where((m) => m.date.isAfter(weekAgo)).map(_fromMoment).toList();
}

List<ArchiveSearchResult> _freeText(
  ArchiveSearchQuery query,
  List<KeyMoment> sorted,
  PatternMap? patternMap,
) {
  final q = query.rawText.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final results = <ArchiveSearchResult>[];

  for (final m in sorted) {
    if (_momentHaystack(m).contains(q)) {
      results.add(_fromMoment(m));
    }
  }

  if (patternMap != null && _patternMapHaystack(patternMap).contains(q)) {
    results.add(
      ArchiveSearchResult(
        id: 'pattern-map-${patternMap.patternTitle.hashCode}',
        title: patternMap.patternTitle,
        body: patternMap.oftenFeelsLike ?? patternMap.patternTitle,
        date: patternMap.lastSeenDate ?? DateTime.fromMillisecondsSinceEpoch(0),
        patternTitle: patternMap.patternTitle,
        nextCheck: patternMap.nextCheck,
        tags: const ['pattern'],
      ),
    );
  }

  results.sort((a, b) => b.date.compareTo(a.date));
  return results;
}

bool _matchesTerm(KeyMoment m, String term) {
  if (m.tags.any((t) => t.toLowerCase() == term)) return true;
  return _momentHaystack(m).contains(term);
}

String _momentHaystack(KeyMoment m) => [
  m.originalText,
  m.shortSummary,
  m.title,
  m.patternTitle ?? '',
  m.resultHint ?? '',
  m.tags.join(' '),
  m.dayKey,
].join(' ').toLowerCase();

String _patternMapHaystack(PatternMap map) => [
  map.patternTitle,
  map.usuallyStartsBefore ?? '',
  map.oftenFeelsLike ?? '',
  map.getsLighterWhen ?? '',
  map.getsHeavierWhen ?? '',
  map.nextCheck ?? '',
  map.confidenceLabel,
].join(' ').toLowerCase();

ArchiveSearchResult _fromMoment(KeyMoment m) => ArchiveSearchResult(
  id: 'moment-${m.id}',
  title: m.title,
  body: m.shortSummary.isNotEmpty ? m.shortSummary : m.originalText,
  date: m.date,
  momentId: m.id,
  patternTitle: m.patternTitle,
  resultHint: m.resultHint,
  tags: m.tags,
  nextCheck: m.nextCheck,
);

ArchiveSearchResult _fromTimelineEvent(
  ArchiveEvolutionEvent event, {
  String? resultHint,
}) => ArchiveSearchResult(
  id: 'timeline-${event.id}',
  title: event.title,
  body: event.body,
  date: event.date,
  momentId: event.momentId,
  patternTitle: event.patternTitle,
  resultHint: resultHint,
  nextCheck: event.nextCheck,
);

String _dayLabel(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}';
}

/// Backwards-compatible wrapper used by older call sites.
class ArchiveSearchEngine {
  const ArchiveSearchEngine();

  List<ArchiveSearchResult> search(
    ArchiveSearchQuery query,
    List<KeyMoment> moments, {
    PatternMemory? memory,
    PatternMap? patternMap,
    ArchiveEvolutionTimeline? timeline,
    DateTime? now,
  }) => searchArchive(
    query: query,
    moments: moments,
    memory: memory,
    patternMap: patternMap,
    timeline: timeline,
    now: now,
  );
}