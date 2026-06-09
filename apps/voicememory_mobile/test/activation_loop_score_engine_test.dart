import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/activation_loop_score_engine.dart';
import 'package:voicememory_mobile/features/activation/activation_loop_score_model.dart';

void main() {
  test('weakest bucket is first missing step in order', () {
    final score = buildActivationLoopScore(const ActivationEventCounts());
    expect(score.savedFirstMoment, isFalse);
    expect(score.weakestBucket, ActivationLoopWeakestBucket.firstRecord);
  });

  test('tomorrow check is weakest when first moment saved only', () {
    final score = buildActivationLoopScore(
      const ActivationEventCounts(firstReflectionSaved: 1),
    );
    expect(score.savedFirstMoment, isTrue);
    expect(score.choseTomorrowCheck, isFalse);
    expect(score.weakestBucket, ActivationLoopWeakestBucket.tomorrowCheck);
  });

  test('return day is weakest when tomorrow check chosen but no return', () {
    final score = buildActivationLoopScore(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        firstPatternAccepted: 1,
      ),
    );
    expect(score.weakestBucket, ActivationLoopWeakestBucket.returnDay);
  });

  test('useful result is weakest when loop closed but not rated useful', () {
    final score = buildActivationLoopScore(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        firstPatternAccepted: 1,
        returnedNextDay: 1,
        tomorrowCheckInCompleted: 1,
      ),
    );
    expect(score.closedLoop, isTrue);
    expect(score.ratedUsefulOrSortOf, isFalse);
    expect(score.weakestBucket, ActivationLoopWeakestBucket.usefulResult);
  });

  test('next check is weakest when result rated but no next check chosen', () {
    final score = buildActivationLoopScore(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        firstPatternAccepted: 1,
        returnedNextDay: 1,
        tomorrowCheckInCompleted: 1,
        usefulnessYes: 1,
      ),
    );
    expect(score.weakestBucket, ActivationLoopWeakestBucket.nextCheck);
  });

  test('completed full loop only when all six steps are true', () {
    final partial = buildActivationLoopScore(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        firstPatternAccepted: 1,
        returnedNextDay: 1,
        tomorrowCheckInCompleted: 1,
        usefulnessYes: 1,
      ),
    );
    expect(partial.completedFullLoop, isFalse);

    final full = buildActivationLoopScore(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        firstPatternAccepted: 1,
        returnedNextDay: 1,
        tomorrowCheckInCompleted: 1,
        usefulnessSortOf: 1,
        resultNextCheckUsed: 1,
      ),
    );
    expect(full.completedFullLoop, isTrue);
    expect(full.weakestBucket, ActivationLoopWeakestBucket.none);
  });
}
