import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/lenses/recovery_lens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recovery lens exposes listen targets and cold-start prompts', () {
    expect(RecoveryLens.listenTargets.length, 4);
    expect(RecoveryLens.coldStartPromptSeeds.first, contains('urge'));
    expect(RecoveryLens.coldStartTitle, isNotEmpty);
    expect(RecoveryLens.coldStartSubtitle, contains('Neutral mirror'));
  });

  test('system prompt injection prohibits clinical and therapeutic language', () {
    const injection = RecoveryLens.systemPromptInjection;
    expect(injection, contains('RECOVERY / SOBRIETY LENS'));
    expect(injection, contains('STRICT PROHIBITIONS'));
    expect(injection, contains('clinical advice'));
    expect(injection, contains('therapeutic directives'));
    expect(injection, contains('rationalizations'));
  });

  test('matches recovery lens only', () {
    expect(RecoveryLens.matches(LifeStageLens.recovery), isTrue);
    expect(RecoveryLens.matches(LifeStageLens.careerTransition), isFalse);
  });

  test('suppression multiplier scales negative history counts', () {
    expect(RecoveryLens.scaleSuppressionCount(0), 0);
    expect(RecoveryLens.scaleSuppressionCount(1),
        RecoveryLens.suppressionHistoryMultiplier);
    expect(RecoveryLens.scaleSuppressionCount(2),
        2 * RecoveryLens.suppressionHistoryMultiplier);
  });
}