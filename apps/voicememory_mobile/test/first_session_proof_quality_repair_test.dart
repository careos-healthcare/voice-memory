import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/billing/restore_purchases_copy.dart';
import 'package:voicememory_mobile/features/app_review/archive_app_review_access_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/first_session_proof_repair/first_session_proof_repair_analytics.dart';
import 'package:voicememory_mobile/features/first_session_proof_repair/first_session_proof_repair_copy.dart';
import 'package:voicememory_mobile/features/first_session_proof_repair/first_session_proof_repair_engine.dart';
import 'package:voicememory_mobile/features/first_session_proof_repair/first_session_proof_repair_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import 'package:voicememory_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/first_session_proof_repair_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/first_session_proof_repair/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

ProofQualityRepairVisibilityInput _proofInput({
  int entryCount = 4,
  bool hasTimelineProofVisible = true,
  bool hasConfirmedRepeat = true,
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.watchOnly,
  int usefulFeedbackCount = 0,
  int negativeFeedbackCount = 0,
  bool betaProofFeedbackRowVisible = false,
  bool isRecording = false,
}) => ProofQualityRepairVisibilityInput(
  entryCount: entryCount,
  source: 'test',
  hasTimelineProofVisible: hasTimelineProofVisible,
  hasConfirmedRepeat: hasConfirmedRepeat,
  confidenceLevel: confidenceLevel,
  usefulFeedbackCount: usefulFeedbackCount,
  negativeFeedbackCount: negativeFeedbackCount,
  betaProofFeedbackRowVisible: betaProofFeedbackRowVisible,
  isRecording: isRecording,
  isDegradedTranscriptState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
);

SurfacePriorityCandidates _recordCandidates({
  bool firstSessionProofRepair = false,
  bool firstSessionLift = false,
  bool firstSaveLift = false,
  bool betaActivationPath = false,
}) => SurfacePriorityCandidates.recordReady(
  firstSessionProofRepair: firstSessionProofRepair,
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
  proofQualityRepair: false,
  evidenceWeighting: false,
  proofSpecificity: false,
  presentDayRelevance: false,
  patternConfidence: false,
  betaTesterReport: false,
  proEvidenceValue: false,
  privateReportProBridge: false,
  suppressLegacyEducation: false,
);

