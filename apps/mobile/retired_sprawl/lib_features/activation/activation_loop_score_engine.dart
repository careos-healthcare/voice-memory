import 'package:archiveme_mobile/features/activation/activation_events_store.dart';
import 'package:archiveme_mobile/features/activation/activation_loop_score_model.dart';

/// Derives activation loop health from existing local event counts.
ActivationLoopScore buildActivationLoopScore(ActivationEventCounts events) {
  final savedFirstMoment =
      events.firstReflectionSaved > 0 ||
      events.trialSaveCompleted > 0 ||
      events.activationFirstSaveCompleted > 0;

  final choseTomorrowCheck =
      events.firstPatternAccepted > 0 ||
      events.tomorrowCheckInCreated > 0 ||
      events.watchForPromptAccepted > 0 ||
      events.activationTomorrowCheckUsed > 0;

  final returnedNextDay = events.returnedNextDay > 0;

  final closedLoop =
      events.tomorrowCheckInCompleted > 0 || events.returnDayLoopClosed > 0;

  final ratedUsefulOrSortOf =
      events.usefulnessYes > 0 ||
      events.usefulnessSortOf > 0 ||
      events.activationResultRatedUseful > 0 ||
      events.activationResultRatedSortOf > 0;

  final choseNextCheck =
      events.resultNextCheckUsed > 0 || events.activationNextCheckUsed > 0;

  final completedFullLoop =
      savedFirstMoment &&
      choseTomorrowCheck &&
      returnedNextDay &&
      closedLoop &&
      ratedUsefulOrSortOf &&
      choseNextCheck;

  final weakestBucket = _weakestBucket(
    savedFirstMoment: savedFirstMoment,
    choseTomorrowCheck: choseTomorrowCheck,
    returnedNextDay: returnedNextDay,
    closedLoop: closedLoop,
    ratedUsefulOrSortOf: ratedUsefulOrSortOf,
    choseNextCheck: choseNextCheck,
  );

  return ActivationLoopScore(
    savedFirstMoment: savedFirstMoment,
    choseTomorrowCheck: choseTomorrowCheck,
    returnedNextDay: returnedNextDay,
    closedLoop: closedLoop,
    ratedUsefulOrSortOf: ratedUsefulOrSortOf,
    choseNextCheck: choseNextCheck,
    completedFullLoop: completedFullLoop,
    weakestBucket: weakestBucket,
  );
}

ActivationLoopWeakestBucket _weakestBucket({
  required bool savedFirstMoment,
  required bool choseTomorrowCheck,
  required bool returnedNextDay,
  required bool closedLoop,
  required bool ratedUsefulOrSortOf,
  required bool choseNextCheck,
}) {
  if (!savedFirstMoment) return ActivationLoopWeakestBucket.firstRecord;
  if (!choseTomorrowCheck) return ActivationLoopWeakestBucket.tomorrowCheck;
  if (!returnedNextDay || !closedLoop) {
    return ActivationLoopWeakestBucket.returnDay;
  }
  if (!ratedUsefulOrSortOf) return ActivationLoopWeakestBucket.usefulResult;
  if (!choseNextCheck) return ActivationLoopWeakestBucket.nextCheck;
  return ActivationLoopWeakestBucket.none;
}