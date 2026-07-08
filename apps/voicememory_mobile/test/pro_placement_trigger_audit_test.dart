import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/pro_placement_trigger_audit/pro_placement_trigger_audit_copy.dart';
import 'package:voicememory_mobile/features/pro_placement_trigger_audit/pro_placement_trigger_audit_engine.dart';
import 'package:voicememory_mobile/features/pro_placement_trigger_audit/pro_placement_trigger_audit_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/pro_visibility_lift/pro_visibility_lift_engine.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/pro_placement_trigger_audit_card.dart';

ProPlacementTriggerAuditInput _input({
  bool betaMissionEnabled = true,
  BetaRepairLabMode activeRepairMode =
      BetaRepairLabMode.proPlacementAfterUsefulProof,
  int entryCount = 4,
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.strong,
  bool hasSafeAnchor = true,
  bool hasMatchQuality = true,
  bool hasConfirmedRepeat = true,
  bool hasTimelineProofVisible = true,
  BetaProofFeedbackType? feedbackType = BetaProofFeedbackType.useful,
  bool? hasUsefulOrStrongProof,
  bool proPlacementEligible = true,
  bool proPlacementShown = true,
  bool proPlacementBlocked = false,
  bool hasProEngagement = false,
}) =>
    ProPlacementTriggerAuditInput(
      betaMissionEnabled: betaMissionEnabled,
      activeRepairMode: activeRepairMode,
      entryCount: entryCount,
      confidenceLevel: confidenceLevel,
      hasSafeAnchor: hasSafeAnchor,
      hasMatchQuality: hasMatchQuality,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasTimelineProofVisible: hasTimelineProofVisible,
      feedbackType: feedbackType,
      hasUsefulOrStrongProof: hasUsefulOrStrongProof ??
          ProPlacementTriggerAuditEngine.hasUsefulOrStrongProof(
            feedbackType: feedbackType,
            confidenceLevel: confidenceLevel,
          ),
      proPlacementEligible: proPlacementEligible,
      proPlacementShown: proPlacementShown,
      proPlacementBlocked: proPlacementBlocked,
      hasProEngagement: hasProEngagement,
      source: 'test',
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  ProPlacementTriggerAuditInput? input,
}) async {
  ArchiveBetaMissionGate.enabledOverride = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProPlacementTriggerAuditCard(
            inputOverride: input,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    ArchiveBetaMissionGate.enabledOverride = true;
    ProPlacementTriggerAuditEngine.resetForTest();
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    ProPlacementTriggerAuditEngine.resetForTest();
  });

  group('ProPlacementTriggerAuditEngine', () {
    test('inactive when beta mission off', () {
      expect(
        ProPlacementTriggerAuditEngine.resolveOutcome(
          _input(betaMissionEnabled: false),
        ),
        ProPlacementTriggerAuditOutcome.inactive,
      );
    });

    test('inactive when repair mode is not proPlacementAfterUsefulProof', () {
      expect(
        ProPlacementTriggerAuditEngine.resolveOutcome(
          _input(activeRepairMode: BetaRepairLabMode.proExplanation),
        ),
        ProPlacementTriggerAuditOutcome.inactive,
      );
    });

    test('eligibleAndShown when useful/strong proof exists and no block reason',
        () {
      expect(
        ProPlacementTriggerAuditEngine.resolveOutcome(_input()),
        ProPlacementTriggerAuditOutcome.eligibleAndShown,
      );
      final result = ProPlacementTriggerAuditEngine.build(input: _input());
      expect(result.title, ProPlacementTriggerAuditCopy.eligibleAndShownTitle);
      expect(result.blockReason, 'none');
    });

    test('blockedNoUsefulProof when no useful proof exists', () {
      expect(
        ProPlacementTriggerAuditEngine.resolveOutcome(
          _input(
            feedbackType: null,
            confidenceLevel: ProofConfidenceLevel.watchOnly,
            hasUsefulOrStrongProof: false,
            proPlacementEligible: false,
            proPlacementShown: false,
          ),
        ),
        ProPlacementTriggerAuditOutcome.blockedNoUsefulProof,
      );
    });

    test('blockedWeakProof when proof is watch-only/cautious', () {
      expect(
        ProPlacementTriggerAuditEngine.resolveOutcome(
          _input(
            confidenceLevel: ProofConfidenceLevel.watchOnly,
            hasUsefulOrStrongProof: true,
            feedbackType: BetaProofFeedbackType.useful,
            proPlacementEligible: false,
            proPlacementShown: false,
          ),
        ),
        ProPlacementTriggerAuditOutcome.blockedWeakProof,
      );
      expect(
        ProPlacementTriggerAuditEngine.resolveOutcome(
          _input(
            confidenceLevel: ProofConfidenceLevel.emerging,
            hasUsefulOrStrongProof: true,
            feedbackType: BetaProofFeedbackType.useful,
            proPlacementEligible: false,
            proPlacementShown: false,
          ),
        ),
        ProPlacementTriggerAuditOutcome.blockedWeakProof,
      );
    });

    test('blockedNegativeFeedback after Too vague / Not relevant', () {
      for (final type in [
        BetaProofFeedbackType.tooVague,
        BetaProofFeedbackType.notRelevant,
      ]) {
        expect(
          ProPlacementTriggerAuditEngine.resolveOutcome(
            _input(
              feedbackType: type,
              proPlacementEligible: false,
              proPlacementShown: false,
            ),
          ),
          ProPlacementTriggerAuditOutcome.blockedNegativeFeedback,
        );
      }
    });

    test('blockedNoStrongAnchor when safe anchor is missing', () {
      expect(
        ProPlacementTriggerAuditEngine.resolveOutcome(
          _input(
            hasSafeAnchor: false,
            proPlacementEligible: false,
            proPlacementShown: false,
          ),
        ),
        ProPlacementTriggerAuditOutcome.blockedNoStrongAnchor,
      );
    });

    test('blockedAlreadyShown when Pro already shown', () {
      expect(
        ProPlacementTriggerAuditEngine.resolveOutcome(
          _input(
            hasProEngagement: true,
            proPlacementEligible: false,
            proPlacementShown: false,
          ),
        ),
        ProPlacementTriggerAuditOutcome.blockedAlreadyShown,
      );
    });

    test('production behavior unchanged without beta mission', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        ProPlacementTriggerAuditEngine.shouldShow(betaMissionEnabled: false),
        isFalse,
      );
      expect(
        ProPlacementTriggerAuditEngine.build(
          input: _input(betaMissionEnabled: false),
        ),
        ProPlacementTriggerAuditResult.hidden,
      );
    });

    test('no RevenueCat purchase pricing changes', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: 4,
          isPro: false,
          hasUsefulProof: true,
          confidenceLevel: ProofConfidenceLevel.strong,
          feedbackState: ProofQualityFeedbackState.useful,
          hasPaywallSeen: false,
          hasFreshReturnAfterCorrection: false,
          hasChangeAnchor: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });
  });

  group('copy guard', () {
    test('no private journal text', () {
      for (final line in ProPlacementTriggerAuditCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('ProPlacementTriggerAuditCard', () {
    testWidgets('card renders outcome and warning', (tester) async {
      await _pumpCard(
        tester,
        input: _input(
          proPlacementEligible: false,
          proPlacementShown: false,
          hasUsefulOrStrongProof: false,
          feedbackType: null,
          confidenceLevel: ProofConfidenceLevel.watchOnly,
        ),
      );

      expect(
        find.byKey(const Key('pro_placement_trigger_audit_heading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pro_placement_trigger_audit_outcome')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pro_placement_trigger_audit_block_reason')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pro_placement_trigger_audit_warning')),
        findsOneWidget,
      );
      expect(
        find.text(ProPlacementTriggerAuditCopy.warning),
        findsOneWidget,
      );
      expect(
        find.textContaining('Pro placement after useful proof'),
        findsOneWidget,
      );
    });

    testWidgets('hidden when beta mission disabled', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await _pumpCard(tester, input: _input(betaMissionEnabled: false));
      expect(
        find.byKey(const Key('pro_placement_trigger_audit_heading')),
        findsNothing,
      );
    });
  });
}
