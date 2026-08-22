import 'package:archiveme_mobile/features/acquisition/acquisition_intent_model.dart';
import 'package:archiveme_mobile/features/acquisition/audience_wedge_model.dart';
import 'package:archiveme_mobile/features/acquisition/audience_wedge_store.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/post_save_insight_models.dart';
import 'package:archiveme_mobile/features/quality/first_insight_specificity_store.dart';
import 'package:archiveme_mobile/features/quality/interpretation_quality_signal_engine.dart';
import 'package:archiveme_mobile/features/quality/interpretation_quality_signal_model.dart';
import 'package:archiveme_mobile/features/quality/interpretation_quality_store.dart';
import 'package:archiveme_mobile/features/reminders/reminder_timing_engine.dart';
import 'package:archiveme_mobile/features/reminders/reminder_timing_model.dart';
import 'package:archiveme_mobile/features/reminders/reminder_timing_store.dart';
import 'package:archiveme_mobile/features/retention/reminder_pre_prompt_coordinator.dart';
import 'package:archiveme_mobile/features/retention/retention_diagnosis_v2_engine.dart';
import 'package:archiveme_mobile/features/retention/return_reason_capture_store.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/record/read_micro_feedback_row.dart';
import 'package:archiveme_research/screens/onboarding_intent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PostSaveInsightSignal _read({String title = 'Saying yes before checking'}) {
  return PostSaveInsightSignal(
    id: 'r1',
    readId: 'read1',
    title: title,
    explanation: 'You agreed quickly.',
    mightMean: 'Pressure to please.',
    wouldConfirm: 'Another yes while stretched.',
    wouldContradict: 'A pause before answering.',
    recordNextQuestion: 'When did you last pause?',
    categoryId: 'pressure',
    evidenceChips: const ['agreed', 'stretched'],
    strengthLabel: 'medium',
  );
}

PostSaveInsightBundle _bundle() {
  return PostSaveInsightBundle(
    signals: [_read()],
    sourcePattern: FirstSessionPattern(
      id: 'p1',
      createdAt: DateTime(2026),
      title: 'Pattern',
      whyNoticed: 'noticed',
      watchForText: 'watch',
      chips: const [],
      confidenceLabel: FirstSessionConfidenceLabel.early,
      sourceTextPreview: 'preview',
      matchReason: 'match',
      categoryId: 'pressure',
      confidenceScore: 50,
    ),
  );
}

RetentionDiagnosisV2Input _input({
  bool first = true,
  bool second = false,
  bool third = false,
  List<InterpretationQualitySignal> signals = const [],
  bool reminderAccepted = false,
  int reminderDismissed = 0,
  AcquisitionIntent? intent,
}) {
  return RetentionDiagnosisV2Input(
    firstMomentRecorded: first,
    secondMomentRecorded: second,
    thirdMomentRecorded: third,
    interpretationSignals: signals,
    reminderPrePromptShown: reminderDismissed > 0 || reminderAccepted,
    reminderPrePromptAccepted: reminderAccepted,
    reminderPrePromptDismissed: reminderDismissed,
    reminderReturnCount: 0,
    onboardingIntent: intent,
    journeyEvidenceCount: third ? 3 : (second ? 2 : 1),
    reviewConfirmed: false,
  );
}

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_diag_journal_$stamp.json',
    prefsPath: '/tmp/vm_diag_prefs_$stamp.json',
  );
}

