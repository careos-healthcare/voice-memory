import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/feedback/archive_feedback_model.dart';
import 'package:voicememory_mobile/features/feedback/archive_feedback_summary_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/result_next_check_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/result_next_check_model.dart';

void main() {
  test('same / showed up again creates repeatBefore', () {
    for (final hint in ['same', 'showed_up_again']) {
      final next = ResultNextCheckEngine.build(resultHint: hint);
      expect(next.type, ResultNextCheckType.repeatBefore);
      expect(next.title, 'Check what happens before it starts');
      expect(next.nextQuestion, 'What happens right before it shows up?');
      expect(next.exampleMoment, 'I noticed it started before I said yes.');
      expect(next.ctaLabel, 'Use this tomorrow');
    }
  });

  test('lighter result creates findHelped', () {
    final next = ResultNextCheckEngine.build(resultHint: 'lighter');
    expect(next.type, ResultNextCheckType.findHelped);
    expect(next.title, 'Check what helped');
    expect(next.nextQuestion, 'What helped make it lighter?');
    expect(next.exampleMoment, 'It felt lighter after I paused.');
  });

  test('heavier result creates reduceHeavier', () {
    final next = ResultNextCheckEngine.build(resultHint: 'heavier');
    expect(next.type, ResultNextCheckType.reduceHeavier);
    expect(next.title, 'Check what made it heavier');
    expect(next.nextQuestion, 'What made it heavier?');
    expect(next.exampleMoment, 'It felt heavier after I took it on alone.');
  });

  test('changed / not_today / none_fit creates noticeDifferent', () {
    for (final hint in ['changed', 'not_today', 'none_fit']) {
      final next = ResultNextCheckEngine.build(resultHint: hint);
      expect(next.type, ResultNextCheckType.noticeDifferent);
      expect(next.title, 'Check what changed');
      expect(next.nextQuestion, 'What was different today?');
      expect(next.exampleMoment, 'It changed when I waited before answering.');
    }
  });

  test('too_vague reason creates makeConcrete and overrides result type', () {
    final next = ResultNextCheckEngine.build(
      resultHint: 'lighter',
      notUsefulReason: 'too_vague',
    );
    expect(next.type, ResultNextCheckType.makeConcrete);
    expect(next.title, 'Make the next check more concrete');
    expect(next.nextQuestion, 'What was the exact moment this showed up?');
    expect(next.exampleMoment, 'It showed up when I opened the message.');
  });

  test('already_knew_this keeps result type but strengthens why useful', () {
    final next = ResultNextCheckEngine.build(
      resultHint: 'same',
      notUsefulReason: 'already_knew_this',
    );
    expect(next.type, ResultNextCheckType.repeatBefore);
    expect(next.whyUseful, contains('The value is not that it happened once.'));
    expect(next.whyUseful, contains('whether it keeps happening or changes'));
  });

  test('confusing keeps result type but adds simple-answer guidance', () {
    final next = ResultNextCheckEngine.build(
      resultHint: 'heavier',
      notUsefulReason: 'confusing',
    );
    expect(next.type, ResultNextCheckType.reduceHeavier);
    expect(next.whyUseful, contains('Keep tomorrow'));
    expect(next.whyUseful, contains('lighter, heavier, or different'));
  });

  test('tooGeneric feedback gently prefers a concrete next check', () {
    final next = ResultNextCheckEngine.build(
      resultHint: 'lighter',
      feedback: ArchiveFeedbackType.tooGeneric,
    );
    expect(next.type, ResultNextCheckType.makeConcrete);
    expect(next.nextQuestion, 'What was the exact moment this showed up?');
  });

  test('moreSpecific feedback also points at one exact moment', () {
    final next = ResultNextCheckEngine.build(
      resultHint: 'same',
      feedback: ArchiveFeedbackType.moreSpecific,
    );
    expect(next.type, ResultNextCheckType.makeConcrete);
  });

  test('alreadyKnew feedback emphasizes change over time', () {
    final next = ResultNextCheckEngine.build(
      resultHint: 'same',
      feedback: ArchiveFeedbackType.alreadyKnew,
    );
    expect(next.type, ResultNextCheckType.repeatBefore);
    expect(next.whyUseful, contains('whether it keeps happening or changes'));
  });

  test('useful and notMe feedback keep the current style', () {
    for (final f in [ArchiveFeedbackType.useful, ArchiveFeedbackType.notMe]) {
      final next = ResultNextCheckEngine.build(
        resultHint: 'lighter',
        feedback: f,
      );
      expect(next.type, ResultNextCheckType.findHelped);
      expect(next.nextQuestion, 'What helped make it lighter?');
    }
  });

  test('an explicit not-useful reason still wins over feedback', () {
    final next = ResultNextCheckEngine.build(
      resultHint: 'lighter',
      notUsefulReason: 'too_vague',
      feedback: ArchiveFeedbackType.useful,
    );
    expect(next.type, ResultNextCheckType.makeConcrete);
  });

  test(
    'feedbackSummary dominant issue nudges next check like feedback type',
    () {
      final summary = ArchiveFeedbackSummary(
        total: 2,
        usefulCount: 0,
        tooGenericCount: 2,
        notMeCount: 0,
        alreadyKnewCount: 0,
        moreSpecificCount: 0,
        dominantIssue: ArchiveFeedbackType.tooGeneric,
      );
      final next = ResultNextCheckEngine.build(
        resultHint: 'lighter',
        feedbackSummary: summary,
      );
      expect(next.type, ResultNextCheckType.makeConcrete);
      expect(next.nextQuestion, 'What was the exact moment this showed up?');
    },
  );
}
