import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/language/localized_copy.dart';
import 'package:voicememory_mobile/features/record/record_stack_policy.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_check_in_status_card.dart';
import 'package:voicememory_mobile/widgets/record/check_in_completed_card.dart';
import 'package:voicememory_mobile/widgets/trial/check_in_result_rating_prompt.dart';

void main() {
  TomorrowCheckIn completed(String optionId) {
    return TomorrowCheckIn(
      id: 't1',
      createdAt: DateTime(2026, 5, 25),
      targetDate: '2026-05-26',
      patternTitle: 'Pattern',
      prompt: 'Tomorrow, check whether this pattern shows up again.',
      question: 'Did this pattern show up again?',
      options: kDefaultTomorrowCheckInOptions,
      selectedOptionId: optionId,
      completedAt: DateTime(2026, 5, 26),
    );
  }

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('same result shows a repeat takeaway before rating', (
    tester,
  ) async {
    await pump(
      tester,
      CheckInCompletedCard(checkIn: completed('showed_up_again')),
    );

    expect(find.text('You closed the loop.'), findsOneWidget);
    expect(find.text('It showed up again.'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.usefulTakeawayTitle), findsOneWidget);
    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('Why this is useful'), findsOneWidget);
    expect(find.text('This was a repeat, not a one-off.'), findsOneWidget);
    expect(
      find.text('The same pattern showed up again today.'),
      findsOneWidget,
    );
    expect(
      find.text('Repeats are useful because they show where to look next.'),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.makeResultMoreUsefulCta), findsOneWidget);
  });

  testWidgets('lighter result shows a helped takeaway with next check', (
    tester,
  ) async {
    await pump(tester, CheckInCompletedCard(checkIn: completed('lighter')));

    expect(find.text('It felt lighter today.'), findsOneWidget);
    expect(find.text('Something made this lighter.'), findsOneWidget);
    expect(
      find.text('That is useful because it points to what helped.'),
      findsOneWidget,
    );
    expect(find.text('What helped make it lighter?'), findsOneWidget);
    expect(find.text('It felt lighter after I paused.'), findsOneWidget);
  });

  testWidgets('heavier result shows an attention takeaway', (tester) async {
    await pump(tester, CheckInCompletedCard(checkIn: completed('heavier')));

    expect(find.text('It felt heavier today.'), findsOneWidget);
    expect(find.text('Something made this heavier.'), findsOneWidget);
    expect(find.text('What made it heavier?'), findsOneWidget);
  });

  testWidgets('changed result shows a changed takeaway', (tester) async {
    await pump(tester, CheckInCompletedCard(checkIn: completed('not_today')));

    expect(find.text('Something changed today.'), findsOneWidget);
    expect(find.text('Today was different.'), findsOneWidget);
    expect(find.text('What was different today?'), findsOneWidget);
  });

  testWidgets('weak input shows an Early read with a concrete next check', (
    tester,
  ) async {
    await pump(
      tester,
      CheckInCompletedCard(checkIn: completed('lighter'), weakInput: true),
    );

    expect(
      find.text(ConsumerUiCopy.inputQualityEarlyReadLabel),
      findsOneWidget,
    );
    expect(
      find.textContaining('Add one clearer moment to make this more useful.'),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.resultEarlyReadNextCheck), findsOneWidget);
  });

  testWidgets('result card can show Spanish labels', (tester) async {
    await pump(
      tester,
      CheckInCompletedCard(checkIn: completed('lighter'), languageCode: 'es'),
    );

    expect(find.text(localized('usefulTakeaway', 'es')), findsOneWidget);
    expect(
      find.text(localized('result.lighter.headline', 'es')),
      findsOneWidget,
    );
    expect(find.text(localized('makeThisMoreUseful', 'es')), findsOneWidget);
    // The result headline and loop-closed title are localized too.
    expect(find.text(localized('feltLighter', 'es')), findsOneWidget);
    expect(find.text(localized('loopClosed', 'es')), findsOneWidget);
    // English takeaway copy must not leak through.
    expect(find.text('Something made this lighter.'), findsNothing);
    expect(find.text('It felt lighter today.'), findsNothing);
  });

  testWidgets('Show original reveals the preserved original text on tap', (
    tester,
  ) async {
    await pump(
      tester,
      CheckInCompletedCard(
        checkIn: completed('lighter'),
        languageCode: 'es',
        originalText: 'Hoy me sentí más ligero después de una pausa.',
      ),
    );

    // Hidden until requested; original is never shown by default.
    expect(
      find.text('Hoy me sentí más ligero después de una pausa.'),
      findsNothing,
    );

    await tester.tap(find.text(localized('showOriginal', 'es')));
    await tester.pump();

    expect(
      find.text('Hoy me sentí más ligero después de una pausa.'),
      findsOneWidget,
    );
    expect(find.text(localized('hideOriginal', 'es')), findsOneWidget);
  });

  testWidgets('no Show original toggle without original text', (tester) async {
    await pump(tester, CheckInCompletedCard(checkIn: completed('lighter')));
    expect(find.text(localized('showOriginal', 'en')), findsNothing);
  });

  testWidgets('useful takeaway appears above the usefulness rating', (
    tester,
  ) async {
    await pump(tester, CheckInCompletedCard(checkIn: completed('lighter')));

    final takeawayY = tester
        .getTopLeft(find.text(ConsumerUiCopy.usefulTakeawayTitle))
        .dy;
    final ratingY = tester
        .getTopLeft(find.text(ConsumerUiCopy.checkInResultUsefulPrompt))
        .dy;
    expect(takeawayY, lessThan(ratingY));
  });

  testWidgets(
    'Make this more useful opens the sheet and refines the takeaway',
    (tester) async {
      await pump(tester, CheckInCompletedCard(checkIn: completed('lighter')));

      expect(find.text('Something made this lighter.'), findsOneWidget);

      await tester.tap(find.text(ConsumerUiCopy.makeResultMoreUsefulCta));
      await tester.pumpAndSettle();
      expect(
        find.text(ConsumerUiCopy.makeResultMoreUsefulSheetTitle),
        findsOneWidget,
      );

      await tester.tap(
        find.text(ConsumerUiCopy.makeResultMoreUsefulMoreSpecific),
      );
      await tester.pumpAndSettle();

      // The takeaway is rebuilt as the concrete variant.
      expect(find.text('Make this more concrete.'), findsOneWidget);
      expect(find.text('What exact moment did this show up?'), findsOneWidget);
      expect(find.text('Something made this lighter.'), findsNothing);
    },
  );

  testWidgets('rating appears after the next-check slot', (tester) async {
    await pump(
      tester,
      CheckInCompletedCard(
        checkIn: completed('showed_up_again'),
        nextCheckSlot: const SizedBox(key: Key('next-check-slot'), height: 10),
      ),
    );

    expect(find.byKey(const Key('next-check-slot')), findsOneWidget);
    expect(find.text(ConsumerUiCopy.checkInResultUsefulPrompt), findsOneWidget);

    final slotY = tester
        .getTopLeft(find.byKey(const Key('next-check-slot')))
        .dy;
    final ratingY = tester
        .getTopLeft(find.text(ConsumerUiCopy.checkInResultUsefulPrompt))
        .dy;
    expect(slotY, lessThan(ratingY));
  });

  testWidgets('go deeper button shows for an obvious result and expands', (
    tester,
  ) async {
    await pump(
      tester,
      CheckInCompletedCard(checkIn: completed('showed_up_again')),
    );

    expect(find.text(ConsumerUiCopy.checkInGoDeeperCta), findsOneWidget);
    expect(find.text(ConsumerUiCopy.checkInGoDeeperTitle), findsNothing);

    await tester.tap(find.text(ConsumerUiCopy.checkInGoDeeperCta));
    await tester.pump();

    expect(find.text(ConsumerUiCopy.checkInGoDeeperTitle), findsOneWidget);
    expect(
      find.text('What happened right before it showed up?'),
      findsOneWidget,
    );
  });

  testWidgets('go deeper is hidden for a clear lighter result', (tester) async {
    await pump(tester, CheckInCompletedCard(checkIn: completed('lighter')));
    expect(find.text(ConsumerUiCopy.checkInGoDeeperCta), findsNothing);
  });

  testWidgets('none fit result shows its own headline', (tester) async {
    await pump(tester, CheckInCompletedCard(checkIn: completed('none_fit')));

    expect(find.text('None of those fit today.'), findsOneWidget);
    expect(find.text('Today was different.'), findsOneWidget);
  });

  testWidgets('patterns completed card shows a compact takeaway', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatternsCheckInStatusCard.closed(
            completed: completed('lighter'),
          ),
        ),
      ),
    );

    expect(find.text('Loop closed'), findsOneWidget);
    expect(find.text('Something made this lighter.'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.resultNextCheckTitle), findsOneWidget);
    expect(find.text('What helped make it lighter?'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.patternsResultUseCheckCta), findsOneWidget);
    expect(find.text('Record another moment'), findsOneWidget);
  });

  testWidgets('tapping Not really shows what was wrong and reason options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CheckInResultRatingPrompt(checkInId: 't1')),
      ),
    );

    await tester.tap(find.text('Not really'));
    await tester.pump();

    expect(
      find.text(ConsumerUiCopy.checkInResultNotUsefulFollowUp),
      findsOneWidget,
    );
    expect(find.text('Too vague'), findsOneWidget);
    expect(find.text('Not accurate'), findsOneWidget);
    expect(find.text('I already knew this'), findsOneWidget);
    expect(find.text('Confusing'), findsOneWidget);
  });

  testWidgets(
    'shows one feedback row at a time: rating then correction chips',
    (tester) async {
      await pump(tester, CheckInCompletedCard(checkIn: completed('lighter')));

      // Quick usefulness rating is the only feedback row first — no duplicate.
      expect(find.text('Was this useful?'), findsOneWidget);
      expect(find.text('Too generic'), findsNothing);

      await tester.ensureVisible(find.text('Sort of'));
      await tester.tap(find.text('Sort of'));
      await tester.pumpAndSettle();

      // Now the sharper correction chips replace the rating row.
      expect(find.text('Too generic'), findsOneWidget);
      expect(find.text('More specific'), findsOneWidget);

      await tester.ensureVisible(find.text('Too generic'));
      await tester.tap(find.text('Too generic'));
      await tester.pumpAndSettle();

      expect(find.text('Got it.'), findsOneWidget);
    },
  );

  test('post-save policy shows completed result before archive proof', () {
    final d = decideRecordStack(
      hasDueCheck: false,
      isFirstRun: false,
      isTrialMode: false,
      isRecording: false,
      hasSavedReflection: true,
      inputQualityNeedsCoach: false,
      hasCompletedResult: true,
      hasResultNextCheck: true,
      hasRoutineAnchorOffer: true,
      hasArchiveProof: true,
    );
    expect(d.showCompletedResult, isTrue);
    expect(d.showArchiveProofCards, isTrue);
    expect(d.showInputQualityCoach, isFalse);
  });
}
