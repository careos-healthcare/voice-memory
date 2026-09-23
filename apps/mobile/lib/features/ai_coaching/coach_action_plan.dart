/// One next step taken from a voice note, with a local time estimate.
class CoachActionItem {
  const CoachActionItem({
    required this.text,
    required this.timelineLabel,
    required this.estimateMinutes,
  });

  final String text;
  final String timelineLabel;
  final int estimateMinutes;
}

/// Pulls action items and timeline estimates from a finished transcript.
///
/// The rules stay on device. Nothing here calls a network model.
abstract final class CoachActionPlan {
  CoachActionPlan._();

  static final _cue = RegExp(
    r'\b(need to|have to|remember to|remind me to|call|email|text|buy|finish|schedule)\b',
    caseSensitive: false,
  );

  static final _minutes = RegExp(
    r'\bin\s+(\d+)\s+minutes?\b',
    caseSensitive: false,
  );
  static final _hours = RegExp(
    r'\bin\s+(\d+)\s+hours?\b',
    caseSensitive: false,
  );

  static List<CoachActionItem> fromTranscript(
    String transcript, {
    int durationSeconds = 0,
  }) {
    final sentences = transcript.split(RegExp(r'(?<=[.!?])\s+|\n+'));
    final items = <CoachActionItem>[];
    for (final raw in sentences) {
      final sentence = raw.trim();
      if (sentence.isEmpty || !_cue.hasMatch(sentence)) continue;
      items.add(
        CoachActionItem(
          text: sentence,
          timelineLabel: _timeline(sentence, durationSeconds),
          estimateMinutes: _minutesFor(sentence, durationSeconds),
        ),
      );
    }
    return items;
  }

  static String _timeline(String sentence, int durationSeconds) {
    final lower = sentence.toLowerCase();
    if (lower.contains('tomorrow')) return 'Tomorrow';
    if (lower.contains('next week') || lower.contains('this week')) {
      return 'This week';
    }
    if (_minutes.hasMatch(sentence) || _hours.hasMatch(sentence)) {
      return 'On the clock in this note';
    }
    if (durationSeconds > 0 && durationSeconds < 90) {
      return 'Right after this note';
    }
    return 'Later today';
  }

  static int _minutesFor(String sentence, int durationSeconds) {
    final minutes = _minutes.firstMatch(sentence);
    if (minutes != null) return int.parse(minutes.group(1)!);
    final hours = _hours.firstMatch(sentence);
    if (hours != null) return int.parse(hours.group(1)!) * 60;
    final lower = sentence.toLowerCase();
    if (lower.contains('tomorrow')) return 24 * 60;
    if (lower.contains('next week') || lower.contains('this week')) {
      return 7 * 24 * 60;
    }
    if (durationSeconds > 0 && durationSeconds < 90) {
      return durationSeconds < 60 ? 15 : durationSeconds ~/ 60;
    }
    return 180;
  }
}
