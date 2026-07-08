import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/billing/restore_purchases_copy.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/app_review/archive_app_review_access_gate.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/first_session_lift/first_session_lift_analytics.dart';
import 'package:voicememory_mobile/features/first_session_lift/first_session_lift_copy.dart';
import 'package:voicememory_mobile/features/first_session_lift/first_session_lift_engine.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_analytics.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_copy.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_engine.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_model.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_store.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import 'package:voicememory_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/first_session_lift_card.dart';
import 'package:voicememory_mobile/widgets/pro/pro_understanding_lift_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(
          file: File(
            'test/tmp/first_session_pro_understanding_lift/unused.json',
          ),
        );

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

ProUnderstandingLiftVisibilityInput _proInput({
  bool isPro = false,
  bool hasUsefulProof = true,
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.useful,
  ProofQualityFeedbackState feedbackState = ProofQualityFeedbackState.useful,
  bool hasProEngagement = false,
  bool isRecording = false,
}) =>
    ProUnderstandingLiftVisibilityInput(
      surface: ProUnderstandingLiftSurface.recordReady,
      source: 'test',
      entryCount: 4,
      isPro: isPro,
      hasUsefulProof: hasUsefulProof,
      confidenceLevel: confidenceLevel,
      feedbackState: feedbackState,
      hasProEngagement: hasProEngagement,
      hasFreshReturnAfterCorrection: false,
      hasChangeAnchor: false,
      isRecording: isRecording,
      isDegradedTranscriptState: false,
      isPostSaveDegradedState: false,
      whatChangedQuestionActive: false,
      patternReviewInboxHasActiveItems: false,
    );

SurfacePriorityCandidates _recordCandidates({
  bool firstSessionLift = false,
  bool firstSaveLift = false,
  bool betaActivationPath = false,
  bool proUnderstandingLift = false,
  bool proVisibilityLift = false,
  bool proPreview = false,
  bool proBridgeVisibility = false,
}) =>
    SurfacePriorityCandidates.recordReady(
      firstSessionLift: firstSessionLift,
      firstSaveLift: firstSaveLift,
      betaActivationPath: betaActivationPath,
      threeMomentCompletion: false,
      firstMomentCapture: false,
      secondMomentReturn: false,
      lowFrictionReturn: false,
      whatToNoticeNext: false,
      betaTodaySummary: false,
      openCapturePromptChips: false,
      captureFreedomLine: false,
      timelineProofMoment: false,
      archiveTimelineSpine: false,
      timelinePositioning: false,
      currentRelevance: false,
      correctionMemory: false,
      notRelevantRecovery: false,
      proofQualityResponse: false,
      evidenceWeighting: false,
      proofSpecificity: false,
      presentDayRelevance: false,
      patternConfidence: false,
      betaTesterReport: false,
      proUnderstandingLift: proUnderstandingLift,
      proVisibilityLift: proVisibilityLift,
      proPreview: proPreview,
      proBridgeVisibility: proBridgeVisibility,
      proEvidenceValue: false,
      privateReportProBridge: false,
      suppressLegacyEducation: false,
    );

