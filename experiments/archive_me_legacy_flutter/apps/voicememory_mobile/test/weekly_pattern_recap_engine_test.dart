import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/weekly_pattern_recap_engine.dart';
import 'package:voicememory_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';

const _engine = WeeklyPatternRecapEngine();

PatternMemory _memory({
  int checkInCount = 4,
  int showedAgainCount = 0,
  int lighterCount = 0,
  int heavierCount = 0,
  int changedCount = 0,
  List<String> commonBeforeMoments = const [],
  List<String> helpedMoments = const [],
  List<String> harderMoments = const [],
  PatternMemoryStatus status = PatternMemoryStatus.active,
}) => PatternMemory(
  id: 'pm1',
  patternTitle: 'saying yes when you mean no',
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 4),
  checkInCount: checkInCount,
  showedAgainCount: showedAgainCount,
  lighterCount: lighterCount,
  heavierCount: heavierCount,
  changedCount: changedCount,
  commonBeforeMoments: commonBeforeMoments,
  helpedMoments: helpedMoments,
  harderMoments: harderMoments,
  status: status,
);

void main() {
  test('checkInCount < 4 gives notEnoughYet / shouldShow false', () {
    final r = _engine.build(_memory(checkInCount: 3), null, null);
    expect(r.type, WeeklyPatternRecapType.notEnoughYet);
    expect(r.shouldShow, isFalse);
  });

  test('showedAgain highest creates repeated', () {
    final r = _engine.build(
      _memory(checkInCount: 5, showedAgainCount: 4, lighterCount: 1),
      null,
      null,
    );
    expect(r.type, WeeklyPatternRecapType.repeated);
    expect(r.headline, 'This pattern kept showing up this week.');
    expect(r.body, 'You checked it 5 times and caught it more than once.');
    expect(r.nextQuestion, 'What happens right before it starts?');
    expect(r.shouldShow, isTrue);
  });

  test('lighterCount >= 2 creates lighter', () {
    final r = _engine.build(
      _memory(checkInCount: 4, lighterCount: 2, heavierCount: 1),
      null,
      null,
    );
    expect(r.type, WeeklyPatternRecapType.lighter);
    expect(r.headline, 'This pattern felt lighter this week.');
    expect(r.nextQuestion, 'What helped make it lighter?');
  });

  test('heavierCount >= 2 creates heavier', () {
    final r = _engine.build(
      _memory(checkInCount: 4, heavierCount: 2, lighterCount: 1),
      null,
      null,
    );
    expect(r.type, WeeklyPatternRecapType.heavier);
    expect(r.headline, 'This pattern felt heavier this week.');
    expect(r.nextQuestion, 'What made it heavier?');
  });

  test('changedCount >= 2 creates changing', () {
    final r = _engine.build(
      _memory(checkInCount: 4, changedCount: 2),
      null,
      null,
    );
    expect(r.type, WeeklyPatternRecapType.changing);
    expect(r.headline, 'This pattern changed this week.');
    expect(r.nextQuestion, 'What was different?');
    expect(r.usefulLine, isNull);
  });

  test('priority heavier over lighter', () {
    final r = _engine.build(
      _memory(checkInCount: 6, lighterCount: 3, heavierCount: 4),
      null,
      null,
    );
    expect(r.type, WeeklyPatternRecapType.heavier);
  });

  test('usefulLine appears for repeated before moments', () {
    final r = _engine.build(
      _memory(
        checkInCount: 4,
        showedAgainCount: 3,
        commonBeforeMoments: const ['before saying yes'],
      ),
      null,
      null,
    );
    expect(r.usefulLine, 'It often starts around: before saying yes');
  });

  test('usefulLine appears for lighter helped moments', () {
    final r = _engine.build(
      _memory(
        checkInCount: 4,
        lighterCount: 2,
        helpedMoments: const ['taking a walk'],
      ),
      null,
      null,
    );
    expect(r.usefulLine, 'What helped: taking a walk');
  });

  test('usefulLine appears for heavier harder moments', () {
    final r = _engine.build(
      _memory(
        checkInCount: 4,
        heavierCount: 2,
        harderMoments: const ['short on sleep'],
      ),
      null,
      null,
    );
    expect(r.usefulLine, 'What made it harder: short on sleep');
  });

  test('status changing forces changing recap', () {
    final r = _engine.build(
      _memory(checkInCount: 4, status: PatternMemoryStatus.changing),
      null,
      null,
    );
    expect(r.type, WeeklyPatternRecapType.changing);
  });

  test('week window and id derive from the reference date', () {
    final r = _engine.build(
      _memory(checkInCount: 4, showedAgainCount: 3),
      null,
      null,
      now: DateTime(2026, 6, 4),
    );
    // Monday of the week containing 2026-06-04 (Thursday) is 2026-06-01.
    expect(r.weekStart, DateTime(2026, 6, 1));
    expect(r.weekEnd, DateTime(2026, 6, 7));
    expect(r.id, 'wr_pm1_20260601_repeated');
  });
}
