import '../../config/app_config.dart';
import '../../features/archive_evidence/archive_evidence.dart';
import '../../features/contradiction_detection/statement_analysis.dart';
import '../../features/theme_tracking/theme_tracker_service.dart';
import '../../models/journal_entry.dart';

/// Full archive surfaces unlock at [fullArchiveMinReflections].
int get fullArchiveMinReflections => AppConfig.patternReviewReflectionTarget;

bool isImmediateArchiveValueMode(int reflectionCount) =>
    reflectionCount > 0 && reflectionCount < fullArchiveMinReflections;

// ——— Models ———
class ImmediateArchiveInsight {
  const ImmediateArchiveInsight({
    this.primaryTheme,
    this.strongestQuote,
    this.interestingPhrase,
    this.firstObservation,
  });

  final String? primaryTheme;
  final String? strongestQuote;
  final String? interestingPhrase;
  final String? firstObservation;

  bool get hasEvidence =>
      primaryTheme != null ||
      strongestQuote != null ||
      interestingPhrase != null ||
      firstObservation != null;
}

class ComparisonInsight {
  const ComparisonInsight({required this.headline, required this.lines});

  final String headline;
  final List<String> lines;

  bool get hasEvidence => lines.isNotEmpty;
}

class PatternInsight {
  const PatternInsight({
    required this.headline,
    required this.lines,
    this.footer = 'This may be becoming a recurring area of attention.',
  });

  final String headline;
  final List<String> lines;
  final String footer;

  bool get hasEvidence => lines.isNotEmpty;
}

class ArchiveMomentumInsight {
  const ArchiveMomentumInsight({
    required this.recordedCount,
    required this.targetCount,
    required this.confidenceLabel,
    required this.body,
  });

  final int recordedCount;
  final int targetCount;
  final String confidenceLabel;
  final String body;

  String get progressLabel => '$recordedCount of $targetCount recordings';
}

// ——— Public builders ———

ImmediateArchiveInsight buildFirstRecordingInsight(List<JournalEntry> entries) {
  final working = _workingEntries(entries);
  if (working.isEmpty) return const ImmediateArchiveInsight();

  final focus = working.last;
  final themeId =
      _primaryThemeIdForEntry(focus) ?? _primaryThemeIdAcross(working);
  final themeName = themeId == null
      ? null
      : ThemeTrackerService.displayNames[themeId] ?? _titleCase(themeId);

  return ImmediateArchiveInsight(
    primaryTheme: themeName,
    strongestQuote: _strongestQuote(focus),
    interestingPhrase: _interestingPhrase(focus),
    firstObservation: _firstObservation(focus, themeId),
  );
}

ComparisonInsight buildSecondRecordingComparison(List<JournalEntry> entries) {
  final working = _workingEntries(entries);
  if (working.length < 2) {
    return const ComparisonInsight(headline: 'Comparison', lines: []);
  }

  final first = working.first;
  final second = working.last;
  final lines = <String>[];

  final sharedThemes = ThemeTrackerService.themesForEntry(
    first,
  ).intersection(ThemeTrackerService.themesForEntry(second));
  if (sharedThemes.isNotEmpty) {
    final name =
        ThemeTrackerService.displayNames[sharedThemes.first] ??
        _titleCase(sharedThemes.first);
    lines.add('$name appeared in both recordings.');
    lines.add('$name was present in both recordings.');
  }

  if (_uncertaintyMentioned(first) && _uncertaintyMentioned(second)) {
    lines.add('You mentioned uncertainty twice.');
  }

  final repeatedPhrase = _repeatedPhraseAcross([first, second]);
  if (repeatedPhrase != null) {
    lines.add('The phrase “$repeatedPhrase” appeared repeatedly.');
  }

  for (final themeId in sharedThemes.skip(1).take(1)) {
    final name = ThemeTrackerService.displayNames[themeId] ?? themeId;
    if (!lines.any((l) => l.contains(name))) {
      lines.add('This theme appeared again: $name.');
    }
  }

  final headline = sharedThemes.isNotEmpty
      ? 'This theme appeared again.'
      : (lines.isNotEmpty ? 'Comparison' : 'Comparison');

  return ComparisonInsight(headline: headline, lines: lines);
}

