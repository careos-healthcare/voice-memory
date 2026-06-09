import '../../models/journal_entry.dart';
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

    final blob = _entryBlob(entry).toLowerCase();
    final themes = ThemeTrackerService.themesForEntry(entry);
    final prior = priorEntries
        .where((e) => e.transcript.trim().length >= minTranscriptChars)
        .toList();

    final candidates = <_Candidate>[];

    if (_hasUncertainty(blob)) {
      candidates.add(
        _Candidate(
          priority: 0,
          signal: InstantReflectionSignal.uncertainty,
          line: 'I noticed you sounded uncertain about this.',
        ),
      );
    }

    if (_feelsImportant(blob, entry)) {
      candidates.add(
        _Candidate(
          priority: 1,
          signal: InstantReflectionSignal.importance,
          line: 'This feels important to you.',
        ),
      );
    }

    if (_seemsToCare(blob, entry)) {
      candidates.add(
        _Candidate(
          priority: 2,
          signal: InstantReflectionSignal.care,
          line: 'You seem to care about this more than you realize.',
        ),
      );
    }

    final repeatTheme = _repeatedTheme(themes, prior, entry);
    if (repeatTheme != null) {
      candidates.add(
        _Candidate(
          priority: 3,
          signal: InstantReflectionSignal.repeatedTopic,
          line: 'This topic appears repeatedly.',
        ),
      );
    }

    if (_returnedToFamiliar(themes, prior, entry)) {
      candidates.add(
        _Candidate(
          priority: 4,
          signal: InstantReflectionSignal.familiarConcern,
          line: 'You returned to a familiar concern.',
        ),
      );
    }

    if (candidates.isEmpty) {
      return const InstantReflectionResponse(
        bodyLine: "I'm listening — this reflection is in your archive now.",
        signal: InstantReflectionSignal.listening,
      );
    }

    candidates.sort((a, b) => a.priority.compareTo(b.priority));
    final top = candidates.first;
    return InstantReflectionResponse(
      bodyLine: top.line,
      signal: top.signal,
    );
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
