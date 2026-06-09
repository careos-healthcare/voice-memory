import '../../product/consumer_ui_copy.dart';
import '../tomorrow_return/active_pattern_thread_model.dart';
import '../tomorrow_return/return_comparison_model.dart';
import 'first_three_journey_model.dart';

/// Builds copy and step state for the first-three reflections journey.
class FirstThreeJourneyEngine {
  const FirstThreeJourneyEngine();

  FirstThreeJourneyModel build({
    required int reflectionCount,
    ActivePatternThread? activeThread,
    ReturnComparison? latestComparison,
  }) {
    final count = reflectionCount.clamp(0, 99);
    if (count >= 3) {
      return _complete(count, activeThread, latestComparison);
    }
    if (count == 2) {
      return _stepTwo(count);
    }
    if (count == 1) {
      return _stepOne(count);
    }
    return _stepZero(count);
  }

  FirstThreeJourneyModel _stepZero(int count) {
    return const FirstThreeJourneyModel(
      reflectionCount: 0,
      currentStep: FirstThreeJourneyStep.one,
      title: 'Start with one ordinary moment.',
      body: ConsumerUiCopy.patternsEarlyStateBody,
      progressLabel: '0 of 3 reflections',
      nextAction: 'Record your first moment',
      completed: false,
    );
  }

  FirstThreeJourneyModel _stepOne(int count) {
    return FirstThreeJourneyModel(
      reflectionCount: count,
      currentStep: FirstThreeJourneyStep.two,
      title: 'One pattern may be starting.',
      body:
          'Add one more reflection so ArchiveMe can see whether this shows up again.',
      progressLabel: '1 of 3 reflections',
      nextAction: 'Add one more moment',
      completed: false,
    );
  }

  FirstThreeJourneyModel _stepTwo(int count) {
    return FirstThreeJourneyModel(
      reflectionCount: count,
      currentStep: FirstThreeJourneyStep.three,
      title: 'Now ArchiveMe can compare.',
      body:
          'A third reflection helps separate a one-off moment from something that may be repeating.',
      progressLabel: '2 of 3 reflections',
      nextAction: 'Add the third moment',
      completed: false,
    );
  }

  FirstThreeJourneyModel _complete(
    int count,
    ActivePatternThread? activeThread,
    ReturnComparison? latestComparison,
  ) {
    var body =
        'ArchiveMe now has enough to start showing what repeats, changes, or eases.';
    if (activeThread != null && activeThread.title.trim().isNotEmpty) {
      body =
          'ArchiveMe is tracking “${activeThread.title.trim()}” across your moments.';
    } else if (latestComparison != null) {
      body =
          'ArchiveMe can compare today with yesterday and show what keeps repeating.';
    }

    return FirstThreeJourneyModel(
      reflectionCount: count,
      currentStep: FirstThreeJourneyStep.complete,
      title: 'Your first pattern is forming.',
      body: body,
      progressLabel: '3 of 3 reflections',
      nextAction: 'View your pattern',
      completed: true,
    );
  }
}
