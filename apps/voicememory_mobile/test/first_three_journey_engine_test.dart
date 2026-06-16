import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/first_three_journey_engine.dart';
import 'package:voicememory_mobile/features/activation/first_three_journey_model.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/activation/first_three_journey_card.dart';
import 'package:voicememory_mobile/widgets/activation/first_three_session_journey_indicator.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: 'You mentioned pressure in this moment.',
      repeatedSignal: '',
    ),
  );
}

List<JournalEntry> _repeatEntries() => [
  _entry(
    '1',
    'I said yes again even though I was already tired from work today.',
  ),
  _entry(
    '2',
    'I took responsibility again before asking anyone for help today.',
  ),
  _entry(
    '3',
    'I kept going again before checking whether I had room today.',
  ),
];

void main() {
  const engine = FirstThreeJourneyEngine();

  test('0 reflections returns clean first-run copy', () {
    final m = engine.build(reflectionCount: 0);
    expect(m.reflectionCount, 0);
    expect(m.currentStep, FirstThreeJourneyStep.one);
    expect(m.title, FirstThreeSessionCopy.session0Title);
    expect(m.progressLabel, FirstThreeSessionCopy.journeyStep1);
    expect(m.nextAction, 'Record one moment');
    expect(m.journeyStepIndex, 0);
    expect(m.completed, isFalse);
    expect(m.title, isNot(contains('possible repeat')));
  });

  test('1 reflection returns one-entry copy', () {
    final m = engine.build(reflectionCount: 1);
    expect(m.reflectionCount, 1);
    expect(m.currentStep, FirstThreeJourneyStep.two);
    expect(m.title, FirstThreeSessionCopy.session1CardTitle);
    expect(m.body, FirstThreeSessionCopy.session1CardBody);
    expect(m.progressLabel, FirstThreeSessionCopy.journeyStep2);
    expect(m.nextAction, FirstThreeSessionCopy.session1NextAction);
    expect(m.journeyStepIndex, 1);
    expect(m.completed, isFalse);
    expect(m.title, isNot(contains('possible repeat')));
  });

  test('2 reflections shows starting to notice, not possible repeat', () {
    final m = engine.build(reflectionCount: 2);
    expect(m.currentStep, FirstThreeJourneyStep.three);
    expect(m.title, FirstThreeSessionCopy.session2StartingToNoticeTitle);
    expect(m.body, FirstThreeSessionCopy.session2StartingToNoticeBody);
    expect(m.progressLabel, FirstThreeSessionCopy.journeyStep2);
    expect(m.nextAction, FirstThreeSessionCopy.session1NextAction);
    expect(m.journeyStepIndex, 1);
    expect(m.completed, isFalse);
    expect(m.title, isNot(contains('possible repeat')));
  });

  test('3 reflections without repeat match stays on useful-archive copy', () {
    final m = engine.build(
      reflectionCount: 3,
      entries: [
        _entry('a', 'First ordinary moment with enough words saved today.'),
        _entry('b', 'Second unrelated moment about cooking dinner tonight.'),
        _entry('c', 'Third unrelated moment about walking outside quietly.'),
      ],
    );
    expect(m.currentStep, FirstThreeJourneyStep.complete);
    expect(m.title, FirstThreeSessionCopy.session3Title);
    expect(m.title, isNot(ConsumerUiCopy.secondSessionPossibleRepeatTitle));
    expect(m.progressLabel, FirstThreeSessionCopy.journeyStep3);
    expect(m.nextAction, 'View archive');
    expect(m.completed, isTrue);
    expect(m.completedSteps, 3);
    expect(m.journeyStepIndex, 2);
  });

  test('3 reflections with repeat match shows possible repeat title', () {
    final m = engine.build(
      reflectionCount: 3,
      entries: _repeatEntries(),
    );
    expect(m.title, FirstThreeSessionCopy.session2RepeatTitle);
    expect(m.completed, isTrue);
    expect(m.journeyStepIndex, 2);
  });

  test('4+ reflections stays complete', () {
    final m = engine.build(reflectionCount: 9);
    expect(m.completed, isTrue);
    expect(m.reflectionCount, 9);
  });

  test('journey step index waits for three entries before watch-changes step', () {
    expect(engine.journeyStepIndexForCount(0), 0);
    expect(engine.journeyStepIndexForCount(1), 1);
    expect(engine.journeyStepIndexForCount(2), 1);
    expect(engine.journeyStepIndexForCount(3), 2);
  });

  group('FirstThreeJourneyCard states', () {
    Finder cardTitle(String title) {
      return find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == title &&
            (widget.style?.fontSize ?? 0) >= 18,
      );
    }

    Future<void> pumpCard(WidgetTester tester, FirstThreeJourneyModel model) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: FirstThreeJourneyCard(model: model)),
        ),
      );
      await tester.pump();
    }

    testWidgets('0 entries shows Start your archive', (tester) async {
      await pumpCard(tester, engine.build(reflectionCount: 0));
      expect(cardTitle(FirstThreeSessionCopy.session0Title), findsOneWidget);
      expect(find.text(FirstThreeSessionCopy.session2RepeatTitle), findsNothing);
    });

    testWidgets('1 entry shows one-moment copy', (tester) async {
      await pumpCard(tester, engine.build(reflectionCount: 1));
      expect(cardTitle(FirstThreeSessionCopy.session1CardTitle), findsOneWidget);
      expect(find.text(FirstThreeSessionCopy.session1NextAction), findsOneWidget);
      expect(find.text(FirstThreeSessionCopy.session2RepeatTitle), findsNothing);
    });

    testWidgets('2 entries shows starting to notice, not possible repeat', (
      tester,
    ) async {
      await pumpCard(tester, engine.build(reflectionCount: 2));
      expect(
        cardTitle(FirstThreeSessionCopy.session2StartingToNoticeTitle),
        findsOneWidget,
      );
      expect(find.text(FirstThreeSessionCopy.session2RepeatTitle), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FirstThreeSessionJourneyIndicator &&
              widget.activeStepIndex == 1,
        ),
        findsOneWidget,
      );
    });

    testWidgets('3 entries without match avoids possible repeat headline', (
      tester,
    ) async {
      await pumpCard(
        tester,
        engine.build(
          reflectionCount: 3,
          entries: [
            _entry('a', 'First ordinary moment with enough words saved today.'),
            _entry('b', 'Second unrelated moment about cooking dinner tonight.'),
            _entry('c', 'Third unrelated moment about walking outside quietly.'),
          ],
        ),
      );
      expect(cardTitle(FirstThreeSessionCopy.session3Title), findsOneWidget);
      expect(find.text(ConsumerUiCopy.secondSessionPossibleRepeatTitle), findsNothing);
    });
  });
}
