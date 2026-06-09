import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../contradiction_detection/statement_analysis.dart';
import '../theme_tracking/theme_tracker_service.dart';
import 'life_chapter_models.dart';

/// Groups chronological journal evidence into named life chapters.
class LifeChapterEngine {
  const LifeChapterEngine();

  /// Minimum eligible recordings in a time window to emit a chapter.
  static const int minEntriesPerChapter = 2;

  /// Minimum times a theme must appear within a chapter window.
  static const int minThemeHitsPerChapter = 2;

  /// Days without recordings that starts a new chapter boundary.
  static const int gapDaysNewChapter = 42;

  /// Splits very long spans when the dominant theme shifts mid-period.
  static const int maxChapterSpanDays = 120;

  LifeChapterResult build({required List<JournalEntry> entries}) {
    final evidenceCount = archiveEvidenceReflectionCount(entries);
    final hasMin = archiveHasMinimumEvidence(entries);
    if (!hasMin) {
      return LifeChapterResult(
        chapters: const [],
        hasMinimumArchiveEvidence: false,
        evidenceReflectionCount: evidenceCount,
      );
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length < minEntriesPerChapter) {
      return LifeChapterResult(
        chapters: const [],
        hasMinimumArchiveEvidence: true,
        evidenceReflectionCount: evidenceCount,
      );
    }

    final segments = _segmentTimeline(eligible);
    final chapters = <LifeChapter>[];

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.length < minEntriesPerChapter) continue;
      final chapter = _chapterFromSegment(segment, index: i);
      if (chapter != null) chapters.add(chapter);
    }

    chapters.sort((a, b) => b.startDate.compareTo(a.startDate));

    return LifeChapterResult(
      chapters: chapters.take(8).toList(),
      hasMinimumArchiveEvidence: true,
      evidenceReflectionCount: evidenceCount,
    );
  }
}

List<List<JournalEntry>> _segmentTimeline(List<JournalEntry> eligible) {
  final segments = <List<JournalEntry>>[];
  var current = <JournalEntry>[eligible.first];

  for (var i = 1; i < eligible.length; i++) {
    final prev = eligible[i - 1];
    final entry = eligible[i];
    final gap = entry.createdAt.difference(prev.createdAt).inDays;
    if (gap >= LifeChapterEngine.gapDaysNewChapter) {
      segments.add(current);
      current = [entry];
    } else {
      current.add(entry);
    }
  }
  segments.add(current);

  return _splitOversizedSegments(segments);
}

List<List<JournalEntry>> _splitOversizedSegments(List<List<JournalEntry>> segments) {
  final out = <List<JournalEntry>>[];
  for (final segment in segments) {
    if (segment.length < LifeChapterEngine.minEntriesPerChapter) {
      out.add(segment);
      continue;
    }
    final spanDays =
        segment.last.createdAt.difference(segment.first.createdAt).inDays;
    if (spanDays <= LifeChapterEngine.maxChapterSpanDays) {
      out.add(segment);
      continue;
    }

    final splitIndex = _themeShiftSplitIndex(segment);
    if (splitIndex <= 0 || splitIndex >= segment.length - 1) {
      out.add(segment);
      continue;
    }
    out.add(segment.sublist(0, splitIndex + 1));
    out.add(segment.sublist(splitIndex + 1));
  }
  return out;
}

int _themeShiftSplitIndex(List<JournalEntry> segment) {
  var bestIndex = segment.length ~/ 2;
  var bestDelta = 0;

  for (var i = 1; i < segment.length; i++) {
    final early = segment.sublist(0, i);
    final late = segment.sublist(i);
    final earlyTop = _dominantThemeIds(early).keys.firstOrNull;
    final lateTop = _dominantThemeIds(late).keys.firstOrNull;
    if (earlyTop == null || lateTop == null || earlyTop == lateTop) continue;
    final delta = (_dominantThemeIds(early)[earlyTop] ?? 0) +
        (_dominantThemeIds(late)[lateTop] ?? 0);
    if (delta > bestDelta) {
      bestDelta = delta;
      bestIndex = i;
    }
  }
  return bestIndex;
}

