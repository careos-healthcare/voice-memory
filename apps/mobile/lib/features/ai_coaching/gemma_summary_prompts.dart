/// System prompts that reshape a voice note with the on-device Gemma model.
enum GemmaSummaryStyle { smartSummary, actionItems, diaryFormat }

abstract final class GemmaSummaryPrompts {
  GemmaSummaryPrompts._();

  static String systemPrompt(GemmaSummaryStyle style) {
    return switch (style) {
      GemmaSummaryStyle.smartSummary =>
        'You rewrite a voice note into a short Smart Summary. '
            'Use plain sentences. Keep the meaning. Do not invent facts.',
      GemmaSummaryStyle.actionItems =>
        'You pull Action Items from a voice note. '
            'Return only next steps, one per line, each starting with a dash. '
            'Do not invent tasks.',
      GemmaSummaryStyle.diaryFormat =>
        'You rewrite a voice note into Diary Format. '
            'Write a short first-person entry in a few sentences. '
            'Do not invent events.',
    };
  }

  static String userPrompt(String transcript) {
    return 'Voice note:\n${transcript.trim()}';
  }
}

class GemmaSummaryResult {
  const GemmaSummaryResult({required this.text, required this.deferred});

  final String text;
  final bool deferred;

  static const waiting = GemmaSummaryResult(
    text: 'This will finish when the device is charging.',
    deferred: true,
  );
}
