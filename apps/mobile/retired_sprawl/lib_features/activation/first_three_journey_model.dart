enum FirstThreeJourneyStep { one, two, three, complete }

/// Activation state for the first three reflections journey.
class FirstThreeJourneyModel {
  const FirstThreeJourneyModel({
    required this.reflectionCount,
    required this.currentStep,
    required this.title,
    required this.body,
    required this.progressLabel,
    required this.nextAction,
    required this.completed,
    this.journeyStepIndex = 0,
  });

  final int reflectionCount;
  final FirstThreeJourneyStep currentStep;
  final String title;
  final String body;
  final String progressLabel;
  final String nextAction;
  final bool completed;
  final int journeyStepIndex;

  int get completedSteps {
    if (reflectionCount >= 3) return 3;
    return reflectionCount.clamp(0, 3);
  }

  bool get showOnRecord => !completed;

  bool get showOnPatterns => !completed || reflectionCount < 3;
}