PatternInsight buildThirdRecordingPattern(List<JournalEntry> entries) {
  final working = _workingEntries(entries);
  if (working.length < 3) {
    return const PatternInsight(headline: 'Early pattern', lines: []);
  }

  final lines = <String>[];
  final n = working.length;

  for (final themeId in ThemeTrackerService.canonicalThemeIds) {
    final hits = working
        .where((e) => ThemeTrackerService.themesForEntry(e).contains(themeId))
        .length;
    if (hits == n) {
      final name =
          ThemeTrackerService.displayNames[themeId] ?? _titleCase(themeId);
      lines.add('$name has appeared in all $n recordings.');
    } else if (hits >= 2 && hits >= (n * 0.66).ceil()) {
      final name =
          ThemeTrackerService.displayNames[themeId] ?? _titleCase(themeId);
      lines.add('$name appears repeatedly.');
    }
  }

  if (_uncertaintyMentionedInAll(working)) {
    if (!lines.any((l) => l.toLowerCase().contains('uncertainty'))) {
      lines.add('Uncertainty is becoming a recurring topic.');
    }
  }

  final approvalHits = working
      .where((e) => ThemeTrackerService.themesForEntry(e).contains('approval'))
      .length;
  if (approvalHits >= 2 && !lines.any((l) => l.contains('Approval'))) {
    lines.add('Approval appears repeatedly.');
  }

  return PatternInsight(headline: 'Early pattern', lines: lines);
}

ArchiveMomentumInsight buildArchiveMomentum(List<JournalEntry> entries) {
  final count = entries.length;
  final eligible = archiveEligibleEvidenceEntries(entries).length;
  final confidenceLabel = eligible >= 3 ? 'Building' : 'Low';

  return ArchiveMomentumInsight(
    recordedCount: count.clamp(0, fullArchiveMinReflections),
    targetCount: fullArchiveMinReflections,
    confidenceLabel: confidenceLabel,
    body:
        'The archive is beginning to see patterns, but needs one more detailed '
        'saved moment before generating a working belief.',
  );
}

// ——— Internals ———

