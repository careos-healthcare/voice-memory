import 'return_after_proof_copy.dart';

enum ReturnAfterProofPromptType {
  itCameBack,
  feltLighter,
  feltHeavier,
  somethingHelped,
  handledDifferently,
  notToday,
}

extension ReturnAfterProofPromptTypeAnalytics on ReturnAfterProofPromptType {
  String get analyticsValue => switch (this) {
        ReturnAfterProofPromptType.itCameBack => 'it_came_back',
        ReturnAfterProofPromptType.feltLighter => 'felt_lighter',
        ReturnAfterProofPromptType.feltHeavier => 'felt_heavier',
        ReturnAfterProofPromptType.somethingHelped => 'something_helped',
        ReturnAfterProofPromptType.handledDifferently => 'handled_differently',
        ReturnAfterProofPromptType.notToday => 'not_today',
      };
}

extension ReturnAfterProofPromptTypeLists on ReturnAfterProofPromptType {
  static const capturePrompts = [
    ReturnAfterProofPromptType.itCameBack,
    ReturnAfterProofPromptType.feltLighter,
    ReturnAfterProofPromptType.feltHeavier,
    ReturnAfterProofPromptType.somethingHelped,
    ReturnAfterProofPromptType.handledDifferently,
    ReturnAfterProofPromptType.notToday,
  ];
}

class ReturnAfterProofPrompt {
  const ReturnAfterProofPrompt({
    required this.type,
    required this.label,
    required this.selectedLine,
  });

  final ReturnAfterProofPromptType type;
  final String label;
  final String selectedLine;
}

class ReturnAfterProofResult {
  const ReturnAfterProofResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.closingLine,
    required this.prompts,
    required this.entryCount,
    required this.source,
    required this.hasTimelineProof,
    required this.hasFirstProof,
  });

  factory ReturnAfterProofResult.hidden({
    required String source,
    required int entryCount,
  }) =>
      ReturnAfterProofResult(
        shouldShow: false,
        title: ReturnAfterProofCopy.title,
        body: ReturnAfterProofCopy.body,
        closingLine: ReturnAfterProofCopy.closingLine,
        prompts: const [],
        entryCount: entryCount,
        source: source,
        hasTimelineProof: false,
        hasFirstProof: false,
      );

  final bool shouldShow;
  final String title;
  final String body;
  final String closingLine;
  final List<ReturnAfterProofPrompt> prompts;
  final int entryCount;
  final String source;
  final bool hasTimelineProof;
  final bool hasFirstProof;
}
