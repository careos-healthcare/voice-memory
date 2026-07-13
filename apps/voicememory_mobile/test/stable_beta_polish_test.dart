import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_copy.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_engine.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/first_session_proof_repair/first_session_proof_repair_copy.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_copy.dart';
import 'package:voicememory_mobile/features/pro_visibility_lift/pro_visibility_lift_copy.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/beta_repair_lab_card.dart';

BetaRepairLabVisibilityInput _input({
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.strong,
  BetaProofFeedbackType? feedbackType = BetaProofFeedbackType.useful,
}) =>
    BetaRepairLabVisibilityInput(
      mode: BetaRepairLabMode.proofSpecificityCaution,
      entryCount: 4,
      source: 'test',
      isPro: false,
      isRecording: false,
      isDegradedTranscriptState: false,
      whatChangedQuestionActive: false,
      patternReviewInboxHasActiveItems: false,
      hasTimelineProofVisible: true,
      hasConfirmedRepeat: true,
      confidenceLevel: confidenceLevel,
      hasUsefulProofFeedback: feedbackType == BetaProofFeedbackType.useful,
      feedbackType: feedbackType,
      isNegativeFeedback: feedbackType == BetaProofFeedbackType.tooVague ||
          feedbackType == BetaProofFeedbackType.notRelevant,
      betaMissionEnabled: true,
    );

