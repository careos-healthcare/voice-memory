import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_result_interpretation.dart';

void main() {
  CheckInResultInterpretation build(String hint, {String? reason}) =>
      buildCheckInResultInterpretation(
        resultHint: hint,
        question: 'Did it show up again?',
        reflectionText: 'It came back in the evening.',
        topNotUsefulReason: reason,
      );

  test('same result explains the repeat and next check', () {
    final r = build('same');
    expect(r.headline, 'It showed up again.');
    expect(r.whatChanged, 'This was a repeat, not a one-off.');
    expect(
      r.whyItMatters,
      'Repeats are useful because they show where the pattern starts.',
    );
    expect(r.nextCheck, 'What happened right before it showed up?');
    expect(r.oneSentenceSummary, contains('It showed up again.'));
  });

  test('lighter result points at what helped', () {
    final r = build('lighter');
    expect(r.headline, 'It felt lighter today.');
    expect(r.whatChanged, 'Something made this easier today.');
    expect(r.whyItMatters, 'That helps you see what may be working.');
    expect(r.nextCheck, 'What helped make it lighter?');
  });

  test('heavier result points at what needs attention', () {
    final r = build('heavier');
    expect(r.headline, 'It felt heavier today.');
    expect(r.whatChanged, 'This took more from you today.');
    expect(
      r.whyItMatters,
      'That is useful because it shows what needs attention.',
    );
    expect(r.nextCheck, 'What made it heavier?');
  });

  test('changed result frames movement', () {
    final r = build('changed');
    expect(r.headline, 'Something changed today.');
    expect(r.whatChanged, 'Today was not just a repeat.');
    expect(
      r.whyItMatters,
      'Change is useful because it shows the pattern can move.',
    );
    expect(r.nextCheck, 'What was different today?');
  });

  test('option ids map to the same hints', () {
    expect(build('showed_up_again').headline, 'It showed up again.');
    expect(build('not_today').headline, 'Something changed today.');
  });

  test('none_fit maps to the changed reading', () {
    final r = build('none_fit');
    expect(r.headline, 'Something changed today.');
    expect(r.nextCheck, 'What was different today?');
  });

  test('too_vague reason appends concrete guidance', () {
    final r = build('same', reason: 'too_vague');
    expect(r.whyItMatters, contains('name the moment, not the whole day'));
  });

  test('not_accurate reason appends closest-answer guidance', () {
    final r = build('same', reason: 'not_accurate');
    expect(r.whyItMatters, contains('Choose the closest answer'));
  });

  test('already_knew_this reason appends change framing', () {
    final r = build('same', reason: 'already_knew_this');
    expect(r.whyItMatters, contains('whether it changes tomorrow'));
  });

  test('confusing reason appends one-sentence guidance', () {
    final r = build('same', reason: 'confusing');
    expect(r.whyItMatters, contains('what happened, and how it felt'));
  });

  test('unknown hint falls back to the repeat reading', () {
    expect(build('???').headline, 'It showed up again.');
  });
}
