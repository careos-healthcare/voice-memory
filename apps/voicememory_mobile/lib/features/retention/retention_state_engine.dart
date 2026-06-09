import '../tomorrow_return/tomorrow_check_in_model.dart';
import 'retention_state_model.dart';

/// Builds the consumer-visible retention state from loop inputs.
RetentionState buildRetentionState({
  required DateTime now,
  TomorrowCheckIn? activeCheckIn,
  TomorrowCheckIn? missedCheckIn,
  bool hasClosedLoopToday = false,
  bool hasChosenNextCheck = false,
  String? latestNextCheck,
  String? latestPatternTitle,
  bool compact = false,
}) {
  final today = tomorrowCheckInDateKey(now);
  final tomorrow = tomorrowCheckInDateKey(now.add(const Duration(days: 1)));

  if (missedCheckIn != null && !missedCheckIn.isCompleted) {
    return RetentionState(
      type: RetentionStateType.checkMissed,
      title: 'You missed a check',
      body: 'You can still record what happened.',
      checkQuestion: missedCheckIn.question,
      patternTitle: missedCheckIn.patternTitle,
      targetDate: missedCheckIn.targetDate,
      primaryCtaLabel: 'Answer now',
      compact: compact,
    );
  }

  if (activeCheckIn != null && !activeCheckIn.isCompleted) {
    if (activeCheckIn.targetDate == today) {
      return RetentionState(
        type: RetentionStateType.checkDueToday,
        title: 'Today\u2019s check is waiting',
        body: 'Answer the check you chose yesterday.',
        checkQuestion: activeCheckIn.question,
        patternTitle: activeCheckIn.patternTitle,
        targetDate: activeCheckIn.targetDate,
        primaryCtaLabel: 'Answer check',
        urgencyLabel: 'Due today',
        compact: compact,
      );
    }
    if (activeCheckIn.targetDate == tomorrow ||
        activeCheckIn.targetDate.compareTo(today) > 0) {
      if (hasChosenNextCheck) {
        return RetentionState(
          type: RetentionStateType.nextCheckChosen,
          title: 'Next check ready',
          body: 'ArchiveMe will keep this ready for tomorrow.',
          checkQuestion: latestNextCheck ?? activeCheckIn.question,
          patternTitle: latestPatternTitle ?? activeCheckIn.patternTitle,
          targetDate: activeCheckIn.targetDate,
          primaryCtaLabel: 'Done for today',
          compact: true,
        );
      }
      return RetentionState(
        type: RetentionStateType.checkSetForTomorrow,
        title: 'Tomorrow\u2019s check is set',
        body: 'Come back tomorrow to answer this.',
        checkQuestion: activeCheckIn.question,
        patternTitle: activeCheckIn.patternTitle,
        targetDate: activeCheckIn.targetDate,
        primaryCtaLabel: 'View check',
        urgencyLabel: 'Waiting for tomorrow',
        compact: compact,
      );
    }
  }

  if (hasChosenNextCheck) {
    return RetentionState(
      type: RetentionStateType.nextCheckChosen,
      title: 'Next check ready',
      body: 'ArchiveMe will keep this ready for tomorrow.',
      checkQuestion: latestNextCheck,
      patternTitle: latestPatternTitle,
      primaryCtaLabel: 'Done for today',
      compact: true,
    );
  }

  if (hasClosedLoopToday) {
    return RetentionState(
      type: RetentionStateType.loopClosed,
      title: 'Loop closed',
      body: 'You answered yesterday\u2019s check.',
      checkQuestion: latestNextCheck,
      patternTitle: latestPatternTitle,
      primaryCtaLabel: 'Choose next check',
      compact: compact,
    );
  }

  return RetentionState(
    type: RetentionStateType.noCheckSet,
    title: 'No check set',
    body: 'Record one moment to choose what to check tomorrow.',
    primaryCtaLabel: 'Record one moment',
    compact: compact,
  );
}

/// Whether a retention card would duplicate an existing full check-in card.
bool retentionStateDuplicatesFullDueCard(RetentionStateType type) {
  return type == RetentionStateType.checkDueToday;
}

/// Whether a retention card would duplicate an existing Patterns check-in card.
bool retentionStateDuplicatesPatternsCheckInCard({
  required RetentionStateType type,
  required bool hasDueCheckStatusCard,
  required bool hasMissedPrompt,
  required bool hasClosedLoopCard,
}) {
  if (type == RetentionStateType.checkDueToday && hasDueCheckStatusCard) {
    return true;
  }
  if (type == RetentionStateType.checkMissed && hasMissedPrompt) return true;
  if (type == RetentionStateType.loopClosed && hasClosedLoopCard) return true;
  return false;
}
