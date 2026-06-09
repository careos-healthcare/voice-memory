import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_engine.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_model.dart';

const _engine = PatternNextActionEngine();

PatternMemory _memory({
  int checkInCount = 3,
  String? nextBestQuestion,
  PatternMemoryStatus status = PatternMemoryStatus.active,
}) =>
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
      status: status,
    );

PatternProgressMoment _progress(PatternProgressType type) => PatternProgressMoment(
      id: 'pp_pm1_3',
      memoryId: 'pm1',
      createdAt: DateTime(2026, 6, 4),
      type: type,
      headline: 'headline',
      body: 'body',
      nextLine: 'next',
      checkInCount: 3,
      shouldShow: true,
    );

void main() {
  test('stillRepeating creates repeatCheck', () {
    final a = _engine.build(_memory(), _progress(PatternProgressType.stillRepeating));
    expect(a.type, PatternNextActionType.repeatCheck);
    expect(a.title, 'Check what happens before it starts');
    expect(a.question, 'What happens right before it shows up?');
    expect(a.ctaLabel, 'Use this check');
    expect(a.sourceProgressType, 'stillRepeating');
    expect(a.sourceStatus, 'active');
  });

  test('gettingLighter creates lookForHelped', () {
    final a = _engine.build(_memory(), _progress(PatternProgressType.gettingLighter));
    expect(a.type, PatternNextActionType.lookForHelped);
    expect(a.title, 'Look for what helped');
    expect(a.question, 'What helped make it lighter?');
  });

  test('gettingHeavier creates lookForHeavier', () {
    final a = _engine.build(_memory(), _progress(PatternProgressType.gettingHeavier));
    expect(a.type, PatternNextActionType.lookForHeavier);
    expect(a.title, 'Look for what made it heavier');
    expect(a.question, 'What made it heavier?');
  });

  test('changing creates recordDifferentMoment', () {
    final a = _engine.build(_memory(), _progress(PatternProgressType.changing));
    expect(a.type, PatternNextActionType.recordDifferentMoment);
    expect(a.title, 'Notice what changed');
    expect(a.question, 'What was different today?');
  });

  test('no progress creates sharpenQuestion using next best question', () {
    final a = _engine.build(
      _memory(nextBestQuestion: 'Did it show up before lunch?'),
      null,
    );
    expect(a.type, PatternNextActionType.sharpenQuestion);
    expect(a.question, 'Did it show up before lunch?');
    expect(a.ctaLabel, "Choose tomorrow's check");
    expect(a.sourceProgressType, 'none');
  });

  test('notEnoughYet falls back to sharpenQuestion default question', () {
    final a = _engine.build(
      _memory(nextBestQuestion: null),
      _progress(PatternProgressType.notEnoughYet),
    );
    expect(a.type, PatternNextActionType.sharpenQuestion);
    expect(a.question, 'Did this pattern show up again?');
  });

  test('id encodes memory, count and type for de-duplication', () {
    final a = _engine.build(
      _memory(checkInCount: 5),
      _progress(PatternProgressType.stillRepeating),
    );
    expect(a.id, 'na_pm1_5_repeatCheck');
  });
}