void main() {
  setUp(() async {
    await BetaRepairLabStore.resetForTest(null);
    ArchiveBetaMissionGate.enabledOverride = true;
    BetaRepairLabStore.repairModeOverrideForTest = null;
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaRepairLabStore.repairModeOverrideForTest = null;
  });

  group('first-session clarity', () {
    test('first-session copy says Record one real moment', () {
      expect(RecordFirstUsePromptCopy.title, 'Record one real moment');
      expect(RecordScreenFramingCopy.emptyArchiveTitle, 'Record one real moment');
      expect(
        RecordFirstUsePromptCopy.body,
        'One real sentence is enough. ArchiveMe compares saved moments later.',
      );
    });

    test('first-session examples are concrete', () {
      expect(
        RecordFirstUsePromptCopy.examples,
        [
          'I kept checking even after I was done.',
          'I avoided replying again.',
          'I felt pressure before starting.',
        ],
      );
    });

    test('first-session copy avoids journal therapy coach advice language', () {
      final banned = ['journal', 'therapy', 'coach', 'advice', 'reflection'];
      for (final line in [
        RecordFirstUsePromptCopy.title,
        RecordFirstUsePromptCopy.body,
        ...RecordFirstUsePromptCopy.examples,
        RecordScreenFramingCopy.emptyArchiveBody,
      ]) {
        for (final word in banned) {
          expect(line.toLowerCase(), isNot(contains(word)), reason: line);
        }
      }
    });

    test('primary CTA is Record moment', () {
      expect(VisibleArchiveProofCopy.firstUseCaptureCta, 'Record moment');
      expect(ConsumerUiCopy.recordMomentCta, 'Record moment');
    });
  });

  group('proof readability and correction', () {
    test('useful proof card includes Why this appeared line', () {
      final result = BetaRepairLabEngine.buildProof(
        input: _input(confidenceLevel: ProofConfidenceLevel.strong),
      );
      expect(result.whyAppearedLine, BetaRepairLabCopy.proofStrongWhyAppeared);
      expect(result.whyAppearedLine, contains('Why this appeared'));
    });

    test('proof feedback prompt says Does this feel right', () {
      expect(BetaRepairLabCopy.proofFeedbackPrompt, 'Does this feel right?');
      final result = BetaRepairLabEngine.buildProof(input: _input());
      expect(result.feedbackPrompt, 'Does this feel right?');
    });

    test('Too vague response waits for clearer evidence', () {
      expect(
        BetaRepairLabCopy.proofFeedbackTooVagueResponse,
        'Got it. ArchiveMe will wait for clearer evidence before showing this again.',
      );
      expect(
        FirstSessionProofRepairCopy.proofNextStepTooVague,
        BetaRepairLabCopy.proofFeedbackTooVagueResponse,
      );
    });

    test('Not relevant response avoids useful pattern treatment', () {
      expect(
        BetaRepairLabCopy.proofFeedbackNotRelevantResponse,
        'Got it. ArchiveMe will not treat this as a useful pattern.',
      );
      expect(
        FirstSessionProofRepairCopy.proofNextStepNotRelevant,
        BetaRepairLabCopy.proofFeedbackNotRelevantResponse,
      );
    });

    testWidgets('proof card shows feedback prompt and why appeared', (tester) async {
      final result = BetaRepairLabEngine.buildProof(input: _input());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BetaRepairLabProofCard.test(result: result),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Does this feel right?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('Too vague'), findsOneWidget);
      expect(find.text('Not relevant'), findsOneWidget);
      expect(find.text(result.whyAppearedLine), findsOneWidget);
    });

    testWidgets('proof card shows correction response after Too vague', (tester) async {
      final result = BetaRepairLabEngine.buildProof(input: _input());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BetaRepairLabProofCard.test(
              result: result,
              answered: true,
              answerType: BetaProofFeedbackType.tooVague,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(BetaRepairLabCopy.proofFeedbackTooVagueResponse),
        findsOneWidget,
      );
      expect(find.text('Does this feel right?'), findsNothing);
    });
  });

  group('Pro moment', () {
    test('Pro bridge copy explains free first proof and longer trail', () {
      expect(BetaRepairLabCopy.proPlacementTitle, 'Keep the longer trail');
      expect(
        BetaRepairLabCopy.proPlacementBody,
        contains('Free shows the first useful proof'),
      );
      expect(
        BetaRepairLabCopy.proPlacementBody,
        contains('returns, changes, fades, or needs correcting'),
      );
      expect(ProVisibilityLiftCopy.title, 'Keep the longer trail');
      expect(
        ProVisibilityLiftCopy.body,
        RevenueLiftExperimentV2Copy.proVisibilityBody,
      );
      expect(ProBridgeVisibilityCopy.cta, 'See Pro timeline');
      expect(ProBridgeVisibilityCopy.secondary, 'Not now');
    });

    test('Pro placement only after strong useful proof', () {
      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.proPlacementAfterUsefulProof,
      );
      expect(
        BetaRepairLabEngine.shouldShowProPlacement(
          input: _input(
            confidenceLevel: ProofConfidenceLevel.watchOnly,
            feedbackType: null,
          ),
        ),
        isFalse,
      );
      expect(
        BetaRepairLabEngine.shouldShowProPlacement(
          input: _input(
            confidenceLevel: ProofConfidenceLevel.strong,
            feedbackType: BetaProofFeedbackType.useful,
          ),
        ),
        isTrue,
      );
    });
  });

  group('empty states', () {
    test('empty states point back to recording real moments', () {
      const target =
          'Record a few real moments. ArchiveMe will look for what repeats across them.';
      expect(ConsumerUiCopy.patternsEarlyStateBody, target);
      expect(ArchiveHistoryCopy.emptyBody, target);
      expect(
        VisibleArchiveProofCopy.patternsMindMapEmptyBody,
        'ArchiveMe will look for what repeats across them.',
      );
      expect(
        EmptyArchiveCopy.intentionalEmptyOpening,
        ConsumerUiCopy.patternsEarlyStateBody,
      );
    });
  });

  group('protected areas and baseline', () {
    test('proof protection baseline remains default in beta mission', () {
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.proofSpecificityCaution,
      );
      expect(BetaRepairLabStore.isDefaultBaselineActive, isTrue);
    });

    test('no RevenueCat pricing purchase paywall mechanics changed', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(PaywallSource.valueMoment.name, 'valueMoment');
    });
  });
}
