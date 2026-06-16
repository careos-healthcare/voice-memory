import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/features/feedback/archive_feedback_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/compelling_check_model.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/first_session_pattern_card.dart';
import 'package:voicememory_mobile/widgets/record/result_next_check_card.dart';
import 'package:voicememory_mobile/widgets/tomorrow_return/compelling_check_preview.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  testWidgets('compelling preview shows question, why, and example', (
    tester,
  ) async {
    const check = CompellingCheckQuestion(
      type: CompellingCheckType.beforeMoment,
      question: 'Did you say yes before checking what you needed?',
      whyThisCheck:
          'This is useful because it catches the moment before the pattern starts.',
      exampleAnswer: 'I noticed it before I said yes.',
      sharpnessLabel: CompellingCheckSharpness.direct,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompellingCheckPreview(check: check, trackShown: false),
        ),
      ),
    );

    expect(find.text(check.question), findsOneWidget);
    expect(find.text(check.whyThisCheck), findsOneWidget);
    expect(find.text(check.exampleAnswer), findsOneWidget);
    expect(find.text(CompellingCheckSharpness.direct), findsOneWidget);
  });

  testWidgets(
    'first-session card defaults to Most specific when feedback is moreSpecific',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstSessionPatternCard(
                pattern: ScreenshotSampleData.firstSessionPatternSample,
                feedbackHint: ArchiveFeedbackType.moreSpecific,
                onAccept:
                    (
                      _, {
                      correctionLearningId,
                      reflectionText,
                      sourceReflectionId,
                      selectedVariantId,
                      checkInQuestionOverride,
                    }) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('What exact moment did this show up?'), findsOneWidget);
      expect(find.text(CompellingCheckSharpness.mostSpecific), findsOneWidget);
    },
  );

  testWidgets('result card chooser updates preview when Direct is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: TomorrowCheckIn(
                id: 't1',
                createdAt: DateTime(2026, 5, 25),
                targetDate: '2026-05-26',
                patternTitle: 'Taking responsibility before saying yes',
                prompt: 'Tomorrow, check whether this pattern shows up again.',
                question: 'Did this pattern show up again?',
                options: kDefaultTomorrowCheckInOptions,
                selectedOptionId: 'showed_up_again',
                completedAt: DateTime(2026, 5, 26),
              ),
              onCreateCheckIn: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Direct'));
    await tester.pump();

    expect(
      find.text('Did you say yes before checking what you needed?'),
      findsOneWidget,
    );
  });

  testWidgets('result card use tomorrow passes selected question', (
    tester,
  ) async {
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: TomorrowCheckIn(
                id: 't1',
                createdAt: DateTime(2026, 5, 25),
                targetDate: '2026-05-26',
                patternTitle: 'Pattern',
                prompt: 'Tomorrow, check whether this pattern shows up again.',
                question: 'Did this pattern show up again?',
                options: kDefaultTomorrowCheckInOptions,
                selectedOptionId: 'lighter',
                completedAt: DateTime(2026, 5, 26),
              ),
              onCreateCheckIn: (question) async => created = question,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta));
    await tester.pump();

    expect(created, 'What helped make it lighter?');
  });

  test('compellingCheckAccepted increments activation events', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_compelling_metrics_journal_$stamp.json',
      prefsPath: '/tmp/vm_compelling_metrics_prefs_$stamp.json',
    );
    ActivationTracker.trackCompellingCheckAccepted();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final events = await ActivationEventsStore(
      AppServices.instance.prefs,
    ).read();
    expect(events.compellingCheckAccepted, 1);
  });
}
