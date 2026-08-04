import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/impossible_insight/impossible_insight_engine.dart';
import 'package:voicememory_mobile/features/impossible_insight/impossible_insight_models.dart';
import 'package:voicememory_mobile/features/record/daily_mirror_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id, String transcript) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 7, int.parse(id)),
  transcript: transcript,
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

void main() {
  const engine = ImpossibleInsightEngine();

  test('ranks an exact recurring behavioral phrase first', () {
    final result = engine.build([
      _entry('1', 'Today I paused before answering the message, then replied.'),
      _entry(
        '2',
        'At lunch I paused before answering the message, then waited.',
      ),
    ]);

    expect(result?.kind, ImpossibleInsightKind.exactRecurringPhrase);
    expect(result?.value.evidence.map((e) => e.entryId).toSet(), {'1', '2'});
  });

  test('citations use exact UTF-16 offsets after emoji', () {
    final entries = [
      _entry(
        '1',
        '🧠 Today I paused before answering the message, then replied.',
      ),
      _entry(
        '2',
        '🙂 Again I paused before answering the message, then waited.',
      ),
    ];
    final result = engine.build(entries)!;

    for (final citation in result.value.evidence) {
      final transcript = entries
          .singleWhere((e) => e.id == citation.entryId)
          .transcript;
      expect(
        transcript.substring(citation.startUtf16, citation.endUtf16),
        citation.quote,
      );
    }
  });

  test('requires trigger action cost order for repeated sequence', () {
    final result = engine.build([
      _entry(
        '1',
        'When a request message arrived, I said yes immediately and later felt drained.',
      ),
      _entry(
        '2',
        'After another email request came in, I said yes quickly and felt exhausted.',
      ),
    ]);
    expect(result?.kind, ImpossibleInsightKind.repeatedTriggerActionCost);

    final wrongOrder = engine.build([
      _entry('1', 'I felt drained before the message arrived and I said yes.'),
      _entry('2', 'I was exhausted before the email arrived and I said yes.'),
    ]);
    expect(
      wrongOrder?.kind,
      isNot(ImpossibleInsightKind.repeatedTriggerActionCost),
    );
    expect(wrongOrder?.value.statement, isNot(contains('trigger came before')));
  });

  test('suppresses a one-entry micro-habit label', () {
    final result = engine.build([
      _entry(
        '1',
        'Whenever my manager asks for last-minute help, I say yes before checking my calendar.',
      ),
    ]);

    // The deterministic candidate calls this a "micro-habit" and a "trigger",
    // language the user did not use. The shared semantic gate correctly
    // suppresses that abstraction rather than presenting a one-entry pattern
    // as an established personal change.
    expect(result, isNull);
  });

  test('detects a concrete reversal across distinct entries', () {
    final result = engine.build([
      _entry('1', 'I wanted to rest and stop after lunch because I was tired.'),
      _entry('2', 'I kept working through dinner to finish another task.'),
    ]);

    expect(result?.kind, ImpossibleInsightKind.reversal);
    expect(result?.value.evidence.map((e) => e.entryId).toSet(), {'1', '2'});
  });

  test('requires three ordered observations for narrow correlation', () {
    final result = engine.build([
      _entry(
        '1',
        'When an urgent deadline appeared, I kept working through the afternoon.',
      ),
      _entry(
        '2',
        'After urgent pressure arrived, I keep on working without a break.',
      ),
      _entry(
        '3',
        'Whenever the deadline felt urgent, I kept on working past dinner.',
      ),
    ]);

    expect(result?.kind, ImpossibleInsightKind.narrowSequenceCorrelation);
    expect(result?.value.evidence, hasLength(3));
    expect(
      result?.value.uncertaintyNote.toLowerCase(),
      contains('not evidence'),
    );
  });

  test('does not produce output for unrelated or generic entries', () {
    expect(
      engine.build([
        _entry('1', 'I walked beside the river and watched a red boat pass.'),
        _entry('2', 'We cooked pasta with tomatoes for a family dinner.'),
        _entry('3', 'The book on astronomy explained a distant blue star.'),
      ]),
      isNull,
    );
    expect(engine.build([_entry('1', 'I feel stressed.')]), isNull);
    expect(engine.build([_entry('1', '[pending]')]), isNull);
  });

  test('Daily Mirror consumes the same validated first insight', () {
    final entries = [
      _entry('1', 'Today I paused before answering the message, then replied.'),
      _entry(
        '2',
        'At lunch I paused before answering the message, then waited.',
      ),
    ];
    final direct = engine.build(entries)!;
    final mirror = const DailyMirrorEngine().build(entries);

    expect(mirror.impossibleInsight?.value.id, direct.value.id);
    expect(mirror.heroBody, direct.value.statement);
  });
}