void main() {
  group('interpretation quality engine', () {
    const engine = InterpretationQualitySignalEngine();

    test('accepted read = strong signal', () {
      final signal = engine.buildSignal(
        read: _read(),
        bundle: _bundle(),
        action: ReadUserAction.accepted,
      );
      expect(signal.qualityLabel, InterpretationQualityLabel.strong);
    });

    test('deeper opened = strong signal', () {
      final signal = engine.buildSignal(
        read: _read(),
        bundle: _bundle(),
        action: ReadUserAction.deeperOpened,
      );
      expect(signal.qualityLabel, InterpretationQualityLabel.strong);
    });

    test('rejected all = weak signal', () {
      final prior = [
        engine.buildSignal(
          read: _read(title: 'A'),
          bundle: _bundle(),
          action: ReadUserAction.rejected,
        ),
        engine.buildSignal(
          read: _read(title: 'B'),
          bundle: _bundle(),
          action: ReadUserAction.alternativeChosen,
        ),
      ];
      final label = engine.diagnoseQuality(
        action: ReadUserAction.rejected,
        sessionSignals: prior,
      );
      expect(label, InterpretationQualityLabel.weak);
    });

    test('ignored = unclear', () {
      final label = engine.diagnoseQuality(
        action: ReadUserAction.ignored,
        sessionSignals: const [],
      );
      expect(label, InterpretationQualityLabel.unclear);
    });
  });

  test('micro feedback row copy avoids banned terms', () {
    const banned = [
      'therapy',
      'coach',
      'diagnosis',
      'AI friend',
      'VoiceMemory',
    ];
    for (final s in [
      ConsumerUiCopy.readMicroFeedbackQuestion,
      ConsumerUiCopy.readMicroFeedbackUseful,
      ConsumerUiCopy.readMicroFeedbackNotQuite,
    ]) {
      for (final word in banned) {
        expect(s.toLowerCase(), isNot(contains(word.toLowerCase())));
      }
    }
  });

  testWidgets('micro feedback row renders question and buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadMicroFeedbackRow(onUseful: () {}, onNotQuite: () {}),
        ),
      ),
    );
    expect(find.text(ConsumerUiCopy.readMicroFeedbackQuestion), findsOneWidget);
    expect(find.text(ConsumerUiCopy.readMicroFeedbackUseful), findsOneWidget);
    expect(find.text(ConsumerUiCopy.readMicroFeedbackNotQuite), findsOneWidget);
  });

  group('reminder timing', () {
    test('notification copy safe without transcript', () {
      const engine = ReminderTimingEngine();
      final plan = engine.plan(
        journeyId: 'j1',
        variant: ReminderTimingVariant.tomorrowMorning,
        prompt:
            'Today I said yes to everything at work and felt completely drained after the meeting ended.',
      );
      expect(plan.body, contains('ArchiveMe is watching'));
      expect(plan.body, isNot(contains('felt drained after')));
      expect(plan.title, ConsumerUiCopy.nextEvidenceReminderTitle);
    });

    test('not now suppresses same session', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      expect(
        await ReminderPrePromptCoordinator.shouldShow(
          ReminderPrePromptTrigger.signalAccepted,
        ),
        isTrue,
      );
      await ReminderPrePromptCoordinator.markShown();
      expect(
        await ReminderPrePromptCoordinator.shouldShow(
          ReminderPrePromptTrigger.signalAccepted,
        ),
        isFalse,
      );
    });

    test('timing variant stored', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await ReminderTimingStore.instance().recordOffered([
        ReminderTimingVariant.tomorrowMorning,
      ]);
      await ReminderTimingStore.instance().recordSelected(
        ReminderTimingVariant.tomorrowEvening,
      );
      final offer = await ReminderTimingStore.instance().loadLatest();
      expect(offer?.selectedVariant, ReminderTimingVariant.tomorrowEvening);
    });
  });

  group('return reason capture', () {
    test('reminder return flag consumed once', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      final store = ReturnReasonCaptureStore.instance();
      await store.markPendingReminder();
      expect(await store.consumePending(), ReturnSourceKind.reminder);
      expect(await store.consumePending(), isNull);
    });

    test('second and third moment return tracked via coordinator', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await ReturnReasonCaptureStore.instance().recordReturn(
        source: ReturnSourceKind.manual,
        activeJourneyAtReturn: true,
        timeSinceLastMomentHours: 20,
        reflectionCountAfter: 2,
      );
      await ReturnReasonCaptureStore.instance().recordReturn(
        source: ReturnSourceKind.reminder,
        activeJourneyAtReturn: true,
        timeSinceLastMomentHours: 24,
        reflectionCountAfter: 3,
      );
      expect(
        await ReturnReasonCaptureStore.instance().reminderReturnCount(),
        1,
      );
    });

    test('no crash if source unknown', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await ReturnReasonCaptureStore.instance().recordReturn(
        source: ReturnSourceKind.unknown,
        activeJourneyAtReturn: false,
        timeSinceLastMomentHours: 0,
        reflectionCountAfter: 2,
      );
      expect(
        await ReturnReasonCaptureStore.instance().reminderReturnCount(),
        0,
      );
    });
  });

  group('acquisition intent', () {
    testWidgets('question appears and skip works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingIntentScreen()),
      );
      expect(
        find.text(ConsumerUiCopy.acquisitionIntentQuestion),
        findsOneWidget,
      );
      expect(
        find.text(AudienceWedge.sayingYesNoCapacity.label),
        findsOneWidget,
      );
      expect(find.text(ConsumerUiCopy.acquisitionIntentSkip), findsOneWidget);
    });

    test('wedge selection stored and adjusts first prompt', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await AudienceWedgeStore.instance().save(AudienceWedge.sayingYesCapacity);
      final prompt = await AudienceWedgeStore.instance().firstRecordingPrompt();
      expect(prompt, AudienceWedge.sayingYesCapacity.firstPrompt);
      expect(prompt, isNot(contains('I want freedom')));
    });
  });

  group('interpretation store', () {
    test('useful and not quite stored', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      await InterpretationQualityStore.recordMicroFeedback(
        readId: 'read1',
        useful: true,
      );
      await InterpretationQualityStore.recordMicroFeedback(
        readId: 'read2',
        useful: false,
      );
      expect(await InterpretationQualityStore.strongCount(), 0);
    });
  });

  group('retention diagnosis v2', () {
    const engine = RetentionDiagnosisV2Engine();

    test('weak interpretation bottleneck', () {
      final signal = InterpretationQualitySignal(
        readId: 'r1',
        readTitle: 't',
        specificityLevel: ReadSpecificityLevel.low,
        evidenceCount: 0,
        userAction: ReadUserAction.rejected,
        createdAt: DateTime(2026),
        source: ReadSourceKind.latestOnly,
        qualityLabel: InterpretationQualityLabel.weak,
      );
      final result = engine.diagnose(_input(signals: [signal]));
      expect(result.bottleneck, RetentionBottleneckV2.weakInterpretation);
    });

    test('reminder not accepted bottleneck', () {
      final result = engine.diagnose(
        _input(
          reminderDismissed: 1,
          signals: [
            InterpretationQualitySignal(
              readId: 'r1',
              readTitle: 't',
              specificityLevel: ReadSpecificityLevel.high,
              evidenceCount: 2,
              userAction: ReadUserAction.accepted,
              createdAt: DateTime(2026),
              source: ReadSourceKind.latestOnly,
              qualityLabel: InterpretationQualityLabel.strong,
            ),
          ],
        ),
      );
      expect(result.bottleneck, RetentionBottleneckV2.reminderNotAccepted);
    });

    test('reminder accepted no return', () {
      final result = engine.diagnose(
        _input(reminderAccepted: true),
      );
      expect(result.bottleneck, RetentionBottleneckV2.reminderAcceptedNoReturn);
    });

    test('no third moment', () {
      final result = engine.diagnose(_input(second: true));
      expect(result.bottleneck, RetentionBottleneckV2.noThirdMoment);
    });

    test('healthy early loop at review', () {
      final result = engine.diagnose(
        const RetentionDiagnosisV2Input(
          firstMomentRecorded: true,
          secondMomentRecorded: true,
          thirdMomentRecorded: true,
          interpretationSignals: [],
          reminderPrePromptShown: false,
          reminderPrePromptAccepted: false,
          reminderPrePromptDismissed: 0,
          reminderReturnCount: 0,
          onboardingIntent: null,
          journeyEvidenceCount: 3,
          reviewConfirmed: true,
        ),
      );
      expect(result.bottleneck, RetentionBottleneckV2.healthyEarlyLoop);
    });

    test('acquisition mismatch without first moment', () {
      final result = engine.diagnose(
        _input(first: false, intent: AcquisitionIntent.workPressure),
      );
      expect(result.bottleneck, RetentionBottleneckV2.acquisitionMismatch);
    });

    test('audience not activated when wedge selected without record', () {
      final result = engine.diagnose(
        const RetentionDiagnosisV2Input(
          firstMomentRecorded: false,
          secondMomentRecorded: false,
          thirdMomentRecorded: false,
          interpretationSignals: [],
          reminderPrePromptShown: false,
          reminderPrePromptAccepted: false,
          reminderPrePromptDismissed: 0,
          reminderReturnCount: 0,
          onboardingIntent: null,
          journeyEvidenceCount: 0,
          reviewConfirmed: false,
          audienceWedge: AudienceWedge.proveEnough,
        ),
      );
      expect(result.bottleneck, RetentionBottleneckV2.audienceNotActivated);
    });

    test('insight too generic bottleneck', () {
      final result = engine.diagnose(
        const RetentionDiagnosisV2Input(
          firstMomentRecorded: true,
          secondMomentRecorded: false,
          thirdMomentRecorded: false,
          interpretationSignals: [],
          reminderPrePromptShown: false,
          reminderPrePromptAccepted: false,
          reminderPrePromptDismissed: 0,
          reminderReturnCount: 0,
          onboardingIntent: null,
          journeyEvidenceCount: 1,
          reviewConfirmed: false,
          firstInsightSpecificityRating:
              FirstInsightSpecificityRating.tooGeneric,
        ),
      );
      expect(result.bottleneck, RetentionBottleneckV2.insightTooGeneric);
    });
  });
}