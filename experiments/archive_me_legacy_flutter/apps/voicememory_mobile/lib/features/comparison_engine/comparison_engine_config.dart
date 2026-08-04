import 'comparison_engine_prompt.dart';

class ComparisonEngineConfig {
  const ComparisonEngineConfig();

  /// Generates the strict system prompt for comparing a new moment to historical words.
  String buildSystemPrompt() => ComparisonEnginePrompt.systemPrompt;
}
