import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/perspective/kinder_angle_engine.dart';
import 'package:voicememory_mobile/features/perspective/kinder_angle_model.dart';

void main() {
  test('self-blame trigger creates a selfBlame kinder angle', () {
    final angle = buildKinderAngle(
      reflectionText:
          'After the meeting I felt stupid and useless, like it was my fault.',
    );
    expect(angle.trigger, KinderAngleTrigger.selfBlame);
    expect(angle.title, 'A kinder angle');
    expect(angle.kinderRead, contains('wrong with you'));
    expect(angle.nextCheck, 'What happened right before you judged yourself?');
    expect(angle.confidenceLabel, isNull);
  });

  test('pressure trigger creates a pressure kinder angle', () {
    final angle = buildKinderAngle(
      reflectionText:
          'I said yes before I had time, because of the pressure to help.',
    );
    expect(angle.trigger, KinderAngleTrigger.pressure);
    expect(angle.nextCheck, 'Where did the pressure first show up?');
  });

  test('tiredness trigger creates a tiredness kinder angle', () {
    final angle = buildKinderAngle(
      reflectionText:
          'After work I felt exhausted and drained, with no energy left.',
    );
    expect(angle.trigger, KinderAngleTrigger.tiredness);
    expect(angle.kinderRead, contains('running low'));
  });

  test('avoidance trigger creates an avoidance kinder angle', () {
    final angle = buildKinderAngle(
      reflectionText: 'I avoided the email after lunch and put off starting it.',
    );
    expect(angle.trigger, KinderAngleTrigger.avoidance);
    expect(angle.nextCheck, 'What pressure showed up before you delayed it?');
  });

  test('relationship trigger creates a relationship kinder angle', () {
    final angle = buildKinderAngle(
      reflectionText:
          'After the conversation with my boss I replayed it for hours.',
    );
    expect(angle.trigger, KinderAngleTrigger.relationship);
    expect(angle.nextCheck, 'What stayed with you after the conversation?');
  });

  test('every angle carries the caution line', () {
    final angle = buildKinderAngle(
      reflectionText: 'I felt the pressure and said yes before I was ready.',
    );
    expect(angle.cautionLine, 'Use what fits. Leave what does not.');
  });

  test('neutral input is not worth showing', () {
    const neutral = 'I watered the plants and tidied the kitchen this morning.';
    expect(detectKinderAngleTrigger(neutral), isNull);
    expect(shouldShowKinderAngle(neutral), isFalse);
  });

  test('vague but hard input shows an Early read', () {
    final angle = buildKinderAngle(reflectionText: 'I felt so stupid.');
    expect(angle.confidenceLabel, 'Early read');
    expect(angle.isEarlyRead, isTrue);
    expect(angle.kinderRead.toLowerCase(), contains('early read'));
    expect(angle.nextCheck, 'What exact moment felt hard?');
  });

  test('does not show on a clearly lighter result unless self-blame', () {
    const tired = 'I was exhausted and drained but it felt lighter after.';
    expect(
      shouldShowKinderAngle(tired, resultHint: 'lighter'),
      isFalse,
    );
    const blame = 'It felt lighter, but I still felt stupid about it.';
    expect(
      shouldShowKinderAngle(blame, resultHint: 'lighter'),
      isTrue,
    );
  });

  test('shows on a heavier result with a trigger', () {
    const heavy = 'I carried it alone and felt the pressure all day.';
    expect(shouldShowKinderAngle(heavy, resultHint: 'heavier'), isTrue);
  });

  test('trigger override stays grounded without an Early read', () {
    final angle = buildKinderAngle(
      reflectionText: '',
      patternTitle: 'Carrying it alone',
      triggerOverride: KinderAngleTrigger.genericHardMoment,
    );
    expect(angle.trigger, KinderAngleTrigger.genericHardMoment);
    expect(angle.confidenceLabel, isNull);
    expect(angle.kinderRead, contains('one hard moment'));
    expect(angle.sourcePhrase, 'Carrying it alone');
  });
}
