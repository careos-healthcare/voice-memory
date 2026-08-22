import 'package:archiveme_mobile/features/prove_enough/loop_trigger_map_engine.dart';
import 'package:archiveme_mobile/features/prove_enough/loop_trigger_map_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/prove_enough/loop_trigger_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6),
    transcript: transcript,
    durationSeconds: 45,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

LoopTriggerMapRow? _rowFor(
  LoopTriggerMapModel model,
  LoopTriggerCategory category,
) {
  for (final row in model.rows) {
    if (row.category == category) return row;
  }
  return null;
}

void main() {
  const engine = LoopTriggerMapEngine();

  group('LoopTriggerMapEngine', () {
    test('detects unfinished work trigger', () {
      final model = engine.build([
        _entry(
          id: 'e1',
          transcript:
              'There is still unfinished work on my list and I feel behind on what is not done.',
        ),
        _entry(
          id: 'e2',
          transcript:
              'I kept working late because I still have unfinished tasks and a deadline tomorrow.',
        ),
      ]);

      final row = _rowFor(model, LoopTriggerCategory.unfinishedWork);
      expect(row, isNotNull);
      expect(row!.count, 2);
      expect(row.lastEvidencePhrase.toLowerCase(), contains('unfinished'));
    });

    test('detects comparison trigger', () {
      final model = engine.build([
        _entry(
          id: 'e1',
          transcript:
              'I compared myself to everyone else and felt like they are ahead of me on this project.',
        ),
        _entry(
          id: 'e2',
          transcript:
              'When I look at others finishing faster, I start doing more to catch up on my own work.',
        ),
      ]);

      final row = _rowFor(model, LoopTriggerCategory.comparison);
      expect(row, isNotNull);
      expect(row!.count, 2);
      expect(row.lastEvidencePhrase.toLowerCase(), contains('others'));
    });

    test('detects praise and expectations trigger', () {
      final model = engine.build([
        _entry(
          id: 'e1',
          transcript:
              'I wanted to prove I was capable because people expected me to look impressive and protect my reputation.',
        ),
        _entry(
          id: 'e2',
          transcript:
              'Someone said they were impressed and I felt pressure to keep proving I could handle more.',
        ),
      ]);

      final row = _rowFor(model, LoopTriggerCategory.praiseOrExpectations);
      expect(row, isNotNull);
      expect(row!.count, 2);
    });

    test('detects quiet or rest trigger', () {
      final model = engine.build([
        _entry(
          id: 'e1',
          transcript:
              'I tried to rest during a quiet break but kept thinking I should use the free time to work.',
        ),
        _entry(
          id: 'e2',
          transcript:
              'I stopped for a break and the quiet made it hard to stay still without opening my laptop again.',
        ),
      ]);

      final row = _rowFor(model, LoopTriggerCategory.quietOrRest);
      expect(row, isNotNull);
      expect(row!.count, 2);
    });

    test('detects feeling behind trigger', () {
      final model = engine.build([
        _entry(
          id: 'e1',
          transcript:
              'I feel behind and like it is not enough even though I should have done more yesterday.',
        ),
        _entry(
          id: 'e2',
          transcript:
              'I spent the evening catching up because I felt behind on what I owed myself to finish.',
        ),
      ]);

      final row = _rowFor(model, LoopTriggerCategory.feelingBehind);
      expect(row, isNotNull);
      expect(row!.count, 2);
    });

    test('counts across multiple entries', () {
      final model = engine.build([
        _entry(
          id: 'e1',
          transcript:
              'I kept going because I felt behind and there was still unfinished work on my plate.',
        ),
        _entry(
          id: 'e2',
          transcript:
              'I compared myself to everyone else and pushed harder because I felt not enough.',
        ),
        _entry(
          id: 'e3',
          transcript:
              'I tried to rest during quiet time but started working again when I thought about my deadline.',
        ),
      ]);

      expect(model.analyzedEntryCount, 3);
      expect(model.hasEnoughData, isTrue);
      expect(model.rankedRows, isNotEmpty);
      expect(
        model.rankedRows.fold<int>(0, (sum, row) => sum + row.count),
        greaterThanOrEqualTo(3),
      );
    });

    test('not-enough-data state with one entry', () {
      final model = engine.build([
        _entry(
          id: 'e1',
          transcript:
              'I kept going because I felt behind and there was still unfinished work on my plate.',
        ),
      ]);

      expect(model.analyzedEntryCount, 1);
      expect(model.hasEnoughData, isFalse);
    });

    test('not-enough-data state when triggers are unclear', () {
      final model = engine.build([
        _entry(
          id: 'e1',
          transcript: 'It was a normal day with nothing specific happening.',
        ),
        _entry(
          id: 'e2',
          transcript: 'I worked for a while and then went to bed.',
        ),
      ]);

      expect(model.analyzedEntryCount, 2);
      expect(model.hasEnoughData, isFalse);
      expect(_rowFor(model, LoopTriggerCategory.unclear)?.count, 2);
    });

    test('evidence phrases are not invented', () {
      const transcript =
          'I compared myself to everyone else and kept working because I felt behind.';
      final model = engine.build([
        _entry(id: 'e1', transcript: transcript),
        _entry(
          id: 'e2',
          transcript:
              'I compared myself to everyone else again when I saw others moving faster.',
        ),
      ]);

      for (final row in model.rankedRows) {
        expect(
          transcript.toLowerCase().contains(
                row.lastEvidencePhrase.toLowerCase(),
              ) ||
              row.lastEvidencePhrase.toLowerCase().contains('everyone else') ||
              row.lastEvidencePhrase.toLowerCase().contains('behind') ||
              row.lastEvidencePhrase.toLowerCase().contains('compared'),
          isTrue,
        );
      }
    });

    test('uses most recent evidence phrase for a trigger', () {
      final model = engine.build([
        _entry(
          id: 'e1',
          createdAt: DateTime(2026, 6),
          transcript:
              'I compared myself to everyone else and kept working late into the night.',
        ),
        _entry(
          id: 'e2',
          createdAt: DateTime(2026, 6, 3),
          transcript:
              'Today I compared myself to everyone else again after seeing their progress update.',
        ),
      ]);

      final row = _rowFor(model, LoopTriggerCategory.comparison);
      expect(row!.lastEvidencePhrase.toLowerCase(), contains('today'));
    });
  });

  group('LoopTriggerMapCard', () {
    testWidgets('renders not-enough-data copy safely', (tester) async {
      const model = LoopTriggerMapModel(
        rows: [],
        analyzedEntryCount: 1,
        hasEnoughData: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoopTriggerMapCard(model: model)),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(const Key('loop_trigger_map_card')), findsOneWidget);
      expect(find.text('Loop trigger map'), findsOneWidget);
      expect(find.text(LoopTriggerMapModel.notEnoughDataCopy), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('renders ranked rows when enough data', (tester) async {
      const model = LoopTriggerMapModel(
        rows: [
          LoopTriggerMapRow(
            category: LoopTriggerCategory.feelingBehind,
            count: 2,
            lastEvidencePhrase: 'I felt behind and not enough.',
          ),
          LoopTriggerMapRow(
            category: LoopTriggerCategory.unfinishedWork,
            count: 1,
            lastEvidencePhrase: 'Still unfinished work on my list.',
          ),
        ],
        analyzedEntryCount: 3,
        hasEnoughData: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoopTriggerMapCard(model: model)),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text(LoopTriggerMapModel.enoughDataHeadline), findsOneWidget);
      expect(find.text('Feeling behind'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('I felt behind and not enough.'), findsOneWidget);
    });
  });
}