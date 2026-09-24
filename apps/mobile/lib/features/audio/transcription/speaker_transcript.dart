import 'dart:math' as math;

/// One speaker span in a meeting transcript.
class SpeakerTurn {
  const SpeakerTurn({
    required this.speakerLabel,
    required this.text,
    required this.startSeconds,
    required this.endSeconds,
  });

  final String speakerLabel;
  final String text;
  final double startSeconds;
  final double endSeconds;
}

/// Transcript grouped by speaker.
class DiarizedTranscript {
  const DiarizedTranscript({required this.turns});

  final List<SpeakerTurn> turns;

  String get plainText => turns.map((turn) => turn.text).join(' ').trim();

  static DiarizedTranscript singleSpeaker(String transcript) {
    return DiarizedTranscript(
      turns: [
        SpeakerTurn(
          speakerLabel: speakerLabelFor(0),
          text: transcript.trim(),
          startSeconds: 0,
          endSeconds: 0,
        ),
      ],
    );
  }

  /// Parses lines such as `Speaker A: hello`.
  static DiarizedTranscript? parseLabeled(String transcript) {
    final turns = <SpeakerTurn>[];
    for (final line in transcript.split('\n')) {
      final match = RegExp(
        r'^(Speaker [A-Z]):\s*(.+)$',
      ).firstMatch(line.trim());
      if (match == null) continue;
      turns.add(
        SpeakerTurn(
          speakerLabel: match.group(1)!,
          text: match.group(2)!.trim(),
          startSeconds: 0,
          endSeconds: 0,
        ),
      );
    }
    if (turns.length < 2) return null;
    return DiarizedTranscript(turns: turns);
  }
}

/// Maps a zero-based speaker index to `Speaker A`, `Speaker B`, and so on.
String speakerLabelFor(int speakerIndex) {
  if (speakerIndex < 0) return 'Speaker A';
  if (speakerIndex < 26) {
    return 'Speaker ${String.fromCharCode(65 + speakerIndex)}';
  }
  return 'Speaker ${speakerIndex + 1}';
}

class TimedSpeakerSpan {
  const TimedSpeakerSpan({
    required this.start,
    required this.end,
    required this.speaker,
  });

  final double start;
  final double end;
  final int speaker;
}

/// Splits transcript words across diarization spans by how long each span lasts.
List<SpeakerTurn> alignTranscriptToSpeakers({
  required String transcript,
  required List<TimedSpeakerSpan> spans,
}) {
  final words = transcript
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return const [];
  if (spans.isEmpty) {
    return DiarizedTranscript.singleSpeaker(transcript).turns;
  }
  final durations = spans
      .map((span) => math.max(0.001, span.end - span.start))
      .toList(growable: false);
  final total = durations.fold<double>(0, (sum, duration) => sum + duration);
  var wordIndex = 0;
  final turns = <SpeakerTurn>[];
  for (var index = 0; index < spans.length; index++) {
    final span = spans[index];
    final remaining = words.length - wordIndex;
    if (remaining <= 0) break;
    final isLast = index == spans.length - 1;
    final share = isLast
        ? remaining
        : math.min(
            remaining,
            math.max(1, (durations[index] / total * words.length).round()),
          );
    final slice = words.sublist(wordIndex, wordIndex + share);
    wordIndex += share;
    turns.add(
      SpeakerTurn(
        speakerLabel: speakerLabelFor(span.speaker),
        text: slice.join(' '),
        startSeconds: span.start,
        endSeconds: span.end,
      ),
    );
  }
  return turns;
}
