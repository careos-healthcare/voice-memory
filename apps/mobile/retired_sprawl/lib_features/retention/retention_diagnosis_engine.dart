import 'package:archiveme_mobile/features/activation/activation_events_store.dart';
import 'package:archiveme_mobile/features/trial/trial_summary_model.dart';

/// Weakest step in the tomorrow check retention loop.
enum RetentionWeakestBucket {
  noCheckSet,
  didNotReturn,
  didNotCloseLoop,
  didNotChooseNextCheck,
  none,
}

/// Trial readout for where retention breaks down.
class RetentionDiagnosis {
  const RetentionDiagnosis({
    required this.nextDayReturnRate,
    required this.loopCloseRate,
    required this.nextCheckChoiceRate,
    required this.weakestRetentionBucket,
    required this.recommendedFix,
  });

  final double nextDayReturnRate;
  final double loopCloseRate;
  final double nextCheckChoiceRate;
  final RetentionWeakestBucket weakestRetentionBucket;
  final String recommendedFix;
}

const _lowRateThreshold = 0.5;

/// Derives retention health from trial summary counts.
RetentionDiagnosis diagnoseRetentionFromSummary(TrialSummaryModel summary) {
  final saved = summary.firstReflectionSaved;
  final checksSet = summary.checkInCreatedCount;
  final returned = summary.returnedNextDay;
  final closed = summary.checkInCompletedCount;
  final nextChosen = summary.resultNextCheckUsedCount;

  final tomorrowCheckSetRate = saved == 0 ? 0.0 : checksSet / saved.toDouble();
  final nextDayReturnRate = checksSet == 0
      ? 0.0
      : returned / checksSet.toDouble();
  final loopCloseRate = returned == 0 ? 0.0 : closed / returned.toDouble();
  final nextCheckChoiceRate = closed == 0
      ? 0.0
      : nextChosen / closed.toDouble();

  final bucket = _weakestBucket(
    tomorrowCheckSetRate: tomorrowCheckSetRate,
    nextDayReturnRate: nextDayReturnRate,
    loopCloseRate: loopCloseRate,
    nextCheckChoiceRate: nextCheckChoiceRate,
  );

  return RetentionDiagnosis(
    nextDayReturnRate: nextDayReturnRate,
    loopCloseRate: loopCloseRate,
    nextCheckChoiceRate: nextCheckChoiceRate,
    weakestRetentionBucket: bucket,
    recommendedFix: _recommendedFix(bucket),
  );
}

/// Same rates from raw activation counts (for unit tests).
RetentionDiagnosis diagnoseRetentionFromEvents(ActivationEventCounts events) {
  final saved = events.firstReflectionSaved;
  final checksSet = events.tomorrowCheckInCreated;
  final returned = events.returnedNextDay;
  final closed = events.tomorrowCheckInCompleted;
  final nextChosen = events.resultNextCheckUsed;

  final tomorrowCheckSetRate = saved == 0 ? 0.0 : checksSet / saved.toDouble();
  final nextDayReturnRate = checksSet == 0
      ? 0.0
      : returned / checksSet.toDouble();
  final loopCloseRate = returned == 0 ? 0.0 : closed / returned.toDouble();
  final nextCheckChoiceRate = closed == 0
      ? 0.0
      : nextChosen / closed.toDouble();

  final bucket = _weakestBucket(
    tomorrowCheckSetRate: tomorrowCheckSetRate,
    nextDayReturnRate: nextDayReturnRate,
    loopCloseRate: loopCloseRate,
    nextCheckChoiceRate: nextCheckChoiceRate,
  );

  return RetentionDiagnosis(
    nextDayReturnRate: nextDayReturnRate,
    loopCloseRate: loopCloseRate,
    nextCheckChoiceRate: nextCheckChoiceRate,
    weakestRetentionBucket: bucket,
    recommendedFix: _recommendedFix(bucket),
  );
}

RetentionWeakestBucket _weakestBucket({
  required double tomorrowCheckSetRate,
  required double nextDayReturnRate,
  required double loopCloseRate,
  required double nextCheckChoiceRate,
}) {
  if (tomorrowCheckSetRate < _lowRateThreshold) {
    return RetentionWeakestBucket.noCheckSet;
  }
  if (nextDayReturnRate < _lowRateThreshold) {
    return RetentionWeakestBucket.didNotReturn;
  }
  if (loopCloseRate < _lowRateThreshold) {
    return RetentionWeakestBucket.didNotCloseLoop;
  }
  if (nextCheckChoiceRate < _lowRateThreshold) {
    return RetentionWeakestBucket.didNotChooseNextCheck;
  }
  return RetentionWeakestBucket.none;
}

String _recommendedFix(RetentionWeakestBucket bucket) {
  switch (bucket) {
    case RetentionWeakestBucket.noCheckSet:
      return 'Make choosing tomorrow\u2019s check clearer right after the first moment.';
    case RetentionWeakestBucket.didNotReturn:
      return 'Surface today\u2019s check at the top of Record when the user opens the app.';
    case RetentionWeakestBucket.didNotCloseLoop:
      return 'Keep the due check card easy to answer in one tap.';
    case RetentionWeakestBucket.didNotChooseNextCheck:
      return 'Show a compact next-check choice right after the loop closes.';
    case RetentionWeakestBucket.none:
      return 'Retention loop looks healthy; keep the same check flow.';
  }
}