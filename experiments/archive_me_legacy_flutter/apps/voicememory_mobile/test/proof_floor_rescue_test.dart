import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/first_session_proof_repair/first_session_proof_repair_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_analytics.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_copy.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_engine.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_model.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_copy.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_engine.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_model.dart';
import 'package:voicememory_mobile/features/pro_visibility_lift/pro_visibility_lift_engine.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import 'package:voicememory_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/proof/proof_floor_rescue_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/proof_floor_rescue/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

ProofFloorRescueInput _input({
  int entryCount = 4,
  bool hasTimelineProofVisible = true,
  bool hasConfirmedRepeat = true,
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.watchOnly,
  bool hasSafeAnchor = false,
  bool hasLowMatchQuality = true,
  int usefulFeedbackCount = 0,
  BetaProofFeedbackType? latestFeedbackType,
  bool feedbackAnsweredToday = false,
}) => ProofFloorRescueInput(
  entryCount: entryCount,
  source: 'test',
  isPro: false,
  hasTimelineProofVisible: hasTimelineProofVisible,
  hasConfirmedRepeat: hasConfirmedRepeat,
  confidenceLevel: confidenceLevel,
  hasSafeAnchor: hasSafeAnchor,
  hasLowMatchQuality: hasLowMatchQuality,
  usefulFeedbackCount: usefulFeedbackCount,
  latestFeedbackType: latestFeedbackType,
  feedbackAnsweredToday: feedbackAnsweredToday,
  isRecording: false,
  isDegradedTranscriptState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
);

