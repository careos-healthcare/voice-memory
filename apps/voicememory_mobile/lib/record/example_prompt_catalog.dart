import '../product/consumer_ui_copy.dart';

/// Static conversation starters for first-time capture — no LLM.
abstract class ExamplePromptCatalog {
  ExamplePromptCatalog._();

  static const String sectionTitle = ConsumerUiCopy.needAnIdea;

  static const String continueBuildingArchive =
      ConsumerUiCopy.continueBuildingPatterns;

  static const List<String> prompts = [
    "I'm worried about changing jobs.",
    'Today was better than expected.',
    'I keep putting this off.',
    "I'm excited about this idea.",
  ];
}
