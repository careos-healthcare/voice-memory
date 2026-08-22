import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/lenses/career_transition_lens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('career transition lens exposes listen targets and cold-start prompt', () {
    expect(CareerTransitionLens.listenTargets.length, 4);
    expect(
      CareerTransitionLens.primaryColdStartPrompt,
      contains('tipping point'),
    );
    expect(CareerTransitionLens.coldStartPromptSeeds.first,
        CareerTransitionLens.primaryColdStartPrompt);
  });

  test('system prompt injection covers identity, skills, risk, and success', () {
    const injection = CareerTransitionLens.systemPromptInjection;
    expect(injection, contains('professional identity shifts'));
    expect(injection, contains('skill-transfer beliefs'));
    expect(injection, contains('risk-tolerance contradictions'));
    expect(injection, contains('definitions of success'));
  });

  test('matches career transition lens only', () {
    expect(CareerTransitionLens.matches(LifeStageLens.careerTransition), isTrue);
    expect(CareerTransitionLens.matches(LifeStageLens.recovery), isFalse);
  });
}