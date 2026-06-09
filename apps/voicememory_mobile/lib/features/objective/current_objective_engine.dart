import '../retention/retention_state_model.dart';
import '../tomorrow_return/tomorrow_check_in_model.dart';
import 'current_objective_model.dart';

/// Builds the consumer-visible current objective from loop inputs.
CurrentObjective buildCurrentObjective({
  RetentionState? retentionState,
  TomorrowCheckIn? activeCheckIn,
  required bool hasAnyMoment,
  required bool hasClosedLoopToday,
  required bool hasNextCheckChosen,
  String? latestNextCheck,
  String? latestPatternTitle,
  DateTime? now,
}) {
  const recordRoute = '/record';
  final clock = now ?? DateTime.now();
  final today = tomorrowCheckInDateKey(clock);

  final dueToday = activeCheckIn != null &&
      !activeCheckIn.isCompleted &&
      activeCheckIn.targetDate == today;
  final dueFromRetention =
      retentionState?.type == RetentionStateType.checkDueToday;
  final missedFromRetention =
      retentionState?.type == RetentionStateType.checkMissed;

  if (dueToday || dueFromRetention || missedFromRetention) {
    return CurrentObjective(
      type: CurrentObjectiveType.answerTodayCheck,
      title: 'Today\u2019s check',
      body: 'Answer the check you chose yesterday.',
      checkQuestion: activeCheckIn?.question ?? retentionState?.checkQuestion,
      patternTitle:
          activeCheckIn?.patternTitle ?? retentionState?.patternTitle,
      primaryCtaLabel: 'Answer check',
      route: recordRoute,
      targetDate: activeCheckIn?.targetDate ?? retentionState?.targetDate,
    );
  }

  if (!hasAnyMoment) {
    return const CurrentObjective(
      type: CurrentObjectiveType.recordFirstMoment,
      title: 'Start with one moment',
      body: 'Record one moment to start finding what repeats.',
      primaryCtaLabel: 'Record one moment',
      route: recordRoute,
    );
  }

  if (hasClosedLoopToday && !hasNextCheckChosen) {
    return CurrentObjective(
      type: CurrentObjectiveType.chooseNextCheck,
      title: 'Choose tomorrow\u2019s check',
      body: 'Pick one useful thing to check tomorrow.',
      checkQuestion: latestNextCheck,
      patternTitle: latestPatternTitle,
      primaryCtaLabel: 'Choose check',
      route: recordRoute,
    );
  }

  if (hasNextCheckChosen ||
      retentionState?.type == RetentionStateType.nextCheckChosen) {
    return CurrentObjective(
      type: CurrentObjectiveType.doneForToday,
      title: 'Next check ready',
      body: 'Come back tomorrow to answer it.',
      checkQuestion: latestNextCheck ?? retentionState?.checkQuestion,
      patternTitle: latestPatternTitle ?? retentionState?.patternTitle,
      primaryCtaLabel: 'Done',
      route: recordRoute,
      targetDate: retentionState?.targetDate,
    );
  }

  return const CurrentObjective(
    type: CurrentObjectiveType.recordAnyMoment,
    title: 'Record a moment',
    body: 'Add one moment from today.',
    primaryCtaLabel: 'Record moment',
    route: recordRoute,
  );
}