LifeChapter? _chapterFromSegment(List<JournalEntry> segment, {required int index}) {
  final themeCounts = _dominantThemeIds(segment);
  final ranked = themeCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final qualifying = ranked
      .where((e) => e.value >= LifeChapterEngine.minThemeHitsPerChapter)
      .toList();
  if (qualifying.isEmpty) return null;

  final blob = segment.map(_entryBlob).join(' ').toLowerCase();
  var primary = qualifying.first.key;
  if (qualifying.any((e) => e.key == 'health') &&
      _containsAny(blob, const ['burnout', 'exhausted', 'drained', 'depleted'])) {
    primary = 'health';
  } else if (qualifying.any((e) => e.key == 'confidence') &&
      _confidenceRebuild(segment)) {
    primary = 'confidence';
  }
  final dominantThemes = qualifying
      .take(3)
      .map((e) => ThemeTrackerService.displayNames[e.key] ?? _titleCase(e.key))
      .toList();

  final title = _titleForChapter(primary, segment);
  final keyBeliefs = _keyBeliefs(segment);
  if (keyBeliefs.isEmpty) return null;

  final quotes = _importantQuotes(segment);
  final evidenceIds = segment.map((e) => e.id).toList();

  return LifeChapter(
    id: 'chapter-$index-${segment.first.id}',
    title: title,
    startDate: segment.first.createdAt,
    endDate: segment.last.createdAt,
    dominantThemes: dominantThemes,
    keyBeliefs: keyBeliefs,
    importantQuotes: quotes,
    evidenceIds: evidenceIds,
  );
}

Map<String, int> _dominantThemeIds(List<JournalEntry> segment) {
  final counts = <String, int>{};
  for (final entry in segment) {
    for (final theme in ThemeTrackerService.themesForEntry(entry)) {
      counts[theme] = (counts[theme] ?? 0) + 1;
    }
  }
  return counts;
}

String _titleForChapter(String primaryTheme, List<JournalEntry> segment) {
  final blob = segment
      .map(_entryBlob)
      .join(' ')
      .toLowerCase();

  switch (primaryTheme) {
    case 'career':
      if (_containsAny(blob, const [
        'transition',
        'new job',
        'promotion',
        'laid off',
        'resign',
        'networking changed',
      ])) {
        return 'Career Transition';
      }
      return 'Career Focus';
    case 'health':
      if (_containsAny(blob, const ['burnout', 'exhausted', 'drained', 'depleted'])) {
        return 'Burnout Period';
      }
      return 'Health Reset';
    case 'relationships':
      if (_segmentSentiment(segment) >= 0) {
        return 'Relationship Growth';
      }
      return 'Relationship Focus';
    case 'confidence':
      if (_confidenceRebuild(segment)) {
        return 'Confidence Rebuild';
      }
      return 'Confidence Work';
    case 'approval':
      return 'Approval & Validation';
    case 'avoidance':
      return 'Avoidance Pattern';
    case 'money':
      return 'Financial Focus';
    default:
      return 'Reflection Period';
  }
}

bool _confidenceRebuild(List<JournalEntry> segment) {
  if (segment.length < 2) return false;
  final half = segment.length ~/ 2;
  final early = segment.sublist(0, half);
  final late = segment.sublist(half);
  final earlyPos = early.fold<int>(
    0,
    (n, e) => n + scoreMarkers(_entryBlob(e).toLowerCase(), positiveMarkers),
  );
  final latePos = late.fold<int>(
    0,
    (n, e) => n + scoreMarkers(_entryBlob(e).toLowerCase(), positiveMarkers),
  );
  return latePos > earlyPos;
}

int _segmentSentiment(List<JournalEntry> segment) {
  var score = 0;
  for (final entry in segment) {
    final lower = _entryBlob(entry).toLowerCase();
    score += scoreMarkers(lower, positiveMarkers);
    score -= scoreMarkers(lower, negativeMarkers);
  }
  return score;
}

List<String> _keyBeliefs(List<JournalEntry> segment) {
  final beliefs = <String>[];
  final seen = <String>{};
  for (final entry in segment.reversed) {
    final obs = entry.reflection.concreteObservation.trim();
    if (obs.length < 16) continue;
    final key = obs.toLowerCase();
    if (!seen.add(key)) continue;
    beliefs.add(obs.length <= 160 ? obs : '${obs.substring(0, 160).trim()}…');
    if (beliefs.length >= 2) break;
  }
  return beliefs;
}

List<LifeChapterQuote> _importantQuotes(List<JournalEntry> segment) {
  final quotes = <LifeChapterQuote>[];
  final seen = <String>{};

  void add(JournalEntry entry, String text) {
    final trimmed = text.trim();
    if (trimmed.length < 12) return;
    final key = trimmed.toLowerCase();
    if (!seen.add(key)) return;
    quotes.add(
      LifeChapterQuote(
        quote: trimmed.length <= 140 ? trimmed : '${trimmed.substring(0, 140).trim()}…',
        entryId: entry.id,
      ),
    );
  }

  for (final entry in segment) {
    add(entry, entry.reflection.exactLanguagePattern);
    if (quotes.length >= 3) break;
  }
  if (quotes.length < 3) {
    for (final entry in segment.reversed) {
      final line = entry.transcript.trim().split('\n').first.trim();
      add(entry, line);
      if (quotes.length >= 3) break;
    }
  }
  return quotes;
}

String _entryBlob(JournalEntry entry) {
  return [
    entry.transcript,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
    ...entry.reflection.recurringThemes,
  ].join(' ');
}

bool _containsAny(String blob, List<String> terms) =>
    terms.any(blob.contains);

String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}
