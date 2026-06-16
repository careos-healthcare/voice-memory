import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/objective/current_objective_engine.dart';
import 'package:voicememory_mobile/features/objective/current_objective_model.dart';
import 'package:voicememory_mobile/features/retention/retention_state_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';

TomorrowCheckIn _dueCheck() => TomorrowCheckIn(
  id: 't1',
  createdAt: DateTime(2026, 5, 25),
  targetDate: '2026-05-26',
  patternTitle: 'Pattern',
  prompt: 'Tomorrow, check whether this pattern shows up again.',
  question: 'What happens right before it shows up?',
  options: kDefaultTomorrowCheckInOptions,
);

void main() {
  test('due check today maps to answerTodayCheck', () {
    final objective = buildCurrentObjective(
      activeCheckIn: _dueCheck(),
      hasAnyMoment: true,
      hasClosedLoopToday: false,
      hasNextCheckChosen: false,
      now: DateTime(2026, 5, 26),
    );
    expect(objective.type, CurrentObjectiveType.answerTodayCheck);
    expect(objective.title, 'Today\u2019s check');
    expect(objective.primaryCtaLabel, 'Answer check');
    expect(objective.route, '/record');
  });

  test('no moments maps to recordFirstMoment', () {
    final objective = buildCurrentObjective(
      hasAnyMoment: false,
      hasClosedLoopToday: false,
      hasNextCheckChosen: false,
    );
    expect(objective.type, CurrentObjectiveType.recordFirstMoment);
    expect(objective.primaryCtaLabel, 'Record one moment');
  });

  test('loop closed without next check maps to chooseNextCheck', () {
    final objective = buildCurrentObjective(
      hasAnyMoment: true,
      hasClosedLoopToday: true,
      hasNextCheckChosen: false,
      latestNextCheck: 'What helped make it lighter?',
    );
    expect(objective.type, CurrentObjectiveType.chooseNextCheck);
    expect(objective.primaryCtaLabel, 'Choose check');
  });

  test('next check chosen maps to doneForToday', () {
    final objective = buildCurrentObjective(
      hasAnyMoment: true,
      hasClosedLoopToday: false,
      hasNextCheckChosen: true,
      latestNextCheck: 'What happens right before it shows up?',
      retentionState: const RetentionState(
        type: RetentionStateType.nextCheckChosen,
        title: 'Next check ready',
        body: 'Come back tomorrow.',
        primaryCtaLabel: 'Done',
        compact: true,
      ),
    );
    expect(objective.type, CurrentObjectiveType.doneForToday);
    expect(objective.primaryCtaLabel, 'Done');
  });

  test('default maps to recordAnyMoment', () {
    final objective = buildCurrentObjective(
      hasAnyMoment: true,
      hasClosedLoopToday: false,
      hasNextCheckChosen: false,
    );
    expect(objective.type, CurrentObjectiveType.recordAnyMoment);
    expect(objective.primaryCtaLabel, 'Record moment');
  });
}
