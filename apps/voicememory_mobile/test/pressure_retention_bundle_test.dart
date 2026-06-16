import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pressure_retention/archive_reflection_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_loop_visibility_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_weekly_recap_engine.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/ask_the_archive_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_loop_visibility_card.dart';

PressureCheckInRecord _record({
  required String id,
  required DateTime createdAt,
  String optionId = 'did_more_to_not_feel_behind',
  List<String> contextIds = const [],
  String? fear,
  bool choseToStop = false,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: createdAt,
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    choseToStop: choseToStop,
    transcript: 'I did more so I wouldn\'t feel behind.',
  );
}

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  final now = DateTime(2026, 6, 8, 12);

  group('Loop visibility (task 2)', () {
    const engine = PressureLoopVisibilityEngine();

    testWidgets('card renders empty state', (tester) async {
      final visibility = engine.build(const [], now: now);
      await _pumpCard(
        tester,
        PressureLoopVisibilityCard(visibility: visibility),
      );

      expect(
        find.byKey(const Key('pressure_loop_visibility_card')),
        findsOneWidget,
      );
      expect(find.text(PressureLoopVisibilityCard.emptyBody), findsOneWidget);
      expect(
        find.text(PressureLoopVisibilityCard.guiltFreeLine),
        findsOneWidget,
      );
    });

    testWidgets('card calculates weekly count', (tester) async {
      final records = [
        _record(id: 'a', createdAt: now.subtract(const Duration(days: 1))),
        _record(id: 'b', createdAt: now.subtract(const Duration(days: 2))),
        _record(id: 'c', createdAt: now.subtract(const Duration(days: 3))),
        // Outside the 7-day window — must not count.
        _record(id: 'old', createdAt: now.subtract(const Duration(days: 30))),
      ];
      final visibility = engine.build(records, now: now);
      expect(visibility.noticedThisWeek, 3);

      await _pumpCard(
        tester,
        PressureLoopVisibilityCard(visibility: visibility),
      );
      expect(
        find.textContaining('noticed pressure 3 times this week'),
        findsOneWidget,
      );
    });

    testWidgets('card calculates chose-to-stop count', (tester) async {
      final records = [
        _record(
          id: 'a',
          createdAt: now.subtract(const Duration(days: 1)),
          choseToStop: true,
        ),
        _record(id: 'b', createdAt: now.subtract(const Duration(days: 2))),
      ];
      final visibility = engine.build(records, now: now);
      expect(visibility.choseToStopCount, 1);

      await _pumpCard(
        tester,
        PressureLoopVisibilityCard(visibility: visibility),
      );
      expect(find.textContaining('chose to stop 1 time'), findsOneWidget);
    });

    testWidgets('copy avoids guilt/shame framing', (tester) async {
      final records = [
        _record(id: 'a', createdAt: now.subtract(const Duration(days: 1))),
        _record(id: 'b', createdAt: now.subtract(const Duration(days: 2))),
      ];
      final visibility = engine.build(records, now: now);
      await _pumpCard(
        tester,
        PressureLoopVisibilityCard(visibility: visibility),
      );

      expect(
        find.text(PressureLoopVisibilityCard.guiltFreeLine),
        findsOneWidget,
      );
      expect(find.textContaining('missed'), findsNothing);
      expect(find.textContaining('failed'), findsNothing);
      expect(find.textContaining('broke'), findsNothing);
      expect(find.textContaining('lazy'), findsNothing);
      expect(find.textContaining('behind on'), findsNothing);
    });

    test('streak counts consecutive days ending today', () {
      final records = [
        _record(id: 'today', createdAt: now),
        _record(id: 'yest', createdAt: now.subtract(const Duration(days: 1))),
        _record(id: 'd2', createdAt: now.subtract(const Duration(days: 2))),
        // Gap at day 3, so streak stops at 3.
        _record(id: 'old', createdAt: now.subtract(const Duration(days: 5))),
      ];
      final visibility = engine.build(records, now: now);
      expect(visibility.streakDays, 3);
    });
  });

  group('Ask the archive (task 4)', () {
    const engine = ArchiveReflectionEngine();

    testWidgets('question list renders', (tester) async {
      await _pumpCard(tester, const AskTheArchiveCard(records: []));

      for (final question in engine.questions()) {
        expect(find.text(question.prompt), findsOneWidget);
      }
    });

    testWidgets('insufficient evidence fallback appears', (tester) async {
      await _pumpCard(tester, const AskTheArchiveCard(records: []));

      await tester.tap(find.text('Where does this repeat?'));
      await tester.pump();

      expect(
        find.text(ArchiveReflectionEngine.insufficientEvidence),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ask_the_archive_answer')), findsOneWidget);
    });

    testWidgets('repeated pressure evidence produces a short answer', (
      tester,
    ) async {
      final records = [
        _record(id: 'a', createdAt: now, contextIds: const ['work']),
        _record(
          id: 'b',
          createdAt: now.subtract(const Duration(days: 1)),
          contextIds: const ['work'],
        ),
      ];
      await _pumpCard(tester, AskTheArchiveCard(records: records));

      await tester.tap(find.text('Where does this repeat?'));
      await tester.pump();

      final answer = engine.answer(
        ArchiveReflectionEngine.whereRepeatId,
        records,
      );
      expect(answer.hasEvidence, isTrue);
      expect(answer.text.toLowerCase(), contains('work'));
      expect(answer.text.length, lessThan(160));
      expect(find.textContaining('work'), findsWidgets);
    });

    test('answer does not overclaim whether a fear was disproven', () {
      final records = [
        _record(
          id: 'a',
          createdAt: now,
          fear: 'I would fall behind',
          choseToStop: true,
        ),
        _record(id: 'b', createdAt: now.subtract(const Duration(days: 1))),
        _record(id: 'c', createdAt: now.subtract(const Duration(days: 2))),
      ];

      final answer = engine.answer(
        ArchiveReflectionEngine.fearProvenWrongId,
        records,
      );

      expect(answer.text.toLowerCase(), contains('needs more evidence'));
      expect(answer.text.toLowerCase(), isNot(contains('proven wrong')));
      expect(answer.text.toLowerCase(), isNot(contains('was wrong')));
    });
  });

  group('Weekly recap (task 5)', () {
    const engine = PressureWeeklyRecapEngine();

    test('empty recap', () {
      final recap = engine.build(const [], now: now);
      expect(recap.hasData, isFalse);
      expect(recap.count, 0);
      expect(recap.sentence, PressureWeeklyRecapEngine.emptyCopy);
    });

    test('recap with one entry does not overclaim', () {
      final recap = engine.build([
        _record(id: 'a', createdAt: now, contextIds: const ['work']),
      ], now: now);
      expect(recap.hasData, isTrue);
      expect(recap.count, 1);
      expect(recap.sentence, contains('One pressure moment'));
      expect(recap.sentence.toLowerCase(), isNot(contains('showed up most')));
      expect(recap.sentence.toLowerCase(), isNot(contains('most around')));
    });

    test('recap with multiple entries surfaces the common context', () {
      final recap = engine.build([
        _record(id: 'a', createdAt: now, contextIds: const ['work']),
        _record(
          id: 'b',
          createdAt: now.subtract(const Duration(days: 1)),
          contextIds: const ['work'],
        ),
        _record(
          id: 'c',
          createdAt: now.subtract(const Duration(days: 2)),
          contextIds: const ['personal'],
        ),
      ], now: now);
      expect(recap.count, 3);
      expect(recap.mostCommonContextLabel, 'Work');
      expect(recap.sentence.toLowerCase(), contains('around work'));
    });

    test('chose-to-stop count is computed', () {
      final recap = engine.build([
        _record(id: 'a', createdAt: now, choseToStop: true),
        _record(
          id: 'b',
          createdAt: now.subtract(const Duration(days: 1)),
          choseToStop: true,
        ),
        _record(id: 'c', createdAt: now.subtract(const Duration(days: 2))),
      ], now: now);
      expect(recap.choseToStopCount, 2);
    });

    test('no overclaiming when data is weak', () {
      final recap = engine.build([_record(id: 'a', createdAt: now)], now: now);
      expect(recap.sentence.toLowerCase(), isNot(contains('most')));
    });
  });
}
