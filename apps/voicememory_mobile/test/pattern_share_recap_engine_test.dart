import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_share_recap_engine.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_share_recap_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';

const _engine = PatternShareRecapEngine();

PatternMemory _memory({
  int checkInCount = 3,
  int showedAgainCount = 2,
  int lighterCount = 1,
  int heavierCount = 0,
  String? nextBestQuestion = 'Did it show up before lunch?',
}) =>
    PatternMemory(
      id: 'pm1',
      patternTitle: 'saying yes when you mean no',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 4),
      checkInCount: checkInCount,
      showedAgainCount: showedAgainCount,
      lighterCount: lighterCount,
      heavierCount: heavierCount,
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
      body: 'You have caught it 3 times.',
      beforeLine: 'It often starts before lunch.',
      helpedLine: 'A short walk helped.',
      nextLine: 'What happens right before it starts?',
      checkInCount: 3,
      shouldShow: shouldShow,
    );

WeeklyPatternRecap _weekly({bool shouldShow = true}) => WeeklyPatternRecap(
      id: 'wr_pm1_20260601_repeated',
      memoryId: 'pm1',
      createdAt: DateTime(2026, 6, 4),
      weekStart: DateTime(2026, 6, 1),
      weekEnd: DateTime(2026, 6, 7),
      type: WeeklyPatternRecapType.repeated,
      patternTitle: 'saying yes when you mean no',
      headline: 'This pattern kept showing up this week.',
      body: 'You checked it 4 times and caught it more than once.',
      usefulLine: 'It often starts around: before saying yes',
      nextQuestion: 'What happens right before it starts?',
      checkInCount: 4,
      shouldShow: shouldShow,
    );

void main() {
  test('weekly recap priority wins', () {
    final r = _engine.build(
      memory: _memory(),
      progress: _progress(),
      weekly: _weekly(),
    );
    expect(r.type, PatternShareRecapType.weekly);
    expect(r.title, 'This week\u2019s pattern');
    expect(r.body, 'This pattern kept showing up this week.');
    expect(r.nextQuestion, 'What happens right before it starts?');
    expect(r.lines, contains('It often starts around: before saying yes'));
  });

  test('progress priority wins over memory', () {
    final r = _engine.build(
      memory: _memory(),
      progress: _progress(),
      weekly: _weekly(shouldShow: false),
    );
    expect(r.type, PatternShareRecapType.progress);
    expect(r.title, 'Pattern progress');
    expect(r.lines, contains('Next check: What happens right before it starts?'));
  });

  test('memory recap works at checkInCount >= 2', () {
    final r = _engine.build(memory: _memory(checkInCount: 2));
    expect(r.type, PatternShareRecapType.memory);
    expect(r.body, 'You checked this pattern 2 times.');
    expect(r.lines, contains('Showed up again: 2'));
    expect(r.lines, contains('Next check: Did it show up before lunch?'));
  });

  test('fallback works', () {
    final r = _engine.build(memory: _memory(checkInCount: 1));
    expect(r.type, PatternShareRecapType.fallback);
    expect(r.title, 'My pattern');
    expect(r.lines, contains('Next check: Did this show up again?'));
  });

  test('fallback when nothing is provided', () {
    final r = _engine.build();
    expect(r.type, PatternShareRecapType.fallback);
  });

  test('plainText includes Made with ArchiveMe', () {
    final r = _engine.build(weekly: _weekly());
    expect(r.plainText, contains('Made with ArchiveMe'));
    expect(r.plainText, contains('This week\u2019s pattern'));
    expect(r.plainText, contains('- It often starts around: before saying yes'));
  });
}
