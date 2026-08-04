import '../../models/journal_entry.dart';
import '../../product/consumer_copy_guard.dart';
import '../record/early_specific_insight_engine.dart';
import '../theme_tracking/theme_tracker_service.dart';
import 'instant_reflection_response.dart';

/// Fast, local observation from the latest transcript + reflection metadata only.
class InstantReflectionResponseEngine {
  const InstantReflectionResponseEngine();

  static const int minTranscriptChars = 16;

  /// Returns a single conversational line, or null when there is nothing to say honestly.
  InstantReflectionResponse? respond({
    required JournalEntry entry,
    List<JournalEntry> priorEntries = const [],
  }) {
    final transcript = entry.transcript.trim();
    if (transcript.length < minTranscriptChars) return null;
    if (entry.reflection.explainableConclusion?.provenance.generatedBy ==
        'model') {
      return const InstantReflectionResponse(
        bodyLine: "I'm listening — this moment is in your archive now.",
        signal: InstantReflectionSignal.listening,
      );
    }

    final blob = _entryBlob(entry).toLowerCase();
    final themes = ThemeTrackerService.themesForEntry(entry);
    final prior = priorEntries
        .where((e) => e.transcript.trim().length >= minTranscriptChars)
        .toList();

    final candidates = <_Candidate>[];

    final sharedPhrase = const EarlySpecificInsightEngine().exactSharedPhrase(
      current: entry,
      priorEntries: prior,
    );
    if (sharedPhrase != null) {
      candidates.add(
        _Candidate(
          priority: 0,
          signal: InstantReflectionSignal.repeatedPhrase,
          line:
              'Early signal from ${prior.length + 1} moments: '
              '“$sharedPhrase” appears in this moment and an earlier one.',
        ),
      );
    }

    final groundedLine = _groundedSpecificLine(entry);
    if (groundedLine != null) {
      candidates.add(
        _Candidate(
          priority: 1,
          signal: InstantReflectionSignal.specificObservation,
          line: groundedLine,
        ),
      );
    }

    if (_hasUncertainty(blob)) {
      candidates.add(
        _Candidate(
          priority: 10,
          signal: InstantReflectionSignal.uncertainty,
          line: 'From this moment, your words include uncertainty.',
        ),
      );
    }

    if (_feelsImportant(blob, entry)) {
      candidates.add(
        _Candidate(
          priority: 11,
          signal: InstantReflectionSignal.importance,
          line: 'This feels important to you.',
        ),
      );
    }

    if (_seemsToCare(blob, entry)) {
      candidates.add(
        _Candidate(
          priority: 12,
          signal: InstantReflectionSignal.care,
          line: 'You seem to care about this more than you realize.',
        ),
      );
    }

    final repeatTheme = _repeatedTheme(themes, prior, entry);
    if (repeatTheme != null) {
      candidates.add(
        _Candidate(
          priority: 13,
          signal: InstantReflectionSignal.repeatedTopic,
          line: 'This topic appears repeatedly.',
        ),
      );
    }

    if (_returnedToFamiliar(themes, prior, entry)) {
      candidates.add(
        _Candidate(
          priority: 14,
          signal: InstantReflectionSignal.familiarConcern,
          line: 'You returned to a familiar concern.',
        ),
      );
    }

    if (candidates.isEmpty) {
      return const InstantReflectionResponse(
        bodyLine: "I'm listening — this moment is in your archive now.",
        signal: InstantReflectionSignal.listening,
      );
    }

    candidates.sort((a, b) => a.priority.compareTo(b.priority));
    final top = candidates.first;
    return InstantReflectionResponse(bodyLine: top.line, signal: top.signal);
  }

  static bool _hasUncertainty(String blob) {
    const markers = [
      'uncertain',
      'uncertainty',
      'not sure',
      "don't know",
      'dont know',
      'unsure',
      'second-guess',
      'second guess',
      'maybe i',
      'i wonder if',
    ];
    return markers.any(blob.contains);
  }

