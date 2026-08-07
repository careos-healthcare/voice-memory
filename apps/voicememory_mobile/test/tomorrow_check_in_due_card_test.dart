import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/language/localized_copy.dart';
import 'package:voicememory_mobile/features/routine/routine_anchor_model.dart';
import 'package:voicememory_mobile/features/record/record_stack_policy.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/record/tomorrow_check_in_due_card.dart';

void main() {
  TomorrowCheckIn checkIn({String? selectedOptionId}) {
    return TomorrowCheckIn(
      id: 't1',
      createdAt: DateTime(2026, 5, 25),
      targetDate: '2026-05-26',
      patternTitle: 'Taking responsibility before asking for help',
      prompt: 'Tomorrow, check whether this pattern shows up again.',
      question: 'Did you ask for help, or carry it alone?',
      options: kDefaultTomorrowCheckInOptions,
      selectedOptionId: selectedOptionId,
    );
  }

  Future<void> pumpDueCard(WidgetTester tester, {String? selectedOptionId}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TomorrowCheckInDueCard(
              checkIn: checkIn(selectedOptionId: selectedOptionId),
              onRecord: () {},
              onSelectOption: (_) async {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the planned routine anchor when set', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TomorrowCheckInDueCard(
              checkIn: checkIn(),
              plannedAnchor: const RoutineAnchor(
                type: RoutineAnchorType.evening,
              ),
              onRecord: () {},
              onSelectOption: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Planned for: Evening'), findsOneWidget);
  });

  testWidgets('hides the planned line when no anchor is set', (tester) async {
    await pumpDueCard(tester);
    expect(find.textContaining('Planned for:'), findsNothing);
  });

  testWidgets('due card shows title and subtitle', (tester) async {
    await pumpDueCard(tester);

    expect(find.text('Your check-in from yesterday'), findsOneWidget);
    expect(
      find.text('You only need to answer what happened today.'),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.tomorrowCheckInDueTitle), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.tomorrowCheckInDueSubtitle),
      findsOneWidget,
    );
  });

  testWidgets('due card renders four answer options', (tester) async {
    await pumpDueCard(tester);

    expect(find.text('It showed up again'), findsOneWidget);
    expect(find.text('It felt lighter'), findsOneWidget);
    expect(find.text('It felt heavier'), findsOneWidget);
    expect(find.text('Not today'), findsOneWidget);
    expect(find.text('Today, what happened?'), findsOneWidget);
    expect(find.text('Yesterday you chose to check:'), findsOneWidget);
  });

  testWidgets('due card offers a None of these fit answer', (tester) async {
    await pumpDueCard(tester);

    expect(find.text('None of these fit'), findsOneWidget);
  });

  testWidgets('helper line hidden until option selected', (tester) async {
    await pumpDueCard(tester);

    expect(find.text('Short is fine. One sentence is enough.'), findsNothing);
  });

  testWidgets('examples expand and render all four examples', (tester) async {
    await pumpDueCard(tester);

    await tester.tap(find.text(ConsumerUiCopy.tomorrowCheckInNeedExamples));
    await tester.pump();

    expect(
      find.textContaining('I said yes before asking for help'),
      findsOneWidget,
    );
    expect(find.textContaining('paused before answering'), findsOneWidget);
    expect(find.textContaining('felt drained'), findsOneWidget);
    expect(find.textContaining('did not come up'), findsOneWidget);
  });

  Future<void> pumpGuided(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TomorrowCheckInDueCard(
              checkIn: checkIn(),
              guided: true,
              onRecord: () {},
              onSelectOption: (_) async {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('guided card initially hides four options', (tester) async {
    await pumpGuided(tester);

    expect(find.text(ConsumerUiCopy.guidedCheckInAnswerCta), findsOneWidget);
    expect(find.text('It showed up again'), findsNothing);
    expect(find.text('It felt lighter'), findsNothing);
    expect(find.text('It felt heavier'), findsNothing);
    expect(find.text('Not today'), findsNothing);
  });

  testWidgets('guided card reveals two primary answers after start', (
    tester,
  ) async {
    await pumpGuided(tester);

    await tester.tap(find.text(ConsumerUiCopy.guidedCheckInAnswerCta));
    await tester.pump();

    expect(find.text(ConsumerUiCopy.guidedCheckInPickClosest), findsOneWidget);
    expect(find.text('It showed up'), findsOneWidget);
    expect(find.text('It did not show up'), findsOneWidget);
    // lighter/heavier are secondary, hidden until revealed.
    expect(find.text('It felt lighter'), findsNothing);
    expect(find.text('It felt heavier'), findsNothing);

    await tester.tap(find.text(ConsumerUiCopy.guidedCheckInOtherAnswers));
    await tester.pump();
    expect(find.text('It felt lighter'), findsOneWidget);
    expect(find.text('It felt heavier'), findsOneWidget);
  });

  testWidgets('selecting lighter shows follow-up and CTA', (tester) async {
    await pumpDueCard(tester);

    await tester.tap(find.text('It felt lighter'));
    await tester.pump();

    expect(find.text('What made it lighter?'), findsOneWidget);
    expect(find.text('Record one moment'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.tomorrowCheckInRecordCta), findsOneWidget);
    expect(find.text('Short is fine. One sentence is enough.'), findsOneWidget);
    expect(
      find.textContaining('ArchiveMe can compare today with yesterday'),
      findsOneWidget,
    );
  });

  testWidgets('Spanish localizes labels, options and follow-up', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TomorrowCheckInDueCard(
              checkIn: checkIn(),
              languageCode: 'es',
              onRecord: () {},
              onSelectOption: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text(localized('todayHappened', 'es')), findsOneWidget);
    expect(find.text(localized('yesterdayChose', 'es')), findsOneWidget);
    expect(find.text(localized('option.lighter', 'es')), findsOneWidget);
    expect(find.text(localized('option.showedUp', 'es')), findsOneWidget);
    // English option labels must not leak through.
    expect(find.text('It felt lighter'), findsNothing);

    await tester.tap(find.text(localized('option.lighter', 'es')));
    await tester.pump();

    expect(
      find.text(localized('result.lighter.nextCheck', 'es')),
      findsOneWidget,
    );
    expect(find.text('What made it lighter?'), findsNothing);
  });

  test('due check policy wins over first-run cards', () {
    final d = decideRecordStack(
      hasDueCheck: true,
      isFirstRun: true,
      isTrialMode: false,
      isRecording: false,
      hasSavedReflection: false,
      inputQualityNeedsCoach: false,
      hasCompletedResult: false,
      hasResultNextCheck: false,
      hasRoutineAnchorOffer: false,
      hasArchiveProof: false,
    );
    expect(d.showDueCheckCard, isTrue);
    expect(d.showArchiveMemoryDemo, isFalse);
  });

  test('due check suppresses duplicate retention card', () {
    final d = decideRecordStack(
      hasDueCheck: true,
      isFirstRun: false,
      isTrialMode: false,
      isRecording: false,
      hasSavedReflection: false,
      inputQualityNeedsCoach: false,
      hasCompletedResult: false,
      hasResultNextCheck: false,
      hasRoutineAnchorOffer: false,
      hasArchiveProof: false,
      hasRetentionStateCard: true,
    );
    expect(d.showDueCheckCard, isTrue);
    expect(d.showRetentionStateCard, isFalse);
  });
}
