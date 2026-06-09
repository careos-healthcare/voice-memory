import '../product/consumer_ui_copy.dart';

/// Start Here recording flow — static prompts, no LLM.
abstract final class StartHereCatalog {
  StartHereCatalog._();

  static const String sectionTitle = ConsumerUiCopy.trySayingOneOfThese;

  static const String continueBuildingArchive =
      ConsumerUiCopy.continueBuildingPatterns;

  static const List<String> prompts = [
    'What happened today?',
    "What's bothering you?",
    'What are you excited about?',
    'What are you thinking about right now?',
  ];
}