  static String? _groundedSpecificLine(JournalEntry entry) {
    final quote = _safeSpecific(entry.reflection.exactLanguagePattern);
    final observation = _safeSpecific(entry.reflection.concreteObservation);
    if (quote != null && observation != null) {
      final clippedQuote = _clip(quote, 90);
      final clippedObservation = _clip(observation, 150);
      if (!clippedObservation.toLowerCase().contains(
        clippedQuote.toLowerCase(),
      )) {
        return 'From this moment: “$clippedQuote” — $clippedObservation';
      }
      return 'From this moment: $clippedObservation';
    }
    final triggerAction = _triggerAction(entry.transcript);
    if (quote != null && triggerAction != null) {
      return 'From this moment: “${_clip(quote, 90)}” — $triggerAction';
    }
    if (observation != null && _hasObservableDetail(observation)) {
      return 'From this moment: ${_clip(observation, 170)}';
    }
    if (quote != null) {
      return 'From this moment: “${_clip(quote, 110)}”.';
    }
    return triggerAction;
  }

  static String? _safeSpecific(String raw) {
    final value = ConsumerCopyGuard.userFacingObservation(raw)?.trim();
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    const generic = [
      'entry language',
      'recorded reflection',
      'you mentioned ',
      'this seems important',
      'you sounded uncertain',
    ];
    return generic.any(lower.contains) ? null : value;
  }

  static String? _triggerAction(String transcript) {
    final match = RegExp(
      r'\b(when|after|before|whenever|every time|because)\s+([^,.!?;]{2,80})[,;]\s*([^.!?;]{2,100})',
      caseSensitive: false,
    ).firstMatch(transcript);
    if (match == null) return null;
    final marker = match.group(1)!.toLowerCase();
    final trigger = match.group(2)!.trim();
    var action = match.group(3)!.trim();
    action = action.replaceFirst(RegExp(r'^I\b', caseSensitive: false), 'you');
    final lead = marker == 'every time'
        ? 'Every time'
        : '${marker[0].toUpperCase()}${marker.substring(1)}';
    return '$lead ${_clip(trigger, 70)}, ${_clip(action, 100)}.';
  }

  static bool _hasObservableDetail(String text) => RegExp(
    r'\b(when|after|before|because|said|opened|checked|reopened|avoided|waited|left|agreed|declined)\b',
    caseSensitive: false,
  ).hasMatch(text);

  static String _clip(String text, int maxChars) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;
    final slice = clean.substring(0, maxChars);
    final boundary = slice.lastIndexOf(' ');
    return '${slice.substring(0, boundary > maxChars ~/ 2 ? boundary : maxChars).trim()}…';
  }

  static bool _feelsImportant(String blob, JournalEntry entry) {
    const markers = [
      'important',
      'matters to me',
      'really matters',
      'means a lot',
      'big deal',
      'need to figure',
      'need to work',
    ];
    if (markers.any(blob.contains)) return true;
    return entry.reflection.emotionalIntensity >= 4 &&
        (blob.contains('really') || blob.contains('so much'));
  }

  static bool _seemsToCare(String blob, JournalEntry entry) {
    const careMarkers = [
      'care about',
      'cares about',
      'i care',
      'love this',
      'love my',
      'worried about',
      'worry about',
      'afraid of losing',
    ];
    return entry.reflection.emotionalIntensity >= 4 &&
        careMarkers.any(blob.contains);
  }

  static String? _repeatedTheme(
    Set<String> themes,
    List<JournalEntry> prior,
    JournalEntry current,
  ) {
    if (themes.isEmpty) return null;

    for (final themeId in themes) {
      var count = 1;
      for (final e in prior) {
        if (ThemeTrackerService.themesForEntry(e).contains(themeId)) {
          count++;
        }
      }
      if (count >= 3) return themeId;
    }
    return null;
  }

  static bool _returnedToFamiliar(
    Set<String> themes,
    List<JournalEntry> prior,
    JournalEntry current,
  ) {
    if (themes.isEmpty || prior.length < 2) return false;

    final sorted = [...prior, current]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final themeId in themes) {
      final withTheme = sorted
          .where((e) => ThemeTrackerService.themesForEntry(e).contains(themeId))
          .toList();
      if (withTheme.length < 2) continue;
      if (withTheme.last.id != current.id) continue;

      final priorIndex = sorted.indexOf(withTheme[withTheme.length - 2]);
      final gap = sorted.length - 1 - priorIndex;
      if (gap >= 2) return true;
    }
    return false;
  }

  static String _entryBlob(JournalEntry entry) {
    return [
      entry.transcript,
      entry.reflection.exactLanguagePattern,
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
      entry.reflection.mood,
      ...entry.reflection.recurringThemes,
    ].join(' ');
  }
}

class _Candidate {
  const _Candidate({
    required this.priority,
    required this.signal,
    required this.line,
  });

  final int priority;
  final InstantReflectionSignal signal;
  final String line;
}
