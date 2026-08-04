import '../immediate_archive_value/immediate_archive_value_engine.dart';

export '../immediate_archive_value/immediate_archive_value_engine.dart'
    show fullArchiveMinReflections, isImmediateArchiveValueMode;

import '../../features/archive_evidence/archive_evidence.dart';
import '../../features/contradiction_detection/statement_analysis.dart';
import '../../features/theme_tracking/theme_tracker_service.dart';
import '../../models/journal_entry.dart';
import '../../product/consumer_copy_guard.dart';

/// Archive home uses first-reflection mode below [fullArchiveMinReflections].
int get firstReflectionModeThreshold => fullArchiveMinReflections;

bool isFirstReflectionMode(int reflectionCount) =>
    isImmediateArchiveValueMode(reflectionCount);

const String firstReflectionDisclaimer =
    'We need more recordings before stronger conclusions.';

class FirstReflectionInsights {
  const FirstReflectionInsights({
    required this.reflectionCount,
    required this.noticedLines,
    required this.themeNames,
    required this.phrases,
  });

  final int reflectionCount;
  final List<String> noticedLines;
  final List<String> themeNames;
  final List<String> phrases;

  bool get hasContent =>
      noticedLines.isNotEmpty || themeNames.isNotEmpty || phrases.isNotEmpty;
}

FirstReflectionInsights buildFirstReflectionInsights(
  List<JournalEntry> entries,
) {
  final eligible = archiveEligibleEvidenceEntries(entries);
  final working =
      eligible.isNotEmpty
            ? eligible
            : entries.where((e) => e.transcript.trim().isNotEmpty).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final themes = const ThemeTrackerService()
      .track(entries: entries)
      .topThemes
      .map((t) => t.name)
      .toList();

  final noticed = <String>[];
  final seenNoticed = <String>{};
  for (final entry in working.reversed) {
    final line = _specificNoticedLine(entry);
    if (line != null && seenNoticed.add(line)) {
      noticed.add(line);
      if (noticed.length >= 3) break;
    }
  }

  if (noticed.isEmpty) {
    for (final theme
        in const ThemeTrackerService()
            .track(entries: entries)
            .topThemes
            .take(3)) {
      final themeId = _themeIdForName(theme.name);
      if (themeId == null) continue;
      for (final entry in working.reversed) {
        if (!ThemeTrackerService.themesForEntry(entry).contains(themeId)) {
          continue;
        }
        final line = _noticedLineForTheme(themeId, entry);
        if (line != null && seenNoticed.add(line)) {
          noticed.add(line);
        }
        break;
      }
    }
  }

  if (noticed.isEmpty && working.isNotEmpty) {
    final snippet = _interestingPhraseFromEntry(working.last);
    if (snippet != null) {
      noticed.add('Your recent saved words mentioned “$snippet”.');
    }
  }

  final phrases = <String>[];
  final seenPhrases = <String>{};
  for (final entry in working.reversed) {
    for (final text in archiveStatementTexts(entry)) {
      final phrase = _normalizePhrase(text);
      if (phrase == null) continue;
      if (seenPhrases.add(phrase)) phrases.add(phrase);
      if (phrases.length >= 5) break;
    }
    if (phrases.length >= 5) break;
  }

  return FirstReflectionInsights(
    reflectionCount: entries.length,
    noticedLines: noticed,
    themeNames: themes,
    phrases: phrases,
  );
}

String? _themeIdForName(String name) {
  for (final entry in ThemeTrackerService.displayNames.entries) {
    if (entry.value == name) return entry.key;
  }
  return null;
}

String? _specificNoticedLine(JournalEntry entry) {
  final quote = _specificField(entry.reflection.exactLanguagePattern);
  final observation = _specificField(entry.reflection.concreteObservation);
  if (quote != null && observation != null) {
    if (!observation.toLowerCase().contains(quote.toLowerCase())) {
      return '“${_cap(quote, 90)}” — ${_cap(observation, 150)}';
    }
    return _cap(observation, 170);
  }
  if (observation != null &&
      RegExp(
        r'\b(when|after|before|because|said|checked|opened|avoided|waited|agreed)\b',
        caseSensitive: false,
      ).hasMatch(observation)) {
    return _cap(observation, 170);
  }
  if (quote != null) return 'From this moment: “${_cap(quote, 110)}”.';
  return null;
}

String? _specificField(String raw) {
  final text = ConsumerCopyGuard.userFacingObservation(raw)?.trim();
  if (text == null || text.isEmpty || _isBoilerplate(text)) return null;
  final lower = text.toLowerCase();
  const generic = [
    'you mentioned ',
    'this seems important',
    'you sounded uncertain',
  ];
  return generic.any(lower.contains) ? null : text;
}

String _cap(String text, int maxChars) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= maxChars) return clean;
  final slice = clean.substring(0, maxChars);
  final boundary = slice.lastIndexOf(' ');
  return '${slice.substring(0, boundary > maxChars ~/ 2 ? boundary : maxChars).trim()}…';
}

String? _noticedLineForTheme(String themeId, JournalEntry entry) {
  final blob = _entryBlob(entry).toLowerCase();
  if (!ThemeTrackerService.themesForEntry(entry).contains(themeId)) {
    return null;
  }

  switch (themeId) {
    case 'career':
      if (_hasAny(blob, ['uncertain', 'uncertainty', 'unsure', 'not sure'])) {
        return 'You mentioned career uncertainty.';
      }
      return 'You mentioned career.';
    case 'confidence':
      if (_hasAny(blob, ['doubt', 'uncertain', 'unsure', 'not sure'])) {
        return 'You mentioned uncertainty about confidence.';
      }
      return 'You mentioned confidence.';
    case 'relationships':
      return 'You mentioned relationships.';
    case 'approval':
      return 'You mentioned seeking approval.';
    case 'avoidance':
      return 'You mentioned avoidance.';
    case 'money':
      return 'You mentioned money.';
    case 'health':
      if (_hasAny(blob, ['anxious', 'anxiety', 'burnout', 'stress'])) {
        return 'You mentioned stress or health.';
      }
      return 'You mentioned health.';
    default:
      final label = ThemeTrackerService.displayNames[themeId] ?? themeId;
      return 'You mentioned ${label.toLowerCase()}.';
  }
}

String? _interestingPhraseFromEntry(JournalEntry entry) {
  final candidates = <String?>[
    entry.reflection.exactLanguagePattern,
    entry.reflection.repeatedSignal,
    if (entry.transcript.trim().length >= 16)
      entry.transcript.split('\n').first,
  ];
  for (final raw in candidates) {
    final phrase = _normalizePhrase(raw);
    if (phrase != null) return phrase;
  }
  return null;
}

String? _normalizePhrase(String? raw) {
  var text = raw?.trim() ?? '';
  if (text.isEmpty || _isBoilerplate(text)) return null;
  if (text.length > 120) {
    text = '${text.substring(0, 120).trim()}…';
  }
  return text;
}

bool _isBoilerplate(String text) {
  final lower = text.toLowerCase();
  const blocked = [
    'saved on this device',
    'cloud processing pending',
    'saved locally',
    '[draft]',
    'transcribe when connected',
  ];
  for (final phrase in blocked) {
    if (lower.contains(phrase)) return true;
  }
  return lower.startsWith('the archive') || lower.startsWith('saved ');
}

String _entryBlob(JournalEntry entry) {
  return [
    entry.transcript,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
  ].join(' ');
}

bool _hasAny(String blob, List<String> terms) =>
    terms.any((t) => blob.contains(t));
