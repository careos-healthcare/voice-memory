import 'confirmed_repeat_thought_map_models.dart';

/// Which archive gap drives today's return reason.
enum DailyReturnReasonKind {
  missingTrigger,
  missingThought,
  missingAction,
  missingResult,
  missingChange,
  missingPositive,
  complete,
}

/// One daily return reason with body, prompt, and record handoff.
class DailyReturnReasonResult {
  const DailyReturnReasonResult({
    required this.title,
    required this.body,
    required this.prompt,
    required this.guidedRecordPrompt,
    required this.kind,
    this.targetSection,
  });

  final String title;
  final String body;
  final String prompt;
  final String guidedRecordPrompt;
  final DailyReturnReasonKind kind;
  final ThoughtMapSectionId? targetSection;

  bool get needsTriggerCapture =>
      targetSection == ThoughtMapSectionId.trigger;
  bool get needsResultCapture =>
      targetSection == ThoughtMapSectionId.result;
}
