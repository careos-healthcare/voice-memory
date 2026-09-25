import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Static conversation starters for first-time capture — no LLM.
abstract class ExamplePromptCatalog {
  ExamplePromptCatalog._();

  static const String sectionTitle = ConsumerUiCopy.needAnIdea;

  static const String continueBuildingArchive =
      ConsumerUiCopy.continueBuildingPatterns;

  static const List<String> prompts = [
    "What's on your mind about work?",
    'What made today better than you expected?',
    'What have you been putting off?',
    'What idea are you excited about?',
  ];
}