Future<void> _pumpCaptureCard(
  WidgetTester tester, {
  required VoidCallback onType,
  required VoidCallback onVoice,
  ValueChanged<String>? onChip,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FirstSessionCaptureRepairCard.test(
          result: FirstSessionProofRepairEngine.buildCapture(
            entryCount: 0,
            source: 'test',
          ),
          onTypeOneSentence: onType,
          onUseVoice: onVoice,
          onChipSelected: onChip ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    ArchiveAppReviewAccessGate.resetForTest();
    FirstSessionProofRepairAnalytics.resetForTest();
    await BetaProofFeedbackStore.resetForTest(_MemoryPrefs());
  });

  group('FirstSessionCaptureRepair', () {
    test('shows at 0 entries', () {
      final result = FirstSessionProofRepairEngine.buildCapture(
        entryCount: 0,
        source: 'test',
      );
      expect(
        FirstSessionProofRepairEngine.shouldShowCapture(
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
      final result = FirstSessionProofRepairEngine.buildCapture(
        entryCount: 1,
        source: 'test',
      );
      expect(result.shouldShow, isFalse);
    });

    test('hidden while recording', () {
      final result = FirstSessionProofRepairEngine.buildCapture(
        entryCount: 0,
        source: 'test',
      );
      expect(
        FirstSessionProofRepairEngine.shouldShowCapture(
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

    test('copy says Do not write a journal entry', () {
      expect(
        FirstSessionProofRepairCopy.captureBody,
        contains('Do not write a journal entry'),
      );
    });

    testWidgets('typed CTA opens typed capture path', (tester) async {
      var typed = false;
      await _pumpCaptureCard(
        tester,
        onType: () => typed = true,
        onVoice: () {},
      );
      await tester.tap(
        find.byKey(const Key('first_session_capture_repair_primary_cta')),
      );
      await tester.pump();
      expect(typed, isTrue);
    });

    testWidgets('chip tap does not create fake entry', (tester) async {
      String? prompt;
      await _pumpCaptureCard(
        tester,
        onType: () {},
        onVoice: () {},
        onChip: (value) => prompt = value,
      );
      await tester.tap(
        find.byKey(
          const Key('first_session_capture_repair_chip_kept_checking_again'),
        ),
      );
      await tester.pump();
      expect(prompt, isNotNull);
      expect(prompt, contains('One moment that felt familiar was'));
    });
  });

  group('SurfacePriorityEngine capture repair', () {
    test('wins guidance slot over first session lift and first save lift', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 0,
        source: 'test',
        candidates: _recordCandidates(
          firstSessionProofRepair: true,
          firstSessionLift: true,
          firstSaveLift: true,
          betaActivationPath: true,
        ),
      );

      expect(
        result.guidanceSlot,
        SurfacePriorityCardKey.firstSessionProofRepair,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.firstSessionLift,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.isVisible(SurfacePriorityCardKey.firstSaveLift, candidate: true),
        isFalse,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.betaActivationPath,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.hiddenReasons,
        contains(SurfacePriorityCopy.hiddenReasonGuidanceCap),
      );
    });
  });

  group('ProofQualityRepair', () {
    test('shows when useful proof count below threshold', () {
      expect(
        FirstSessionProofRepairEngine.shouldShowProof(
          input: _proofInput(usefulFeedbackCount: 1),
        ),
        isTrue,
      );
    });

    test('shows for watch_only confidence', () {
      expect(
        FirstSessionProofRepairEngine.shouldShowProof(
          input: _proofInput(confidenceLevel: ProofConfidenceLevel.watchOnly),
        ),
        isTrue,
      );
    });

    test('hidden when beta proof feedback row visible', () {
      expect(
        FirstSessionProofRepairEngine.shouldShowProof(
          input: _proofInput(betaProofFeedbackRowVisible: true),
        ),
        isFalse,
      );
    });

    test('hidden before 3 saves', () {
      expect(
        FirstSessionProofRepairEngine.shouldShowProof(
          input: _proofInput(entryCount: 2),
        ),
        isFalse,
      );
    });
  });

  group('ProofQualityRepairCard', () {
    testWidgets('useful answer produces useful next-step copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProofQualityRepairCard.test(
              result: FirstSessionProofRepairEngine.buildProof(
                input: _proofInput(),
              ),
              store: BetaProofFeedbackStore.forPrefs(_MemoryPrefs()),
              answered: true,
              answerType: BetaProofFeedbackType.useful,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(FirstSessionProofRepairCopy.proofNextStepUseful),
        findsOneWidget,
      );
    });

    testWidgets('too vague answer produces careful wait copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProofQualityRepairCard.test(
              result: FirstSessionProofRepairEngine.buildProof(
                input: _proofInput(),
              ),
              answered: true,
              answerType: BetaProofFeedbackType.tooVague,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(FirstSessionProofRepairCopy.proofNextStepTooVague),
        findsOneWidget,
      );
    });

    testWidgets('already knew answer produces changed-not-repeated copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProofQualityRepairCard.test(
              result: FirstSessionProofRepairEngine.buildProof(
                input: _proofInput(),
              ),
              answered: true,
              answerType: BetaProofFeedbackType.alreadyKnew,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(FirstSessionProofRepairCopy.proofNextStepAlreadyKnew),
        findsOneWidget,
      );
    });

    testWidgets('not relevant answer reduces thread copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProofQualityRepairCard.test(
              result: FirstSessionProofRepairEngine.buildProof(
                input: _proofInput(),
              ),
              answered: true,
              answerType: BetaProofFeedbackType.notRelevant,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(FirstSessionProofRepairCopy.proofNextStepNotRelevant),
        findsOneWidget,
      );
    });
  });

  group('Analytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      FirstSessionProofRepairAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      final capture = FirstSessionProofRepairEngine.buildCapture(
        entryCount: 0,
        source: 'record',
      );
      FirstSessionProofRepairAnalytics.captureSeen(result: capture);
      FirstSessionProofRepairAnalytics.captureCtaTapped(
        result: capture,
        actionType: FirstSessionProofRepairActionType.typeOneSentence,
      );

      final proof = FirstSessionProofRepairEngine.buildProof(
        input: _proofInput(),
      );
      FirstSessionProofRepairAnalytics.proofSeen(result: proof);
      FirstSessionProofRepairAnalytics.proofAnswered(
        result: proof,
        answerType: BetaProofFeedbackType.useful,
      );

      expect(events, [
        FirstSessionProofRepairAnalytics.captureSeenEvent,
        FirstSessionProofRepairAnalytics.captureCtaEvent,
        FirstSessionProofRepairAnalytics.proofSeenEvent,
        FirstSessionProofRepairAnalytics.proofAnsweredEvent,
      ]);
      for (final props in properties) {
        expect(props.keys, contains('source'));
        expect(props.containsKey('transcript'), isFalse);
      }
      expect(properties.last['answer_type'], 'useful');
    });
  });

  group('Dashboard repair focus', () {
    test('prioritizes useful proof if usefulProofCount < 2', () {
      final focus = FirstSessionProofRepairEngine.resolveRepairFocus(
        const RevenueReadinessDashboardV2Input(
          testerCount: 10,
          firstSessionSaveCount: 1,
          usefulCount: 1,
        ),
      );
      expect(focus.focus, FirstSessionProofRepairFocusId.usefulProofQuality);
      expect(focus.label, FirstSessionProofRepairCopy.focusUsefulProofQuality);
    });

    test('prioritizes first-session capture when useful proof is safe', () {
      final focus = FirstSessionProofRepairEngine.resolveRepairFocus(
        const RevenueReadinessDashboardV2Input(
          testerCount: 10,
          firstSessionSaveCount: 1,
          usefulCount: 3,
        ),
      );
      expect(focus.focus, FirstSessionProofRepairFocusId.firstSessionCapture);
      expect(focus.label, FirstSessionProofRepairCopy.focusFirstSessionCapture);
    });

    test('dashboard model exposes repair focus', () {
      final dashboard = RevenueReadinessDashboardV2Engine.buildFromInput(
        const RevenueReadinessDashboardV2Input(
          testerCount: 10,
          firstSessionSaveCount: 1,
          usefulCount: 1,
        ),
      );
      expect(
        dashboard.repairFocus.focus,
        FirstSessionProofRepairFocusId.usefulProofQuality,
      );
      expect(dashboard.decisionRule, isNotNull);
    });
  });

  group('Integration wiring', () {
    test('record screen integrates capture and proof repair cards', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source, contains('FirstSessionCaptureRepairCard'));
      expect(source, contains('ProofQualityRepairCard'));
      expect(
        source,
        contains('SurfacePriorityCardKey.firstSessionProofRepair'),
      );
      expect(source, contains('SurfacePriorityCardKey.proofQualityRepair'));
    });

    test('proof repair does not duplicate beta proof feedback row', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source, contains('showProofQualityRepairOnRecord'));
      expect(source, contains('betaProofFeedbackRowVisible'));
    });

    test('negative feedback path does not trigger Pro from repair card', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final start = source.indexOf('ProofQualityRepairCard');
      final end = source.indexOf('BetaProofFeedbackRow', start);
      final repairBlock = source.substring(start, end);
      expect(
        repairBlock.contains('_openProEvidenceValueSubscription'),
        isFalse,
      );
      expect(repairBlock.contains('ProUnderstandingLiftCard'), isFalse);
      expect(repairBlock.contains('ProVisibilityLiftCard'), isFalse);
    });

    test('testing screen renders previews', () {
      final source = File(
        'packages/archiveme_research/lib/screens/testing_archiveme_screen.dart',
      ).readAsStringSync();
      expect(source, contains('_FirstSessionProofRepairTestingPanel'));
      expect(source, contains('FirstSessionCaptureRepairCard.test'));
      expect(source, contains('ProofQualityRepairCard.test'));
      expect(source, contains('first_session_capture_repair_status'));
      expect(source, contains('proof_quality_repair_status'));
      expect(source, contains('first_session_proof_repair_next_fix'));
    });

    test('copy stays metadata-safe', () {
      for (final text in FirstSessionProofRepairCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });

    test('protected billing unchanged', () {
      expect(RestorePurchasesCopy.restorePurchases, 'Restore purchases');
      expect(PaywallSource.valueMoment.name, 'valueMoment');
    });
  });
}
