import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_engine.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _engine = PatternProgressEngine();

PatternMemory _memory({
  int checkInCount = 3,
  int showedAgainCount = 0,
  int lighterCount = 0,
  int heavierCount = 0,
  int changedCount = 0,
  PatternMemoryStatus status = PatternMemoryStatus.active,
  List<String> before = const [],
  List<String> helped = const [],
  List<String> harder = const [],
}) => PatternMemory(
  id: 'pm1',
  patternTitle: 'Taking responsibility before asking for help',
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6, 4),
  checkInCount: checkInCount,
  showedAgainCount: showedAgainCount,
  lighterCount: lighterCount,
  heavierCount: heavierCount,
  changedCount: changedCount,
  commonBeforeMoments: before,
  helpedMoments: helped,
  harderMoments: harder,
  status: status,
);

void main() {
  test(
    'fewer than three check-ins gives notEnoughYet and shouldShow false',
    () {
      final moment = _engine.build(_memory(checkInCount: 2, lighterCount: 2));
      expect(moment.type, PatternProgressType.notEnoughYet);
      expect(moment.shouldShow, isFalse);
    },
  );

  test('two lighter results create gettingLighter with helped line', () {
    final moment = _engine.build(
      _memory(
        lighterCount: 2,
        heavierCount: 1,
        helped: const ['paused before answering'],
      ),
    );
    expect(moment.type, PatternProgressType.gettingLighter);
    expect(moment.shouldShow, isTrue);
    expect(moment.headline, 'This pattern may be getting lighter.');
    expect(moment.body, contains('3 times'));
    expect(moment.helpedLine, 'What helped: paused before answering');
    expect(moment.nextLine, 'Next, watch what helps before it gets heavy.');
  });

  test('two heavier results create gettingHeavier with harder line', () {
    final moment = _engine.build(
      _memory(
        heavierCount: 2,
        harder: const ['carried it alone'],
      ),
    );
    expect(moment.type, PatternProgressType.gettingHeavier);
    expect(moment.headline, 'This pattern may be getting heavier.');
    expect(moment.beforeLine, 'What made it harder: carried it alone');
    expect(moment.nextLine, 'Next, watch what makes it heavier.');
  });

  test('showedAgain dominant creates stillRepeating with before line', () {
    final moment = _engine.build(
      _memory(
        checkInCount: 4,
        showedAgainCount: 2,
        lighterCount: 1,
        heavierCount: 1,
        before: const ['before saying yes'],
      ),
    );
    expect(moment.type, PatternProgressType.stillRepeating);
    expect(moment.headline, 'This pattern is still showing up.');
    expect(moment.body, contains('caught it 4 times'));
    expect(moment.beforeLine, 'It often starts around: before saying yes');
  });

  test('two changed results create changing', () {
    final moment = _engine.build(
      _memory(
        changedCount: 2,
        status: PatternMemoryStatus.changing,
      ),
    );
    expect(moment.type, PatternProgressType.changing);
    expect(moment.headline, 'This pattern is changing.');
    expect(moment.nextLine, 'Next, watch what was different.');
  });

  test('priority: heavier wins over lighter when heavier dominates', () {
    final moment = _engine.build(
      _memory(checkInCount: 5, heavierCount: 3, lighterCount: 2),
    );
    expect(moment.type, PatternProgressType.gettingHeavier);
  });

  test('shouldShow false when at threshold but no direction matched', () {
    final moment = _engine.build(
      _memory(
        showedAgainCount: 1,
        lighterCount: 1,
        heavierCount: 1,
      ),
    );
    expect(moment.type, PatternProgressType.notEnoughYet);
    expect(moment.shouldShow, isFalse);
  });

  test('uses cautious "may be" language for direction', () {
    final lighter = _engine.build(_memory(lighterCount: 2));
    final heavier = _engine.build(_memory(heavierCount: 2));
    expect(lighter.headline, contains('may be'));
    expect(heavier.headline, contains('may be'));
  });
}