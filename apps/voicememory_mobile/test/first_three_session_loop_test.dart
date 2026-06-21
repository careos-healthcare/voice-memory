import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/first_three_journey_engine.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_copy.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_gates.dart';
import 'package:voicememory_mobile/features/activation/third_session_archive_usefulness_engine.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/activation/first_three_session_journey_indicator.dart';
import 'package:voicememory_mobile/widgets/activation/third_session_archive_usefulness_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/pro_archive_continuity_card.dart';
import 'package:voicememory_mobile/widgets/record/second_session_comparison_card.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  group('FirstThreeSessionCopy', () {
    test('session 1 lines match product loop', () {
      expect(RecordReturnProCopy.evidenceTitle, 'Your archive has started.');
      expect(
        RecordReturnProCopy.evidenceBody,
        contains('first piece of evidence'),
      );
      expect(
        RecordReturnProCopy.evidenceSecondLine,
        contains('No conclusion yet'),
      );
      expect(
        RecordReturnProCopy.evidenceThirdLine,
        contains('No conclusion yet'),
      );
    });

    test('journey labels follow session path', () {
      expect(FirstThreeSessionCopy.journeyLabelForCount(0), 'Start your archive');
      expect(
        FirstThreeSessionCopy.journeyLabelForCount(1),
        'Notice what repeats',
      );
      expect(
        FirstThreeSessionCopy.journeyLabelForCount(2),
        'Notice what repeats',
      );
      expect(
        FirstThreeSessionCopy.journeyLabelForCount(3),
        'Watch what changes',
      );
    });

    test('consumer copy avoids internal billing language', () {
      final haystack = [
        ...FirstThreeSessionCopy.session1Lines,
        ...FirstThreeSessionCopy.session3Lines,
        ...FirstThreeSessionCopy.proLines,
        ConsumerUiCopy.secondSessionPossibleRepeatTitle,
      ].join(' ').toLowerCase();

      for (final banned in FirstThreeSessionCopy.bannedInternalTerms) {
        expect(haystack, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('FirstThreeSessionGates', () {
    test('suppresses noisy cards on first save only', () {
      expect(
        FirstThreeSessionGates.suppressNoisyPostSaveCards(
          justSavedFirst: true,
          entryCount: 1,
        ),
        isTrue,
      );
      expect(
        FirstThreeSessionGates.suppressNoisyPostSaveCards(
          justSavedFirst: true,
          entryCount: 2,
        ),
        isFalse,
      );
    });

    test('Pro bridge waits until repeat value exists', () {
      expect(
        FirstThreeSessionGates.showSoftProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
        ),
        isFalse,
      );
      expect(
        FirstThreeSessionGates.showSoftProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
        ),
        isTrue,
      );
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
        ),
        isFalse,
      );
    });
  });

  group('Session 1 confirmation', () {
    testWidgets('first save evidence card shows focused copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () {},
              onRecordAnother: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Your archive has started.'), findsOneWidget);
      expect(
        find.textContaining('first piece of evidence'),
        findsOneWidget,
      );
      expect(find.textContaining('No conclusion yet'), findsOneWidget);
      expect(find.text('View archive'), findsOneWidget);
      expect(find.text('Record another'), findsOneWidget);
      expect(find.text('Your pressure loop'), findsNothing);
      expect(find.text('ArchiveMe found a possible repeat'), findsNothing);
    });
  });

  group('Session 2 possible repeat', () {
    test('second session engine surfaces possible repeat conservatively', () {
      final comparison = const SecondSessionSignalEngine().build([
        _entry(
          '1',
          'I said yes again even though I was already tired from work today.',
        ),
        _entry(
          '2',
          'I took responsibility again before asking anyone for help today.',
        ),
      ]);

      expect(comparison.hasEnoughData, isTrue);
      expect(
        comparison.title,
        'ArchiveMe found a possible repeat',
      );
      expect(comparison.possibleRepeat, isTrue);
    });

    testWidgets('comparison card shows repeat sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final comparison = const SecondSessionSignalEngine().build([
        _entry(
          '1',
          'I said yes again even though I was already tired from work today.',
        ),
        _entry(
          '2',
          'I took responsibility again before asking anyone for help today.',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecondSessionComparisonCard(
                comparison: comparison,
                onGoDeeper: () {},
                onRecordNextEvidence: () {},
                onNotTheSame: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ArchiveMe found a possible repeat'), findsOneWidget);
      expect(find.text('What repeated'), findsOneWidget);
      expect(find.text('What changed'), findsWidgets);
      expect(find.text('What to test next'), findsOneWidget);
    });
  });

  group('Session 3 archive usefulness', () {
    test('engine requires three entries', () {
      final two = const ThirdSessionArchiveUsefulnessEngine().build([
        _entry('1', 'First moment with enough words to count as evidence.'),
        _entry('2', 'Second moment with enough words to count as evidence.'),
      ]);
      expect(two.hasEnoughData, isFalse);

      final three = const ThirdSessionArchiveUsefulnessEngine().build([
        _entry('1', 'I said yes again even though I was already tired from work today.'),
        _entry('2', 'I took responsibility again before asking anyone for help today.'),
        _entry('3', 'I kept going again before checking whether I had room today.'),
      ]);
      expect(three.hasEnoughData, isTrue);
    });

    testWidgets('patterns card shows thread copy', (tester) async {
      final usefulness = const ThirdSessionArchiveUsefulnessEngine().build([
        _entry('1', 'I said yes again even though I was already tired from work today.'),
        _entry('2', 'I took responsibility again before asking anyone for help today.'),
        _entry('3', 'I kept going again before checking whether I had room today.'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThirdSessionArchiveUsefulnessCard(usefulness: usefulness),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Your archive is starting to show a thread.'),
        findsOneWidget,
      );
      expect(find.text("Here's what keeps coming back."), findsOneWidget);
      expect(find.text("Here's what changed since last time."), findsOneWidget);
    });
  });

  group('Journey indicator', () {
    testWidgets('highlights the active step label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FirstThreeSessionJourneyIndicator(activeStepIndex: 1),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Start your archive'), findsOneWidget);
      expect(find.text('Notice what repeats'), findsOneWidget);
      expect(find.text('Watch what changes'), findsOneWidget);
    });
  });

  group('Pro boundary', () {
    testWidgets('soft Pro card uses continuity copy after value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProArchiveContinuityCard(
              entryCount: 2,
              source: 'archive',
              onSeePro: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Keep your archive useful over time.'),
        findsOneWidget,
      );
      expect(find.text('See deeper history and saved evidence.'), findsOneWidget);
      expect(
        find.text(
          'Free keeps today\u2019s save. Pro keeps the thread connected over time.',
        ),
        findsOneWidget,
      );
      expect(find.text('Upgrade required'), findsNothing);
      expect(find.text('RevenueCat'), findsNothing);
    });
  });

  group('FirstThreeJourneyEngine alignment', () {
    const engine = FirstThreeJourneyEngine();

    test('zero entries uses Start your archive title', () {
      final model = engine.build(reflectionCount: 0);
      expect(model.title, FirstThreeSessionCopy.session0Title);
      expect(model.journeyStepIndex, 0);
    });

    test('one entry does not claim a confirmed loop', () {
      final model = engine.build(reflectionCount: 1);
      expect(model.title, FirstThreeSessionCopy.session1CardTitle);
      expect(model.nextAction, FirstThreeSessionCopy.session1NextAction);
      expect(model.title.toLowerCase(), isNot(contains('pattern is')));
      expect(model.progressLabel, FirstThreeSessionCopy.journeyStep2);
      expect(model.journeyStepIndex, 1);
    });

    test('two entries shows starting to notice, not possible repeat', () {
      final model = engine.build(reflectionCount: 2);
      expect(model.title, FirstThreeSessionCopy.session2StartingToNoticeTitle);
      expect(model.title, isNot(FirstThreeSessionCopy.session2RepeatTitle));
      expect(model.journeyStepIndex, 1);
      expect(model.progressLabel, FirstThreeSessionCopy.journeyStep2);
    });

    test('three entries uses useful-archive title without invented repeat', () {
      final model = engine.build(
        reflectionCount: 3,
        entries: [
          _entry('a', 'A quiet moment about lunch with a friend today.'),
          _entry('b', 'Another unrelated note about errands this afternoon.'),
          _entry('c', 'A third unrelated note about reading before bed.'),
        ],
      );
      expect(model.title, FirstThreeSessionCopy.session3Title);
      expect(model.completed, isTrue);
      expect(model.journeyStepIndex, 2);
    });
  });
}
