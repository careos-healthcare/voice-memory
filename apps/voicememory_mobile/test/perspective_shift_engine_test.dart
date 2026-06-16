import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/perspective/perspective_shift_engine.dart';
import 'package:voicememory_mobile/features/perspective/perspective_shift_model.dart';

const _grounded = 'I said yes before checking what I needed today.';

void main() {
  test('same result prefers pattern or choice', () {
    final shift = buildPerspectiveShift(
      reflectionText: _grounded,
      resultHint: 'same',
    );
    expect(
      shift.type,
      anyOf(PerspectiveShiftType.pattern, PerspectiveShiftType.choice),
    );
    expect(shift.confidenceLabel, isNull);
  });

  test('showed_up_again maps to the same preferred angle', () {
    expect(
      preferredPerspectiveType('showed_up_again'),
      PerspectiveShiftType.pattern,
    );
  });

  test('heavier result prefers pressure or need', () {
    final shift = buildPerspectiveShift(
      reflectionText: _grounded,
      resultHint: 'heavier',
    );
    expect(
      shift.type,
      anyOf(PerspectiveShiftType.pressure, PerspectiveShiftType.need),
    );
    expect(shift.title, 'Where pressure enters');
  });

  test('lighter result prefers kindness or need', () {
    final shift = buildPerspectiveShift(
      reflectionText: _grounded,
      resultHint: 'lighter',
    );
    expect(
      shift.type,
      anyOf(PerspectiveShiftType.kindness, PerspectiveShiftType.need),
    );
  });

  test('changed / none_fit prefers nextStep or choice', () {
    final changed = buildPerspectiveShift(
      reflectionText: _grounded,
      resultHint: 'changed',
    );
    final noneFit = buildPerspectiveShift(
      reflectionText: _grounded,
      resultHint: 'none_fit',
    );
    for (final shift in [changed, noneFit]) {
      expect(
        shift.type,
        anyOf(PerspectiveShiftType.nextStep, PerspectiveShiftType.choice),
      );
    }
  });

  test('vague reflection shows an Early read', () {
    final shift = buildPerspectiveShift(
      reflectionText: 'Today was stressful.',
      resultHint: 'same',
    );
    expect(shift.confidenceLabel, 'Early read');
    expect(shift.isEarlyRead, isTrue);
    expect(shift.perspective.toLowerCase(), contains('early read'));
    expect(shift.nextCheck, 'What exact moment did this show up?');
  });

  test('empty reflection is grounded, not an Early read', () {
    final shift = buildPerspectiveShift(
      reflectionText: '',
      resultHint: 'same',
      patternTitle: 'Saying yes too fast',
    );
    expect(shift.confidenceLabel, isNull);
    expect(shift.sourcePhrase, 'Saying yes too fast');
  });

  test('preferredType forces a specific angle', () {
    final shift = buildPerspectiveShift(
      reflectionText: _grounded,
      resultHint: 'same',
      preferredType: PerspectiveShiftType.kindness,
    );
    expect(shift.type, PerspectiveShiftType.kindness);
    expect(shift.title, 'A kinder angle');
    expect(
      shift.nextCheck,
      'What would you say if this happened to someone else?',
    );
  });

  test('cycle starts with the preferred type and covers every angle', () {
    final cycle = perspectiveCycle('heavier');
    expect(cycle.first, PerspectiveShiftType.pressure);
    expect(cycle.toSet(), PerspectiveShiftType.values.toSet());
    expect(cycle.length, PerspectiveShiftType.values.length);
  });

  test('keeps a short grounding snippet of the reflection', () {
    final shift = buildPerspectiveShift(
      reflectionText: _grounded,
      resultHint: 'same',
    );
    expect(shift.sourcePhrase, isNotNull);
    expect(shift.sourcePhrase!.toLowerCase(), contains('said yes'));
  });
}