void main() {
  setUp(() async {
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    ArchiveAppReviewAccessGate.resetForTest();
    FirstSessionLiftAnalytics.resetForTest();
    ProUnderstandingLiftAnalytics.resetForTest();
    await ProUnderstandingLiftStore.resetForTest(_MemoryPrefs());
  });

  group('FirstSessionLiftCopy', () {
    test('uses first session capture copy', () {
      expect(FirstSessionLiftCopy.title, 'Start with one sentence');
      expect(FirstSessionLiftCopy.body, contains('Do not journal.'));
      expect(FirstSessionLiftCopy.primaryCta, 'Type one sentence');
      expect(FirstSessionLiftCopy.secondaryCta, 'Use voice instead');
      expect(
        FirstSessionLiftCopy.microcopy,
        'ArchiveMe only needs a real first moment. You can come back later if it repeats.',
      );
    });
  });

  group('FirstSessionLiftEngine', () {
    test('shows at zero entries when beta enabled', () {
      final result = FirstSessionLiftEngine.build(entryCount: 0, source: 'test');
      expect(
        FirstSessionLiftEngine.shouldShow(
          result: result,
          betaMissionEnabled: true,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          isPermissionBlocked: false,
          entryCount: 0,
        ),
        isTrue,
      );
    });

    test('hidden after first save', () {
      final result = FirstSessionLiftEngine.build(entryCount: 1, source: 'test');
      expect(result.shouldShow, isFalse);
    });

    test('hidden while recording', () {
      final result = FirstSessionLiftEngine.build(entryCount: 0, source: 'test');
      expect(
        FirstSessionLiftEngine.shouldShow(
          result: result,
          betaMissionEnabled: true,
          isReady: true,
          isRecording: true,
          isPostSave: false,
          isDegradedTranscriptState: false,
          isPermissionBlocked: false,
          entryCount: 0,
        ),
        isFalse,
      );
    });

    test('flags first session capture weak at 1/10', () {
      expect(
        FirstSessionLiftEngine.isFirstSessionCaptureWeak(
          firstSaveInFirstSession: 1,
          firstSessionOpportunities: 10,
        ),
        isTrue,
      );
    });
  });

  group('FirstSessionLiftCard', () {
    testWidgets('chip tap only pre-fills via handler', (tester) async {
      String? selectedPrompt;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstSessionLiftCard.test(
              result: FirstSessionLiftEngine.build(
                entryCount: 0,
                source: 'test',
              ),
              onTypeOneSentence: () {},
              onUseVoiceInstead: () {},
              onChipSelected: (prompt) => selectedPrompt = prompt,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('first_session_lift_chip_kept_checking_again')),
      );
      await tester.pump();
      expect(selectedPrompt, FirstSessionLiftCopy.exampleKeptCheckingAgain);
    });
  });

  group('ProUnderstandingLiftCopy', () {
    test('uses pro understanding lift copy', () {
      expect(ProUnderstandingLiftCopy.title, 'What Pro actually keeps');
      expect(
        ProUnderstandingLiftCopy.body,
        'Free shows the first proof. Pro keeps the timeline after that — what returns, what changes, what fades, and what you corrected.',
      );
      expect(ProUnderstandingLiftCopy.primaryCta, 'See the Pro timeline');
      expect(ProUnderstandingLiftCopy.secondaryCta, 'Not now');
      expect(ProUnderstandingLiftCopy.bullets, [
        'Free: the first useful proof',
        'Pro: the longer evidence trail',
        'You stay in control: delete or correct entries',
      ]);
      expect(
        ProUnderstandingLiftCopy.supportLine,
        'This is not more chat. It is the record behind the pattern.',
      );
    });
  });

  group('ProUnderstandingLiftEngine', () {
    test('shows after useful proof', () {
      expect(
        ProUnderstandingLiftEngine.shouldShowCard(input: _proInput()),
        isTrue,
      );
    });

    test('hidden without useful proof', () {
      expect(
        ProUnderstandingLiftEngine.shouldShowCard(
          input: _proInput(
            hasUsefulProof: false,
            confidenceLevel: ProofConfidenceLevel.watchOnly,
            feedbackState: ProofQualityFeedbackState.tooVague,
          ),
        ),
        isFalse,
      );
    });

    test('hidden for Pro users', () {
      expect(
        ProUnderstandingLiftEngine.shouldShowCard(input: _proInput(isPro: true)),
        isFalse,
      );
    });

    test('hidden after too vague or not relevant', () {
      expect(
        ProUnderstandingLiftEngine.shouldShowCard(
          input: _proInput(feedbackState: ProofQualityFeedbackState.tooVague),
        ),
        isFalse,
      );
      expect(
        ProUnderstandingLiftEngine.shouldShowCard(
          input: _proInput(
            feedbackState: ProofQualityFeedbackState.notRelevant,
          ),
        ),
        isFalse,
      );
    });

    test('flags pro understanding weak at 1/10', () {
      expect(
        ProUnderstandingLiftEngine.isProUnderstandingWeak(
          understandsProYesMaybe: 1,
          understandsProSurveyResponses: 10,
        ),
        isTrue,
      );
    });
  });

  group('ProUnderstandingLiftCard', () {
    testWidgets('renders without private journal text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProUnderstandingLiftCard.test(
              result: ProUnderstandingLiftEngine.build(input: _proInput()),
              onSeePro: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      for (final text in [
        ProUnderstandingLiftCopy.title,
        ProUnderstandingLiftCopy.body,
        ...ProUnderstandingLiftCopy.bullets,
        ProUnderstandingLiftCopy.supportLine,
        ProUnderstandingLiftCopy.primaryCta,
        ProUnderstandingLiftCopy.secondaryCta,
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.textContaining('transcript'), findsNothing);
    });
  });

  group('SurfacePriorityEngine', () {
    test('first session lift wins guidance slot at zero entries', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 0,
        source: 'test',
        candidates: _recordCandidates(
          firstSessionLift: true,
          firstSaveLift: true,
          betaActivationPath: true,
        ),
      );

      expect(result.guidanceSlot, SurfacePriorityCardKey.firstSessionLift);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.firstSaveLift,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.betaActivationPath,
          candidate: true,
        ),
        isFalse,
      );
      expect(result.hiddenReasons, contains(SurfacePriorityCopy.hiddenReasonGuidanceCap));
    });

    test('pro understanding lift wins single pro slot', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'test',
        candidates: _recordCandidates(
          proUnderstandingLift: true,
          proVisibilityLift: true,
          proPreview: true,
          proBridgeVisibility: true,
        ),
      );

      expect(result.proSlot, SurfacePriorityCardKey.proUnderstandingLift);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.proVisibilityLift,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.isVisible(SurfacePriorityCardKey.proPreview, candidate: true),
        isFalse,
      );
    });
  });

  group('Analytics', () {
    test('first session lift metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      FirstSessionLiftAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      final result =
          FirstSessionLiftEngine.build(entryCount: 0, source: 'record');
      FirstSessionLiftAnalytics.seen(result: result);
      FirstSessionLiftAnalytics.ctaTapped(
        result: result,
        actionType: FirstSessionLiftActionType.typeOneSentence,
      );
      FirstSessionLiftAnalytics.chipTapped(
        result: result,
        chipId: FirstSessionLiftChipId.keptCheckingAgain,
      );

      expect(events, [
        FirstSessionLiftAnalytics.seenEvent,
        FirstSessionLiftAnalytics.ctaTappedEvent,
        FirstSessionLiftAnalytics.chipTappedEvent,
      ]);
      for (final props in properties) {
        expect(props.keys, contains('source'));
        expect(props.containsKey('transcript'), isFalse);
        expect(props.containsKey('body'), isFalse);
      }
      expect(properties[1]['action_type'], 'type_one_sentence');
      expect(properties[2]['chip_id'], 'kept_checking_again');
    });

    test('pro understanding lift metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      ProUnderstandingLiftAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      final result = ProUnderstandingLiftEngine.build(input: _proInput());
      ProUnderstandingLiftAnalytics.seen(result: result);
      ProUnderstandingLiftAnalytics.ctaTapped(result: result);
      ProUnderstandingLiftAnalytics.dismissed(result: result);

      expect(events, [
        ProUnderstandingLiftAnalytics.seenEvent,
        ProUnderstandingLiftAnalytics.ctaTappedEvent,
        ProUnderstandingLiftAnalytics.dismissedEvent,
      ]);
      for (final props in properties) {
        expect(props.keys, containsAll([
          'source',
          'entry_count',
          'has_useful_proof',
          'has_paywall_seen',
        ]));
        expect(props.containsKey('transcript'), isFalse);
      }
    });
  });

  group('RevenueReadinessDashboardV2Engine', () {
    test('flags first session capture weak for 1/10 first-session saves', () {
      final dashboard = RevenueReadinessDashboardV2Engine.buildFromInput(
        RevenueReadinessDashboardV2Input(
          firstSaveInFirstSession: 1,
          firstSessionOpportunities: 10,
        ),
      );

      expect(
        dashboard.diagnoses.any(
          (diagnosis) =>
              diagnosis.id ==
              RevenueReadinessDashboardV2DiagnosisId.firstSessionCaptureWeak,
        ),
        isTrue,
      );
    });

    test('flags pro understanding weak for 1/10 understands Pro', () {
      final dashboard = RevenueReadinessDashboardV2Engine.buildFromInput(
        RevenueReadinessDashboardV2Input(
          understandsProYesMaybe: 1,
          understandsProSurveyResponses: 10,
        ),
      );

      expect(
        dashboard.diagnoses.any(
          (diagnosis) =>
              diagnosis.id ==
              RevenueReadinessDashboardV2DiagnosisId.proUnderstandingWeak,
        ),
        isTrue,
      );
    });
  });

  group('Integration wiring', () {
    test('record screen opens valueMoment paywall for pro understanding lift', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source, contains('FirstSessionLiftCard'));
      expect(source, contains('ProUnderstandingLiftCard'));
      expect(source, contains('record_pro_understanding_lift'));
      expect(source, contains('PaywallSource.valueMoment'));
    });

    test('testing screen renders compact previews', () {
      final source =
          File('lib/screens/testing_archiveme_screen.dart').readAsStringSync();
      expect(source, contains('FirstSessionLiftCard.test'));
      expect(source, contains('ProUnderstandingLiftCard.test'));
      expect(
        source,
        contains('_FirstSessionProUnderstandingLiftTestingPanel'),
      );
      expect(source, contains('first_session_lift_status'));
      expect(source, contains('pro_understanding_lift_status'));
      expect(source, contains('first_session_pro_understanding_lift_diagnosis'));
    });

    test('archive belief integrates pro understanding lift', () {
      final source =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      expect(source, contains('ProUnderstandingLiftCard'));
      expect(source, contains('patterns_pro_understanding_lift'));
    });
  });

  group('Protected billing areas', () {
    test('entitlement IDs unchanged', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('restore purchases unchanged', () {
      expect(RestorePurchasesCopy.restorePurchases, 'Restore purchases');
    });

    test('pro understanding lift opens valueMoment paywall via record screen', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source, contains('_openProEvidenceValueSubscription'));
      expect(source, contains('source: PaywallSource.valueMoment'));
    });
  });
}