SurfacePriorityCandidates _recordReadyCandidates({
  bool proofFloorRescue = false,
  bool proUnderstandingLift = false,
  bool proVisibilityLift = false,
  bool proPreview = false,
  bool proBridgeVisibility = false,
}) => SurfacePriorityCandidates.recordReady(
  proofFloorRescue: proofFloorRescue,
  threeMomentCompletion: false,
  firstMomentCapture: false,
  secondMomentReturn: false,
  lowFrictionReturn: false,
  whatToNoticeNext: false,
  betaTodaySummary: false,
  openCapturePromptChips: false,
  captureFreedomLine: false,
  timelineProofMoment: true,
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
    ProofFloorRescueAnalytics.resetForTest();
    await BetaProofFeedbackStore.resetForTest(_MemoryPrefs());
  });

  group('ProofFloorRescueCopy', () {
    test('uses exact rescue copy', () {
      expect(
        ProofFloorRescueCopy.waitTitle,
        'ArchiveMe is still watching this',
      );
      expect(
        ProofFloorRescueCopy.feedbackTitle,
        'Was this proof actually useful?',
      );
      expect(ProofFloorRescueCopy.sharpenTitle, 'Make the next proof sharper');
      expect(
        ProofFloorRescueCopy.suppressTitle,
        'ArchiveMe will back off this thread',
      );
      expect(ProofFloorRescueCopy.dashboardFocusTitle, 'Protect proof floor');
    });

    test('passes metadata-safe guard', () {
      for (final text in ProofFloorRescueCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('ProofFloorRescueEngine states', () {
    test('weak/watch_only proof shows waitForClearerEvidence', () {
      expect(
        ProofFloorRescueEngine.resolveState(_input()),
        ProofFloorRescueState.waitForClearerEvidence,
      );
    });

    test('no safe anchor shows waitForClearerEvidence', () {
      expect(
        ProofFloorRescueEngine.resolveState(
          _input(
            confidenceLevel: ProofConfidenceLevel.emerging,
            hasLowMatchQuality: false,
            hasSafeAnchor: false,
          ),
        ),
        ProofFloorRescueState.waitForClearerEvidence,
      );
    });

    test('strong proof with no feedback shows needsSpecificFeedback', () {
      expect(
        ProofFloorRescueEngine.resolveState(
          _input(
            confidenceLevel: ProofConfidenceLevel.useful,
            hasSafeAnchor: true,
            hasLowMatchQuality: false,
            usefulFeedbackCount: 1,
          ),
        ),
        ProofFloorRescueState.needsSpecificFeedback,
      );
    });

    test('Too vague feedback shows sharpenNextReturn', () {
      expect(
        ProofFloorRescueEngine.resolveState(
          _input(latestFeedbackType: BetaProofFeedbackType.tooVague),
        ),
        ProofFloorRescueState.sharpenNextReturn,
      );
    });

    test('Already knew feedback shows sharpenNextReturn', () {
      expect(
        ProofFloorRescueEngine.resolveState(
          _input(latestFeedbackType: BetaProofFeedbackType.alreadyKnew),
        ),
        ProofFloorRescueState.sharpenNextReturn,
      );
    });

    test('Not relevant feedback shows suppressThread', () {
      expect(
        ProofFloorRescueEngine.resolveState(
          _input(latestFeedbackType: BetaProofFeedbackType.notRelevant),
        ),
        ProofFloorRescueState.suppressThread,
      );
    });
  });

  group('ProofFloorRescueEngine pro blocking', () {
    test('weak/negative proof blocks ProUnderstandingLift path', () {
      final rescueInput = _input();
      expect(ProofFloorRescueEngine.blocksProMonetization(rescueInput), isTrue);
      expect(
        ProUnderstandingLiftEngine.shouldShowCard(
          input: ProUnderstandingLiftVisibilityInput(
            surface: ProUnderstandingLiftSurface.recordReady,
            source: 'test',
            entryCount: 4,
            isPro: false,
            hasUsefulProof: false,
            confidenceLevel: ProofConfidenceLevel.watchOnly,
            feedbackState: ProofQualityFeedbackState.none,
            hasProEngagement: false,
            hasFreshReturnAfterCorrection: false,
            hasChangeAnchor: false,
            isRecording: false,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive: false,
            patternReviewInboxHasActiveItems: false,
          ),
        ),
        isFalse,
      );
    });

    test('weak/negative proof blocks ProVisibilityLift path', () {
      expect(
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: 4,
          isPro: false,
          hasUsefulProof: false,
          confidenceLevel: ProofConfidenceLevel.watchOnly,
          feedbackState: ProofQualityFeedbackState.none,
          hasPaywallSeen: false,
          hasFreshReturnAfterCorrection: false,
          hasChangeAnchor: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test(
      'surface priority blocks pro cards when proof floor rescue active',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 4,
          source: 'test',
          candidates: _recordReadyCandidates(
            proofFloorRescue: true,
            proUnderstandingLift: true,
            proVisibilityLift: true,
            proPreview: true,
            proBridgeVisibility: true,
          ),
        );
        expect(result.proSlot, isNull);
        expect(
          result.isVisible(
            SurfacePriorityCardKey.proUnderstandingLift,
            candidate: true,
          ),
          isFalse,
        );
      },
    );

    test('strong useful proof still allows Pro path', () {
      final input = _input(
        confidenceLevel: ProofConfidenceLevel.strong,
        hasSafeAnchor: true,
        hasLowMatchQuality: false,
        usefulFeedbackCount: 2,
        latestFeedbackType: BetaProofFeedbackType.useful,
      );
      expect(ProofFloorRescueEngine.blocksProMonetization(input), isFalse);
      expect(ProofFloorRescueEngine.isProofSafeForMonetization(input), isTrue);
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'test',
        candidates: _recordReadyCandidates(
          proofFloorRescue: false,
          proUnderstandingLift: true,
        ),
      );
      expect(result.proSlot, SurfacePriorityCardKey.proUnderstandingLift);
    });
  });

  group('WhatChanged priority', () {
    test('WhatChanged still wins when confirmed repeat is active', () {
      final result = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: 4,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          firstProofPayoff: true,
          whatChanged: true,
          returnPayoff: false,
          timelineProofMomentPostSave: false,
          proofSpecificityPostSave: false,
          betaProofFeedback: true,
          proofFloorRescue: true,
          proUnderstandingLift: true,
          proVisibilityLift: true,
          proPreview: true,
          proBridgeVisibility: true,
          proEvidenceValue: true,
          proLockMoment: true,
          privateReportProBridge: true,
        ),
      );
      expect(
        result.isVisible(SurfacePriorityCardKey.whatChanged, candidate: true),
        isTrue,
      );
      expect(result.proSlot, isNull);
    });
  });

  group('Proof thresholds unchanged', () {
    test('reuses existing useful proof concern threshold', () {
      expect(
        ProofFloorRescueEngine.usefulProofConcernThreshold,
        FirstSessionProofRepairEngine.usefulProofConcernThreshold,
      );
      expect(ProofFloorRescueEngine.usefulProofConcernThreshold, 2);
    });
  });

  group('ProofFloorRescueAnalytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      ProofFloorRescueAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      final result = ProofFloorRescueEngine.build(input: _input());
      ProofFloorRescueAnalytics.seen(result: result);
      ProofFloorRescueAnalytics.ctaTapped(
        result: result,
        ctaType: ProofFloorRescueCtaType.notNow,
      );
      ProofFloorRescueAnalytics.feedbackAnswered(
        result: result,
        answerType: BetaProofFeedbackType.useful,
      );

      expect(events, [
        ProofFloorRescueAnalytics.seenEvent,
        ProofFloorRescueAnalytics.ctaTappedEvent,
        ProofFloorRescueAnalytics.feedbackAnsweredEvent,
      ]);
      for (final props in properties) {
        expect(props.keys, containsAll(['source', 'entry_count']));
        expect(props.containsKey('transcript'), isFalse);
        expect(props.containsKey('journal_text'), isFalse);
      }
    });
  });

  group('Dashboard repair focus', () {
    test('prioritizes protect_proof_floor when usefulProofCount < 2', () {
      final focus = ProofFloorRescueEngine.resolveRepairFocus(
        const RevenueReadinessDashboardV2Input(testerCount: 10, usefulCount: 1),
      );
      expect(focus?.focus, ProofFloorRescueRepairFocusId.protectProofFloor);
      expect(focus?.title, ProofFloorRescueCopy.dashboardFocusTitle);
      expect(focus?.body, ProofFloorRescueCopy.dashboardFocusBody);

      final dashboard = RevenueReadinessDashboardV2Engine.buildFromInput(
        const RevenueReadinessDashboardV2Input(testerCount: 10, usefulCount: 1),
      );
      expect(
        dashboard.proofFloorRescueFocus?.focus,
        ProofFloorRescueRepairFocusId.protectProofFloor,
      );
    });
  });

  group('ProofFloorRescueCard', () {
    testWidgets('renders wait state copy', (tester) async {
      final result = ProofFloorRescueEngine.build(input: _input());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProofFloorRescueCard.test(result: result)),
        ),
      );
      expect(find.text(ProofFloorRescueCopy.waitTitle), findsOneWidget);
      expect(find.text(ProofFloorRescueCopy.waitBody), findsOneWidget);
      expect(find.text(ProofFloorRescueCopy.waitPrimaryCta), findsOneWidget);
    });

    testWidgets('renders feedback options for needsSpecificFeedback', (
      tester,
    ) async {
      final result = ProofFloorRescueEngine.build(
        input: _input(
          confidenceLevel: ProofConfidenceLevel.useful,
          hasSafeAnchor: true,
          hasLowMatchQuality: false,
          usefulFeedbackCount: 1,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProofFloorRescueCard.test(result: result)),
        ),
      );
      expect(find.text(ProofFloorRescueCopy.feedbackTitle), findsOneWidget);
      expect(find.text('Yes'), findsWidgets);
      expect(find.text('Too vague'), findsOneWidget);
    });
  });

  group('Integration wiring', () {
    test('record screen integrates proof floor rescue', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source, contains('ProofFloorRescueCard'));
      expect(source, contains('SurfacePriorityCardKey.proofFloorRescue'));
      expect(source, contains('blocksProByProofFloorOnRecord'));
    });

    test('archive belief screen integrates proof floor rescue', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(source, contains('ProofFloorRescueCard'));
      expect(source, contains('blocksProByProofFloorOnPatterns'));
    });

    test('testing screen shows preview/status', () {
      final source = File(
        'lib/screens/testing_archiveme_screen.dart',
      ).readAsStringSync();
      expect(source, contains('_ProofFloorRescueTestingPanel'));
      expect(source, contains('proof_floor_rescue_state_status'));
      expect(source, contains('proof_floor_rescue_pro_block_status'));
      expect(source, contains('proof_floor_rescue_monetize_status'));
    });

    test('no fake evidence in rescue module', () {
      final engine = File(
        'lib/features/proof_floor_rescue/proof_floor_rescue_engine.dart',
      ).readAsStringSync();
      expect(engine.contains('seed'), isFalse);
      expect(engine.contains('fake'), isFalse);
    });
  });
}
