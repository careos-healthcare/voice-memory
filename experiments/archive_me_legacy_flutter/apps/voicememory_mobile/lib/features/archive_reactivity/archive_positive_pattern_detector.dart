import 'archive_display_copy_guard.dart';

enum ArchivePositivePatternSignalType {
  pause,
  reducedUrgency,
  stoppedSooner,
  choseDifferentAction,
  completedAction,
  askedForSupport,
  unclearHelpfulSignal;

  String get logId => name;
}

class ArchivePositivePatternSignal {
  const ArchivePositivePatternSignal({
    required this.signalType,
    required this.evidencePhrase,
    required this.title,
    required this.nextPrompt,
    required this.confidenceLabel,
    required this.entryId,
  });

  final ArchivePositivePatternSignalType signalType;
  final String evidencePhrase;
  final String title;
  final String nextPrompt;
  final String confidenceLabel;
  final String entryId;
}

abstract class ArchivePositivePatternDetector {
  ArchivePositivePatternDetector._();

  static const _banned = [
    'diagnosis',
    'therapy',
    'cure',
    'addiction',
    'mental health',
    'fix your thoughts',
    'negative thoughts',
    'this proves',
    'you always',
  ];

  static const _patterns = <ArchivePositivePatternSignalType, List<String>>{
    ArchivePositivePatternSignalType.askedForSupport: [
      'asked for help',
      'talked to',
      'reached out',
      'called someone',
    ],
    ArchivePositivePatternSignalType.pause: [
      'paused',
      'pause before',
      'took a pause',
      'waited before',
      'chose to wait',
      'decided to wait',
    ],
    ArchivePositivePatternSignalType.reducedUrgency: [
      'less urgent',
      'felt less urgent',
      'not as urgent',
      'calmer',
      'felt calmer',
      'easier to stop',
    ],
    ArchivePositivePatternSignalType.stoppedSooner: [
      'stopped sooner',
      'stopped after one',
      'did not check again',
      "didn't check again",
      'checked less',
      'only checked once',
      'one check was enough',
    ],
    ArchivePositivePatternSignalType.choseDifferentAction: [
      'chose not to',
      'decided not to',
      'went for a walk',
      'walked away',
      'tried something else',
      'did something else',
    ],
    ArchivePositivePatternSignalType.completedAction: [
      'finished the task',
      'finished it',
      'got it done',
      'completed',
      'wrote it down',
      'made a plan',
      'planned',
      'slept',
    ],
  };

  static List<ArchivePositivePatternSignal> detectFromTranscripts({
    required List<({String entryId, String transcript})> entries,
  }) {
    final signals = <ArchivePositivePatternSignal>[];
    for (final entry in entries) {
      final transcript = entry.transcript.trim();
      if (transcript.isEmpty) continue;
      final lower = transcript.toLowerCase();
      if (_containsBanned(lower)) continue;

      for (final pattern in _patterns.entries) {
        for (final phrase in pattern.value) {
          if (!lower.contains(phrase)) continue;
          final evidence = _extractEvidencePhrase(transcript, phrase);
          if (evidence.isEmpty) continue;
          final signal = _buildSignal(
            type: pattern.key,
            evidencePhrase: evidence,
            entryId: entry.entryId,
          );
          if (signal != null) signals.add(signal);
          break;
        }
      }
    }
    return signals;
  }

  static ArchivePositivePatternSignal? detectLatest({
    required String entryId,
    required String transcript,
  }) {
    final hits = detectFromTranscripts(
      entries: [(entryId: entryId, transcript: transcript)],
    );
    return hits.isEmpty ? null : hits.first;
  }

  static ArchivePositivePatternSignal? _buildSignal({
    required ArchivePositivePatternSignalType type,
    required String evidencePhrase,
    required String entryId,
  }) {
    final copy = _copyFor(type, evidencePhrase);
    if (copy == null) return null;
    return ArchivePositivePatternSignal(
      signalType: type,
      evidencePhrase: evidencePhrase,
      title: copy.title,
      nextPrompt: copy.nextPrompt,
      confidenceLabel: copy.confidenceLabel,
      entryId: entryId,
    );
  }