List<JournalEntry> _workingEntries(List<JournalEntry> entries) {
  final eligible = archiveEligibleEvidenceEntries(entries);
  if (eligible.isNotEmpty) return eligible;
  return entries.where((e) => e.transcript.trim().isNotEmpty).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

String? _primaryThemeIdAcross(List<JournalEntry> entries) {
  final counts = <String, int>{};
  for (final e in entries) {
    for (final id in ThemeTrackerService.themesForEntry(e)) {
      counts[id] = (counts[id] ?? 0) + _themeConfidenceScore(id, e);
    }
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String? _primaryThemeIdForEntry(JournalEntry entry) {
  final matched = ThemeTrackerService.themesForEntry(entry).toList();
  if (matched.isEmpty) return null;
  matched.sort(
    (a, b) => _themeConfidenceScore(
      b,
      entry,
    ).compareTo(_themeConfidenceScore(a, entry)),
  );
  return matched.first;
}

int _themeConfidenceScore(String themeId, JournalEntry entry) {
  final blob = _entryBlob(entry).toLowerCase();
  final keywords = _themeKeywords[themeId] ?? const [];
  return keywords.where(blob.contains).length;
}

String? _strongestQuote(JournalEntry entry) {
  final transcript = entry.transcript.trim();
  if (transcript.isEmpty || _isBoilerplate(transcript)) return null;

  final sentences = _splitSentences(transcript);
  if (sentences.isEmpty) return null;

  String? best;
  var bestScore = -1;
  for (final sentence in sentences) {
    final score = _emotionalScore(sentence);
    final words = _wordCount(sentence);
    if (words < 8 || words > 25) continue;
    if (score > bestScore) {
      bestScore = score;
      best = sentence;
    }
  }

  if (best != null) return best;

  for (final sentence in sentences) {
    final words = _wordCount(sentence);
    if (words >= 8 && words <= 25) {
      return sentence;
    }
  }

  final fallback = sentences.first;
  final words = _wordCount(fallback);
  if (words < 8) return null;
  if (words > 25) {
    return _trimToWordRange(fallback, 8, 25);
  }
  return fallback;
}

String? _interestingPhrase(JournalEntry entry) {
  for (final raw in [
    entry.reflection.exactLanguagePattern,
    entry.reflection.repeatedSignal,
  ]) {
    final phrase = _normalizePhrase(raw);
    if (phrase != null && !_isFillerPhrase(phrase)) return phrase;
  }

  final transcript = entry.transcript.trim();
  if (transcript.isEmpty) return null;
  final sentences = _splitSentences(transcript);
  for (final s in sentences) {
    if (_isFillerPhrase(s) || _wordCount(s) < 4) continue;
    if (_emotionalScore(s) >= 1 || s.contains('?')) {
      return _normalizePhrase(s);
    }
  }
  return _normalizePhrase(sentences.isNotEmpty ? sentences.first : transcript);
}

String? _firstObservation(JournalEntry entry, String? themeId) {
  if (_wordCount(entry.transcript.trim()) < 8) return null;
  final blob = _entryBlob(entry).toLowerCase();
  if (themeId == null) return null;

  switch (themeId) {
    case 'career':
      if (_hasAny(blob, ['uncertain', 'uncertainty', 'unsure', 'not sure'])) {
        return 'This moment may be centered on career uncertainty.';
      }
      return 'This moment may be centered on work or career.';
    case 'approval':
      return "This moment may involve approval or other people's opinions.";
    case 'confidence':
      if (_hasAny(blob, ['doubt', 'uncertain', 'unsure'])) {
        return 'This moment may involve doubt or confidence.';
      }
      return 'This moment may involve confidence.';
    case 'relationships':
      return 'This moment may be centered on a relationship.';
    case 'health':
      return 'This moment may involve health or stress.';
    case 'money':
      return 'This moment may involve money.';
    case 'avoidance':
      return 'This moment may involve something you are avoiding.';
    default:
      final name = ThemeTrackerService.displayNames[themeId] ?? themeId;
      return 'This moment may involve ${name.toLowerCase()}.';
  }
}

bool _uncertaintyMentioned(JournalEntry entry) {
  final blob = _entryBlob(entry).toLowerCase();
  return _hasAny(blob, [
    'uncertain',
    'uncertainty',
    'unsure',
    'not sure',
    'doubt',
  ]);
}

bool _uncertaintyMentionedInAll(List<JournalEntry> entries) =>
    entries.every(_uncertaintyMentioned);

String? _repeatedPhraseAcross(List<JournalEntry> entries) {
  const candidates = [
    'not sure',
    'i keep',
    'i feel',
    'uncertain',
    'worried',
    'anxious',
  ];
  for (final phrase in candidates) {
    if (entries.every((e) => _entryBlob(e).toLowerCase().contains(phrase))) {
      return phrase;
    }
  }
  return null;
}

int _emotionalScore(String text) {
  final lower = text.toLowerCase();
  return scoreMarkers(lower, negativeMarkers) +
      scoreMarkers(lower, softNegativeMarkers) +
      scoreMarkers(lower, positiveMarkers) +
      (lower.contains('?') ? 1 : 0);
}

List<String> _splitSentences(String text) {
  return text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.length >= 12 && !_isBoilerplate(s))
      .toList();
}

int _wordCount(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

String _trimToWordRange(String text, int min, int max) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length <= max) return text;
  return '${words.take(max).join(' ')}…';
}

String? _normalizePhrase(String? raw) {
  var text = raw?.trim() ?? '';
  if (text.isEmpty || _isBoilerplate(text)) return null;
  if (text.length > 100) text = '${text.substring(0, 100).trim()}…';
  return text;
}

bool _isFillerPhrase(String text) {
  final lower = text.toLowerCase();
  const filler = ['you know', 'i mean', 'kind of', 'sort of', 'um ', 'uh '];
  return filler.any(lower.contains) && _wordCount(text) < 8;
}

bool _isBoilerplate(String text) {
  final lower = text.toLowerCase();
  if (lower.startsWith('[draft]')) return true;
  const blocked = [
    'saved on this device',
    'cloud processing pending',
    'saved locally',
    'transcribe when connected',
  ];
  return blocked.any(lower.contains);
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

bool _hasAny(String blob, List<String> terms) => terms.any(blob.contains);

String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}

const Map<String, List<String>> _themeKeywords = {
  'approval': ['approval', 'validation', 'people-pleas', 'people pleas'],
  'confidence': ['confidence', 'confident', 'self-worth', 'doubt'],
  'avoidance': ['avoid', 'avoidance', 'procrastinat'],
  'relationships': ['relationship', 'partner', 'family', 'friend'],
  'career': ['career', 'job', 'work', 'promotion', 'manager'],
  'money': ['money', 'financial', 'income', 'salary'],
  'health': ['health', 'anxiety', 'anxious', 'burnout', 'stress'],
};
