/// Models for the beta tester mission card — counts and stable step ids only.
enum TesterMissionStep {
  step1Of3,
  step2Of3,
  step3Of3,
  stillLooking,
  firstProofReached,
  feedbackSaved;

  String get analyticsValue => switch (this) {
    TesterMissionStep.step1Of3 => 'step_1_of_3',
    TesterMissionStep.step2Of3 => 'step_2_of_3',
    TesterMissionStep.step3Of3 => 'step_3_of_3',
    TesterMissionStep.stillLooking => 'still_looking',
    TesterMissionStep.firstProofReached => 'first_proof_reached',
    TesterMissionStep.feedbackSaved => 'feedback_saved',
  };
}

enum TesterMissionPresentation { full, compact }

class TesterMissionResult {
  const TesterMissionResult({
    required this.title,
    required this.body,
    required this.stepLabel,
    required this.footer,
    required this.step,
    required this.presentation,
    required this.entryCount,
  });

  final String title;
  final String body;
  final String stepLabel;
  final String footer;
  final TesterMissionStep step;
  final TesterMissionPresentation presentation;
  final int entryCount;
}
