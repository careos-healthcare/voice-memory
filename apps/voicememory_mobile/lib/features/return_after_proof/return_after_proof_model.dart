import 'return_after_proof_copy.dart';

import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';

enum ReturnAfterProofWatchTargetType {
  returnedAgain,
  feltLighter,
  feltHeavier,
  helpedAgain,
  handledDifferently,
  avoidedAgain,
  notCurrent,
}

extension ReturnAfterProofWatchTargetTypeAnalytics
    on ReturnAfterProofWatchTargetType {
  String get analyticsValue => switch (this) {
        ReturnAfterProofWatchTargetType.returnedAgain => 'returned_again',
        ReturnAfterProofWatchTargetType.feltLighter => 'felt_lighter',
        ReturnAfterProofWatchTargetType.feltHeavier => 'felt_heavier',
        ReturnAfterProofWatchTargetType.helpedAgain => 'helped_again',
        ReturnAfterProofWatchTargetType.handledDifferently =>
          'handled_differently',
        ReturnAfterProofWatchTargetType.avoidedAgain => 'avoided_again',
        ReturnAfterProofWatchTargetType.notCurrent => 'not_current',
      };
}

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

class ReturnAfterProofStrengthenedResult {
  const ReturnAfterProofStrengthenedResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.targetType,
    required this.confidenceLevel,
    required this.hasAnchor,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.promptLine,
  });

  factory ReturnAfterProofStrengthenedResult.hidden({
    required String source,
    required int entryCount,
  }) =>
      ReturnAfterProofStrengthenedResult(
        shouldShow: false,
        entryCount: entryCount,
        source: source,
        targetType: ReturnAfterProofWatchTargetType.returnedAgain,
        confidenceLevel: ProofConfidenceLevel.watchOnly,
        hasAnchor: false,
        title: ReturnAfterProofCopy.strengthenedTitle,
        body: ReturnAfterProofCopy.fallbackWatchBody,
        primaryCta: ReturnAfterProofCopy.strengthenedPrimaryCta,
        secondaryCta: ReturnAfterProofCopy.strengthenedSecondaryCta,
        promptLine: ReturnAfterProofCopy.promptLineForWatchTarget(
          ReturnAfterProofWatchTargetType.returnedAgain,
        ),
      );

  final bool shouldShow;
  final int entryCount;
  final String source;
  final ReturnAfterProofWatchTargetType targetType;
  final ProofConfidenceLevel confidenceLevel;
  final bool hasAnchor;
  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final String promptLine;
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
    this.strengthened,
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
        strengthened: null,
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
  final ReturnAfterProofStrengthenedResult? strengthened;

  bool get usesStrengthenedCard =>
      strengthened != null && strengthened!.shouldShow;
}
