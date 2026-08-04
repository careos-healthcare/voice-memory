import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/retention/retention_state_engine.dart';
import 'package:voicememory_mobile/features/retention/retention_state_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';

TomorrowCheckIn _checkIn({
  required String targetDate,
  bool completed = false,
  String question = 'Did this pattern show up again?',
}) => TomorrowCheckIn(
  id: 'tci_test',
  createdAt: DateTime(2026, 6, 1),
  targetDate: targetDate,
  patternTitle: 'Evening pressure',
  prompt: 'Tomorrow, check whether this pattern shows up again.',
  question: question,
  options: kDefaultTomorrowCheckInOptions,
  completedAt: completed ? DateTime(2026, 6, 2) : null,
);

void main() {
  final now = DateTime(2026, 6, 2, 10);
  final today = tomorrowCheckInDateKey(now);
  final tomorrow = tomorrowCheckInDateKey(now.add(const Duration(days: 1)));

  test('noCheckSet when nothing active', () {
    final state = buildRetentionState(now: now);
    expect(state.type, RetentionStateType.noCheckSet);
    expect(state.title, 'No check set');
    expect(state.primaryCtaLabel, 'Record one moment');
  });

  test('checkSetForTomorrow when active targets tomorrow', () {
    final state = buildRetentionState(
      now: now,
      activeCheckIn: _checkIn(targetDate: tomorrow),
    );
    expect(state.type, RetentionStateType.checkSetForTomorrow);
    expect(state.urgencyLabel, 'Waiting for tomorrow');
    expect(state.primaryCtaLabel, 'View check');
  });

  test('checkDueToday when active targets today', () {
    final state = buildRetentionState(
      now: now,
      activeCheckIn: _checkIn(targetDate: today),
    );
    expect(state.type, RetentionStateType.checkDueToday);
    expect(state.urgencyLabel, 'Due today');
    expect(state.primaryCtaLabel, 'Answer check');
  });

  test('checkMissed takes priority over no check set', () {
    final state = buildRetentionState(
      now: now,
      missedCheckIn: _checkIn(targetDate: '2026-06-01'),
    );
    expect(state.type, RetentionStateType.checkMissed);
    expect(state.primaryCtaLabel, 'Answer now');
  });

  test('loopClosed when loop closed today without next check', () {
    final state = buildRetentionState(
      now: now,
      hasClosedLoopToday: true,
      latestNextCheck: 'What helped make it lighter?',
    );
    expect(state.type, RetentionStateType.loopClosed);
    expect(state.primaryCtaLabel, 'Choose next check');
  });

  test('nextCheckChosen when user just chose next check', () {
    final state = buildRetentionState(
      now: now,
      activeCheckIn: _checkIn(targetDate: tomorrow),
      hasChosenNextCheck: true,
    );
    expect(state.type, RetentionStateType.nextCheckChosen);
    expect(state.title, 'Next check ready');
    expect(state.primaryCtaLabel, 'Done for today');
    expect(state.compact, isTrue);
  });

  test('due card duplication guard', () {
    expect(
      retentionStateDuplicatesFullDueCard(RetentionStateType.checkDueToday),
      isTrue,
    );
    expect(
      retentionStateDuplicatesFullDueCard(
        RetentionStateType.checkSetForTomorrow,
      ),
      isFalse,
    );
  });
}
