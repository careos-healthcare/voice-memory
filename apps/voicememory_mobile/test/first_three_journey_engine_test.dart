import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/first_three_journey_engine.dart';
import 'package:voicememory_mobile/features/activation/first_three_journey_model.dart';

void main() {
  const engine = FirstThreeJourneyEngine();

  test('0 reflections returns step one copy', () {
    final m = engine.build(reflectionCount: 0);
    expect(m.reflectionCount, 0);
    expect(m.currentStep, FirstThreeJourneyStep.one);
    expect(m.title, 'Start with one ordinary moment.');
    expect(m.progressLabel, '0 of 3 reflections');
    expect(m.nextAction, 'Record your first moment');
    expect(m.completed, isFalse);
  });

  test('1 reflection returns step two copy', () {
    final m = engine.build(reflectionCount: 1);
    expect(m.reflectionCount, 1);
    expect(m.currentStep, FirstThreeJourneyStep.two);
    expect(m.title, 'One pattern may be starting.');
    expect(m.progressLabel, '1 of 3 reflections');
    expect(m.nextAction, 'Add one more moment');
    expect(m.completed, isFalse);
  });

  test('2 reflections returns step three copy', () {
    final m = engine.build(reflectionCount: 2);
    expect(m.currentStep, FirstThreeJourneyStep.three);
    expect(m.title, 'Now ArchiveMe can compare.');
    expect(m.progressLabel, '2 of 3 reflections');
    expect(m.nextAction, 'Add the third moment');
    expect(m.completed, isFalse);
  });

  test('3 reflections returns complete copy', () {
    final m = engine.build(reflectionCount: 3);
    expect(m.currentStep, FirstThreeJourneyStep.complete);
    expect(m.title, 'Your first pattern is forming.');
    expect(m.progressLabel, '3 of 3 reflections');
    expect(m.nextAction, 'View your pattern');
    expect(m.completed, isTrue);
    expect(m.completedSteps, 3);
  });

  test('4+ reflections stays complete', () {
    final m = engine.build(reflectionCount: 9);
    expect(m.completed, isTrue);
    expect(m.reflectionCount, 9);
  });
}
