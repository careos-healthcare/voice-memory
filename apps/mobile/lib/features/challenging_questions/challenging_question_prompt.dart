import 'package:archiveme_mobile/features/challenging_questions/stance_anchor.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';

/// Offline prompt that asks the on-device model for one gentle question.
abstract final class ChallengingQuestionPrompt {
  ChallengingQuestionPrompt._();

  static const systemPrompt = '''
You write privately on this device. Use only the earlier and later anchor points in the user message.
Write one gentle, probing question that offers a counter-perspective.
One sentence. End with a question mark.
No advice, no list, and no second question.
''';

  static const maxAnchorChars = 400;

  static String userPrompt(StanceAnchor anchor) {
    return '''
Topic: ${_clip(anchor.topic)}
Earlier anchor: ${_clip(anchor.earlierStance)}
Later anchor: ${_clip(anchor.laterStance)}

Write one gentle question that looks at this shift from a counter-perspective.
''';
  }

  static LocalLlmCompletionRequest requestFor(StanceAnchor anchor) {
    return LocalLlmCompletionRequest(
      systemPrompt: systemPrompt,
      prompt: userPrompt(anchor),
      maxTokens: 80,
      temperature: 0.4,
    );
  }

  /// Keeps the first question and drops any extra sentences the model added.
  static String? singleQuestion(String raw) {
    var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    text = text.replaceFirst(
      RegExp(r'^(question|q)\s*:\s*', caseSensitive: false),
      '',
    );
    final mark = text.indexOf('?');
    if (mark < 0) return null;
    text = text.substring(0, mark + 1).trim();
    text = text.replaceFirst(RegExp(r'''^["'\s]+'''), '');
    if (text.length < 12 || text.length > 280 || !text.endsWith('?')) {
      return null;
    }
    return text;
  }

  static String _clip(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= maxAnchorChars) return trimmed;
    return '${trimmed.substring(0, maxAnchorChars).trim()}…';
  }
}
