import '../moments/key_moment_model.dart';
import '../pattern_memory/pattern_memory_model.dart';
import 'pattern_map_model.dart';

/// Builds a [PatternMap] from what ArchiveMe already remembers about a pattern.
///
/// The pattern memory is the primary source. Key moments only fill gaps (the
/// "starts before", "lighter when", "heavier when" lines) when the memory has
/// not gathered them yet. Nothing is invented — empty stays empty.
PatternMap buildPatternMap({
  required PatternMemory memory,
  List<KeyMoment> moments = const [],
}) {
  final related = moments
      .where(
        (m) =>
            m.patternTitle != null &&
            m.patternTitle!.trim().toLowerCase() ==
                memory.patternTitle.trim().toLowerCase(),
      )
      .toList();

  final seenCount = memory.checkInCount > 0
      ? memory.checkInCount
      : related.length;

  final lastSeen = _latestDate(memory.updatedAt, related);

  return PatternMap(
    patternTitle: memory.patternTitle,
    seenCount: seenCount,
    lastSeenDate: lastSeen,
    usuallyStartsBefore:
        _first(memory.commonBeforeMoments) ??
        _fromMoments(related, tag: 'pressure'),
    oftenFeelsLike: _oftenFeelsLike(memory),
    getsLighterWhen:
        _first(memory.helpedMoments) ?? _fromMoments(related, hint: 'lighter'),
    getsHeavierWhen:
        _first(memory.harderMoments) ?? _fromMoments(related, hint: 'heavier'),
    nextCheck: (memory.nextBestQuestion ?? '').trim().isNotEmpty
        ? memory.nextBestQuestion!.trim()
        : _fallbackNextCheck,
    confidenceLabel: _confidence(seenCount),
  );
}

/// Plain fallback so the map always offers one useful next check.
const String _fallbackNextCheck = 'What happens right before it shows up?';

String? _first(List<String> values) {
  for (final v in values) {
    if (v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

/// Picks the dominant result so the user sees how it usually lands.
String? _oftenFeelsLike(PatternMemory memory) {
  final counts = <String, int>{
    'heavier': memory.heavierCount,
    'lighter': memory.lighterCount,
    'the same': memory.showedAgainCount,
    'different': memory.changedCount,
  };
  String? best;
  var bestCount = 0;
  counts.forEach((label, count) {
    if (count > bestCount) {
      bestCount = count;
      best = label;
    }
  });
  return bestCount > 0 ? best : null;
}

DateTime? _latestDate(DateTime memoryUpdated, List<KeyMoment> moments) {
  var latest = memoryUpdated;
  for (final m in moments) {
    if (m.date.isAfter(latest)) latest = m.date;
  }
  return latest;
}

String? _fromMoments(List<KeyMoment> moments, {String? tag, String? hint}) {
  for (final m in moments) {
    if (tag != null && m.tags.contains(tag) && m.shortSummary.isNotEmpty) {
      return m.shortSummary;
    }
    if (hint != null && m.resultHint == hint && m.shortSummary.isNotEmpty) {
      return m.shortSummary;
    }
  }
  return null;
}

String _confidence(int seenCount) {
  if (seenCount < 3) return 'Early read';
  return 'Based on $seenCount check-ins';
}
