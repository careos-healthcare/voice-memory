import 'package:archiveme_mobile/features/activation/activation_events_store.dart';
import 'package:archiveme_mobile/features/activation/activation_loop_score_engine.dart';
import 'package:archiveme_mobile/features/activation/activation_loop_score_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weakest bucket is first missing step in order', () {
    final score = buildActivationLoopScore(const ActivationEventCounts());
    expect(score.savedFirstMoment, isFalse);
    expect(score.weakestBucket, ActivationLoopWeakestBucket.firstRecord);
  });

  test('watch-for is weakest when first moment saved only', () {
    final score = buildActivationLoopScore(
      ActivationEventCounts.fromMap({'firstReflectionSaved': 1}),
    );
    expect(score.savedFirstMoment, isTrue);
    expect(score.choseTomorrowCheck, isFalse);
    expect(score.weakestBucket, ActivationLoopWeakestBucket.tomorrowCheck);
  });

  test('return day is weakest when watch-for accepted but no return', () {
    final score = buildActivationLoopScore(
      ActivationEventCounts.fromMap({
        'firstReflectionSaved': 1,
        'watchForPromptAccepted': 1,
      }),
    );
    expect(score.weakestBucket, ActivationLoopWeakestBucket.returnDay);
  });

  test('useful result is weakest when returned but not rated useful', () {
    final score = buildActivationLoopScore(
      ActivationEventCounts.fromMap({
        'firstReflectionSaved': 1,
        'watchForPromptAccepted': 1,
        'returnedNextDay': 1,
        'tomorrowCheckInCompleted': 1,
      }),
    );
    expect(score.closedLoop, isTrue);
    expect(score.ratedUsefulOrSortOf, isFalse);
    expect(score.weakestBucket, ActivationLoopWeakestBucket.usefulResult);
  });

  test('next-check is weakest when v1 steps complete without next-check', () {
    final score = buildActivationLoopScore(
      ActivationEventCounts.fromMap({
        'firstReflectionSaved': 1,
        'watchForPromptAccepted': 1,
        'returnedNextDay': 1,
        'tomorrowCheckInCompleted': 1,
        'usefulnessYes': 1,
      }),
    );
    expect(score.choseNextCheck, isFalse);
    expect(score.completedFullLoop, isFalse);
    expect(score.weakestBucket, ActivationLoopWeakestBucket.nextCheck);
  });

  test('completed full loop only when all tracked steps are true', () {
    final partial = buildActivationLoopScore(
      ActivationEventCounts.fromMap({
        'firstReflectionSaved': 1,
        'watchForPromptAccepted': 1,
        'returnedNextDay': 1,
      }),
    );
    expect(partial.completedFullLoop, isFalse);

    final withoutNextCheck = buildActivationLoopScore(
      ActivationEventCounts.fromMap({
        'firstReflectionSaved': 1,
        'watchForPromptAccepted': 1,
        'returnedNextDay': 1,
        'tomorrowCheckInCompleted': 1,
        'usefulnessSortOf': 1,
      }),
    );
    expect(withoutNextCheck.completedFullLoop, isFalse);
    expect(
      withoutNextCheck.weakestBucket,
      ActivationLoopWeakestBucket.nextCheck,
    );

    final full = buildActivationLoopScore(
      ActivationEventCounts.fromMap({
        'firstReflectionSaved': 1,
        'watchForPromptAccepted': 1,
        'returnedNextDay': 1,
        'tomorrowCheckInCompleted': 1,
        'usefulnessSortOf': 1,
        'resultNextCheckUsed': 1,
      }),
    );
    expect(full.completedFullLoop, isTrue);
    expect(full.weakestBucket, ActivationLoopWeakestBucket.none);
  });
}