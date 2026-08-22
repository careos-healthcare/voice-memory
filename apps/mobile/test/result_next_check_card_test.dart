import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/record/record_stack_policy.dart';
import 'package:archiveme_mobile/features/routine/routine_anchor_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/widgets/record/result_next_check_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TomorrowCheckIn _completed(String optionId) => TomorrowCheckIn(
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

void main() {
  testWidgets('shows the next useful check with title, question and example', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed('showed_up_again'),
              onCreateCheckIn: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text(ConsumerUiCopy.resultNextCheckTitle), findsOneWidget);
    expect(find.text('Check what happens before it starts'), findsOneWidget);
    expect(find.text('What happens right before it shows up?'), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.resultNextCheckExampleLabel),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.resultNextCheckChooseDifferentCta),
      findsOneWidget,
    );
  });

  testWidgets('Use this tomorrow creates the check-in and confirms', (
    tester,
  ) async {
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed('lighter'),
              onCreateCheckIn: (question) async => created = question,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta));
    await tester.pump();

    expect(created, 'What helped make it lighter?');
    expect(
      find.text(ConsumerUiCopy.resultNextCheckConfirmation),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta),
      findsNothing,
    );
  });

  testWidgets('Use this tomorrow attaches a routine anchor when picked', (
    tester,
  ) async {
    RoutineAnchor? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed('lighter'),
              onCreateCheckIn: (_) async {},
              routineAnchorPicker: () async =>
                  const RoutineAnchor(type: RoutineAnchorType.evening),
              onRoutineAnchorChosen: (a) async => chosen = a,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta));
    await tester.pump();

    expect(chosen, isNotNull);
    expect(chosen!.type, RoutineAnchorType.evening);
    expect(
      find.text(ConsumerUiCopy.resultNextCheckConfirmation),
      findsOneWidget,
    );
  });

  testWidgets('skipping the anchor picker still locks the check', (
    tester,
  ) async {
    RoutineAnchor? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed('lighter'),
              onCreateCheckIn: (_) async {},
              routineAnchorPicker: () async => null,
              onRoutineAnchorChosen: (a) async => chosen = a,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta));
    await tester.pump();

    expect(chosen, isNull);
    expect(
      find.text(ConsumerUiCopy.resultNextCheckConfirmation),
      findsOneWidget,
    );
  });

  testWidgets('Choose a different check creates an alternate check-in', (
    tester,
  ) async {
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed('showed_up_again'),
              onCreateCheckIn: (question) async => created = question,
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.text(ConsumerUiCopy.resultNextCheckChooseDifferentCta),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(ConsumerUiCopy.resultNextCheckChooseSheetTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(ConsumerUiCopy.resultNextCheckAltHeavier));
    await tester.pumpAndSettle();

    expect(created, ConsumerUiCopy.resultNextCheckAltHeavier);
    expect(
      find.text(ConsumerUiCopy.resultNextCheckConfirmation),
      findsOneWidget,
    );
  });

  testWidgets('shows one feedback row by default and hides it when asked', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed('lighter'),
              onCreateCheckIn: (_) async {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Was this useful?'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed('lighter'),
              onCreateCheckIn: (_) async {},
              showFeedback: false,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Was this useful?'), findsNothing);
  });

  testWidgets('tooGeneric feedback hint surfaces a concrete next check', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed('lighter'),
              onCreateCheckIn: (_) async {},
              feedbackHint: ArchiveFeedbackType.tooGeneric,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Make the next check more concrete'), findsOneWidget);
    expect(find.text('What exact moment did this show up?'), findsOneWidget);
  });

  test(
    'result next check policy enables feedback and suppresses competitors',
    () {
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
      expect(d.showResultNextCheck, isTrue);
      expect(d.showFeedback, isTrue);
      expect(d.suppressDuplicateUseTomorrowCtas, isTrue);
    },
  );
}