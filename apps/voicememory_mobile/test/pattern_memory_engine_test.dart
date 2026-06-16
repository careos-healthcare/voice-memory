import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_engine.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_engine.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_model.dart';

const _engine = PatternMemoryEngine();
const _title = 'Taking responsibility before asking for help';

PatternMemoryUpdate _update(String hint, {String text = '', int day = 1}) =>
    PatternMemoryUpdate(
      checkInId: 'tci_$day',
      resultHint: hint,
      reflectionText: text,
      createdAt: DateTime(2026, 6, day),
    );

void main() {
  test('first update creates a forming memory', () {
    final memory = _engine.apply(
      null,
      _update(PatternMemoryResultHint.same),
      patternTitle: _title,
    );
    expect(memory.checkInCount, 1);
    expect(memory.showedAgainCount, 1);
    expect(memory.status, PatternMemoryStatus.forming);
    expect(memory.lastResult, PatternMemoryResultHint.same);
    expect(memory.patternTitle, _title);
    expect(memory.nextBestQuestion, 'Did this pattern show up again?');
  });

  test('same result increments showedAgainCount and becomes active', () {
    var memory = _engine.apply(
      null,
      _update(PatternMemoryResultHint.same, day: 1),
      patternTitle: _title,
    );
    memory = _engine.apply(
      memory,
      _update(PatternMemoryResultHint.same, day: 2),
      patternTitle: _title,
    );
    expect(memory.showedAgainCount, 2);
    expect(memory.checkInCount, 2);
    expect(memory.status, PatternMemoryStatus.active);
    expect(memory.nextBestQuestion, 'What happens right before it shows up?');
  });

  test('two lighter results set easing', () {
    var memory = _engine.apply(
      null,
      _update(PatternMemoryResultHint.lighter, day: 1),
      patternTitle: _title,
    );
    memory = _engine.apply(
      memory,
      _update(PatternMemoryResultHint.lighter, day: 2),
      patternTitle: _title,
    );
    expect(memory.lighterCount, 2);
    expect(memory.status, PatternMemoryStatus.easing);
    expect(memory.nextBestQuestion, 'What helped make it lighter?');
  });

  test('two heavier results set needsAttention', () {
    var memory = _engine.apply(
      null,
      _update(PatternMemoryResultHint.heavier, day: 1),
      patternTitle: _title,
    );
    memory = _engine.apply(
      memory,
      _update(PatternMemoryResultHint.heavier, day: 2),
      patternTitle: _title,
    );
    expect(memory.heavierCount, 2);
    expect(memory.status, PatternMemoryStatus.needsAttention);
    expect(memory.nextBestQuestion, 'What made it heavier?');
  });

  test('two changed results set changing', () {
    var memory = _engine.apply(
      null,
      _update(PatternMemoryResultHint.changed, day: 1),
      patternTitle: _title,
    );
    memory = _engine.apply(
      memory,
      _update(PatternMemoryResultHint.changed, day: 2),
      patternTitle: _title,
    );
    expect(memory.changedCount, 2);
    expect(memory.status, PatternMemoryStatus.changing);
    expect(memory.nextBestQuestion, 'What was different today?');
  });

  test('mixed results set changing', () {
    var memory = _engine.apply(
      null,
      _update(PatternMemoryResultHint.lighter, day: 1),
      patternTitle: _title,
    );
    memory = _engine.apply(
      memory,
      _update(PatternMemoryResultHint.changed, day: 2),
      patternTitle: _title,
    );
    expect(memory.status, PatternMemoryStatus.changing);
  });

  test('helped moments extracted only for lighter results', () {
    final lighter = _engine.apply(
      null,
      _update(
        PatternMemoryResultHint.lighter,
        text: 'I paused before answering and it eased.',
      ),
      patternTitle: _title,
    );
    expect(lighter.helpedMoments, isNotEmpty);

    final heavier = _engine.apply(
      null,
      _update(
        PatternMemoryResultHint.heavier,
        text: 'I paused before answering and it eased.',
      ),
      patternTitle: _title,
    );
    expect(heavier.helpedMoments, isEmpty);
  });

  test('harder moments extracted only for heavier results', () {
    final heavier = _engine.apply(
      null,
      _update(
        PatternMemoryResultHint.heavier,
        text: 'I carried it alone all day.',
      ),
      patternTitle: _title,
    );
    expect(heavier.harderMoments, isNotEmpty);

    final lighter = _engine.apply(
      null,
      _update(
        PatternMemoryResultHint.lighter,
        text: 'I carried it alone all day.',
      ),
      patternTitle: _title,
    );
    expect(lighter.harderMoments, isEmpty);
  });

  test('three lighter check-ins feed a gettingLighter progress moment', () {
    var memory = _engine.apply(
      null,
      _update(PatternMemoryResultHint.lighter, day: 1),
      patternTitle: _title,
    );
    memory = _engine.apply(
      memory,
      _update(PatternMemoryResultHint.lighter, day: 2),
      patternTitle: _title,
    );
    memory = _engine.apply(
      memory,
      _update(PatternMemoryResultHint.lighter, day: 3),
      patternTitle: _title,
    );

    final progress = const PatternProgressEngine().build(memory);
    expect(progress.shouldShow, isTrue);
    expect(progress.type, PatternProgressType.gettingLighter);
  });

  test('before moments captured from reflection text', () {
    final memory = _engine.apply(
      null,
      _update(
        PatternMemoryResultHint.same,
        text: 'It came up before saying yes to a favor.',
      ),
      patternTitle: _title,
    );
    expect(memory.commonBeforeMoments, isNotEmpty);
    expect(
      memory.commonBeforeMoments.first.toLowerCase(),
      contains('saying yes'),
    );
  });
}