  static _PositiveCopy? _copyFor(
    ArchivePositivePatternSignalType type,
    String evidencePhrase,
  ) {
    final quote = _guardQuote(evidencePhrase);
    return switch (type) {
      ArchivePositivePatternSignalType.pause => _PositiveCopy(
        title: 'A helpful pattern appeared',
        nextPrompt: 'Record what helped you wait.',
        confidenceLabel: 'Based on your words',
        evidenceTemplate: "The strongest clue is: '$quote'.",
      ),
      ArchivePositivePatternSignalType.reducedUrgency => _PositiveCopy(
        title: 'Urgency may be easing',
        nextPrompt: 'Record whether this calmer tone comes back next time.',
        confidenceLabel: 'Early signal',
        evidenceTemplate:
            "Your latest recording sounded less urgent: '$quote'.",
      ),
      ArchivePositivePatternSignalType.stoppedSooner => _PositiveCopy(
        title: 'A helpful pattern appeared',
        nextPrompt: 'Record what helped you stop sooner.',
        confidenceLabel: 'Based on your words',
        evidenceTemplate: "The strongest clue is: '$quote'.",
      ),
      ArchivePositivePatternSignalType.choseDifferentAction => _PositiveCopy(
        title: 'Something helped',
        nextPrompt: 'Record what made the different action possible.',
        confidenceLabel: 'Based on your words',
        evidenceTemplate:
            'Your recording mentioned a pause, delay, or different action: '
            "'$quote'.",
      ),
      ArchivePositivePatternSignalType.completedAction => _PositiveCopy(
        title: 'A helpful pattern appeared',
        nextPrompt: 'Record what helped you follow through.',
        confidenceLabel: 'Early signal',
        evidenceTemplate: "The strongest clue is: '$quote'.",
      ),
      ArchivePositivePatternSignalType.askedForSupport => _PositiveCopy(
        title: 'Something helped',
        nextPrompt: 'Record what made reaching out possible.',
        confidenceLabel: 'Based on your words',
        evidenceTemplate: "Your recording mentioned support: '$quote'.",
      ),
      ArchivePositivePatternSignalType.unclearHelpfulSignal => null,
    };
  }

  static String _extractEvidencePhrase(String transcript, String matched) {
    final lower = transcript.toLowerCase();
    final index = lower.indexOf(matched.toLowerCase());
    if (index < 0) return matched;

    final start = _sentenceStart(transcript, index);
    final end = _sentenceEnd(transcript, index + matched.length);
    final slice = transcript.substring(start, end).trim();
    if (slice.length < 8) return _guardQuote(matched);
    return _guardQuote(slice);
  }

  static int _sentenceStart(String text, int index) {
    var start = index;
    while (start > 0 && text[start - 1] != '.' && text[start - 1] != '\n') {
      start--;
      if (index - start > 90) break;
    }
    return start;
  }

  static int _sentenceEnd(String text, int index) {
    var end = index;
    while (end < text.length && text[end] != '.' && text[end] != '\n') {
      end++;
      if (end - index > 90) break;
    }
    return end.clamp(0, text.length);
  }

  static String _guardQuote(String raw) {
    final normalized = ArchiveDisplayCopyGuard.validateAndNormalize(
      field: 'evidence',
      text: raw,
      requireSpecificity: false,
    );
    if (normalized.isNotEmpty) return normalized;
    final trimmed = raw.trim();
    return trimmed.length > 120 ? '${trimmed.substring(0, 117)}...' : trimmed;
  }

  static bool _containsBanned(String lower) {
    for (final token in _banned) {
      if (lower.contains(token)) return true;
    }
    return false;
  }
}

class _PositiveCopy {
  const _PositiveCopy({
    required this.title,
    required this.nextPrompt,
    required this.confidenceLabel,
    required this.evidenceTemplate,
  });

  final String title;
  final String nextPrompt;
  final String confidenceLabel;
  final String evidenceTemplate;

  String evidenceLine(String quote) =>
      evidenceTemplate.replaceAll("'$quote'", "'$quote'");
}
