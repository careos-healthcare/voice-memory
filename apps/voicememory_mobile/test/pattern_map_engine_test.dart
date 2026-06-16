import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/features/pattern_map/pattern_map_engine.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';

PatternMemory _memory({
  int checkInCount = 4,
  int showedAgainCount = 2,
  int lighterCount = 1,
  int heavierCount = 1,
  int changedCount = 0,
  List<String> before = const ['before saying yes'],
  List<String> helped = const ['paused before answering'],
  List<String> harder = const ['took it on alone'],
  String? next = 'What happens right before it shows up?',
}) => PatternMemory(
  id: 'pm1',
  patternTitle: 'Taking responsibility before asking for help',
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 4),
  checkInCount: checkInCount,
  showedAgainCount: showedAgainCount,
  lighterCount: lighterCount,
  heavierCount: heavierCount,
  changedCount: changedCount,
  commonBeforeMoments: before,
  helpedMoments: helped,
  harderMoments: harder,
  nextBestQuestion: next,
);

void main() {
  test('maps core fields from pattern memory', () {
    final map = buildPatternMap(memory: _memory());
    expect(map.patternTitle, 'Taking responsibility before asking for help');
    expect(map.seenCount, 4);
    expect(map.lastSeenDate, DateTime(2026, 6, 4));
    expect(map.usuallyStartsBefore, 'before saying yes');
    expect(map.getsLighterWhen, 'paused before answering');
    expect(map.getsHeavierWhen, 'took it on alone');
    expect(map.nextCheck, 'What happens right before it shows up?');
  });

  test('oftenFeelsLike picks the dominant result', () {
    expect(
      buildPatternMap(memory: _memory(showedAgainCount: 5)).oftenFeelsLike,
      'the same',
    );
    expect(
      buildPatternMap(memory: _memory(heavierCount: 9)).oftenFeelsLike,
      'heavier',
    );
    expect(
      buildPatternMap(memory: _memory(lighterCount: 9)).oftenFeelsLike,
      'lighter',
    );
    expect(
      buildPatternMap(memory: _memory(changedCount: 9)).oftenFeelsLike,
      'different',
    );
  });

  test('oftenFeelsLike is null when there are no results yet', () {
    final map = buildPatternMap(
      memory: _memory(
        showedAgainCount: 0,
        lighterCount: 0,
        heavierCount: 0,
        changedCount: 0,
      ),
    );
    expect(map.oftenFeelsLike, isNull);
  });

  test('confidence is an early read below three check-ins', () {
    expect(
      buildPatternMap(memory: _memory(checkInCount: 1)).confidenceLabel,
      'Early read',
    );
    expect(
      buildPatternMap(memory: _memory(checkInCount: 2)).confidenceLabel,
      'Early read',
    );
    expect(
      buildPatternMap(memory: _memory(checkInCount: 3)).confidenceLabel,
      'Based on 3 check-ins',
    );
    expect(
      buildPatternMap(memory: _memory(checkInCount: 4)).confidenceLabel,
      'Based on 4 check-ins',
    );
  });

  test('next check falls back when no question is stored', () {
    final map = buildPatternMap(memory: _memory(next: null));
    expect(map.nextCheck, 'What happens right before it shows up?');
    expect(map.hasNextCheck, isTrue);
  });

  test('does not invent missing lines', () {
    final map = buildPatternMap(
      memory: _memory(before: const [], helped: const [], harder: const []),
    );
    expect(map.usuallyStartsBefore, isNull);
    expect(map.getsLighterWhen, isNull);
    expect(map.getsHeavierWhen, isNull);
  });

  test('fills gaps from related key moments when memory is sparse', () {
    final moments = [
      KeyMoment(
        id: 'm1',
        date: DateTime(2026, 6, 6),
        title: 'Something felt lighter',
        originalText: 'It felt lighter after I paused.',
        shortSummary: 'It felt lighter after I paused.',
        patternTitle: 'Taking responsibility before asking for help',
        resultHint: 'lighter',
        tags: const ['helped', 'lighter'],
      ),
    ];
    final map = buildPatternMap(
      memory: _memory(checkInCount: 0, helped: const []),
      moments: moments,
    );
    expect(map.seenCount, 1);
    expect(map.getsLighterWhen, 'It felt lighter after I paused.');
    expect(map.lastSeenDate, DateTime(2026, 6, 6));
  });
}
