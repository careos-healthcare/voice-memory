import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/habit_proof_engine.dart';
import 'package:voicememory_mobile/features/pattern_memory/habit_proof_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_model.dart';

const _engine = HabitProofEngine();

PatternMemory _memory({int checkInCount = 3, String? nextBestQuestion}) =>
    PatternMemory(
      id: 'pm1',
      patternTitle: 'saying yes when you mean no',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 4),
      checkInCount: checkInCount,
      showedAgainCount: 0,
      lighterCount: 0,
      heavierCount: 0,
      changedCount: 0,
      commonBeforeMoments: const [],
      helpedMoments: const [],
      harderMoments: const [],
      nextBestQuestion: nextBestQuestion,
      status: PatternMemoryStatus.active,
    );

PatternProgressMoment _progress({bool shouldShow = true}) =>
    PatternProgressMoment(
      id: 'pp_pm1_3',
      memoryId: 'pm1',
      createdAt: DateTime(2026, 6, 4),
      type: PatternProgressType.stillRepeating,
      headline: 'This pattern is still showing up.',
      body: 'body',
      nextLine: 'next',
      checkInCount: 3,
      shouldShow: shouldShow,
    );

PatternNextAction _action() => PatternNextAction(
  id: 'na_pm1_3_repeatCheck',
  memoryId: 'pm1',
  createdAt: DateTime(2026, 6, 4),
  type: PatternNextActionType.repeatCheck,
  title: 'Check what happens before it starts',
  body: 'body',
  question: 'What happens right before it shows up?',
  ctaLabel: 'Use this check',
  sourceProgressType: 'stillRepeating',
  sourceStatus: 'active',
);

void main() {
  test('less than 2 check-ins gives notEnoughYet / shouldShow false', () {
    final p = _engine.build(_memory(checkInCount: 1), null, null);
    expect(p.type, HabitProofType.notEnoughYet);
    expect(p.shouldShow, isFalse);
  });

  test('no memory gives notEnoughYet / shouldShow false', () {
    final p = _engine.build(null, null, null);
    expect(p.type, HabitProofType.notEnoughYet);
    expect(p.shouldShow, isFalse);
  });

  test('2 check-ins gives firstLoopClosed', () {
    final p = _engine.build(_memory(checkInCount: 2), null, null);
    expect(p.type, HabitProofType.firstLoopClosed);
    expect(p.shouldShow, isTrue);
    expect(p.headline, 'You closed the loop twice.');
    expect(p.proofLine, 'You have checked this pattern 2 times.');
  });

  test('2 check-ins carries next action question as nextLine', () {
    final p = _engine.build(_memory(checkInCount: 2), null, _action());
    expect(p.type, HabitProofType.firstLoopClosed);
    expect(p.nextLine, 'What happens right before it shows up?');
  });

  test('3 check-ins with no progress and no action gives memoryBuilding', () {
    final p = _engine.build(
      _memory(
        checkInCount: 3,
        nextBestQuestion: 'Did it show up before lunch?',
      ),
      null,
      null,
    );
    expect(p.type, HabitProofType.memoryBuilding);
    expect(p.headline, 'This pattern is building memory.');
    expect(p.proofLine, 'Checked 3 times.');
    expect(p.nextLine, 'Did it show up before lunch?');
  });

  test('progress shouldShow gives progressFound', () {
    final p = _engine.build(_memory(), _progress(), _action());
    expect(p.type, HabitProofType.progressFound);
    expect(p.headline, 'Now there is something to compare.');
    expect(p.proofLine, 'This pattern is still showing up.');
    expect(p.nextLine, 'What happens right before it shows up?');
  });

  test('hidden progress does not count as progressFound', () {
    final p = _engine.build(_memory(), _progress(shouldShow: false), _action());
    expect(p.type, HabitProofType.nextCheckReady);
  });

  test(
    'next action with 3+ check-ins gives nextCheckReady when no progress',
    () {
      final p = _engine.build(_memory(checkInCount: 3), null, _action());
      expect(p.type, HabitProofType.nextCheckReady);
      expect(p.headline, 'Tomorrow\u2019s check is clearer now.');
      expect(p.proofLine, 'Check what happens before it starts');
      expect(p.nextLine, 'What happens right before it shows up?');
    },
  );

  test('priority progressFound beats nextCheckReady', () {
    final p = _engine.build(_memory(), _progress(), _action());
    expect(p.type, HabitProofType.progressFound);
  });

  test('id encodes memory, count and type for de-duplication', () {
    final p = _engine.build(_memory(checkInCount: 4), _progress(), _action());
    expect(p.id, 'hp_pm1_4_progressFound');
  });
}
