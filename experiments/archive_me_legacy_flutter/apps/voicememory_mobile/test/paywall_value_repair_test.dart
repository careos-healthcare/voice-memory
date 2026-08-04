import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_copy.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/paywall_value_repair/paywall_value_repair_copy.dart';
import 'package:voicememory_mobile/features/paywall_value_repair/paywall_value_repair_engine.dart';
import 'package:voicememory_mobile/features/paywall_value_repair/paywall_value_repair_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pro/paywall_value_repair_card.dart';

import 'support/recording_feature_source.dart';

BetaRepairLabVisibilityInput _input({
  bool betaMissionEnabled = true,
  BetaRepairLabMode mode = BetaRepairLabMode.paywallValue,
  int entryCount = 4,
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.strong,
  bool hasTimelineProofVisible = true,
  bool hasConfirmedRepeat = true,
  BetaProofFeedbackType? feedbackType = BetaProofFeedbackType.useful,
  bool isNegativeFeedback = false,
  bool isPro = false,
}) => BetaRepairLabVisibilityInput(
  mode: mode,
  entryCount: entryCount,
  source: 'test',
  isPro: isPro,
  isRecording: false,
  isDegradedTranscriptState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
  hasTimelineProofVisible: hasTimelineProofVisible,
  hasConfirmedRepeat: hasConfirmedRepeat,
  confidenceLevel: confidenceLevel,
  hasUsefulProofFeedback: feedbackType == BetaProofFeedbackType.useful,
  feedbackType: feedbackType,
  isNegativeFeedback: isNegativeFeedback,
  betaMissionEnabled: betaMissionEnabled,
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required PaywallValueRepairResult result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: PaywallValueRepairCard.test(result: result, onSeePro: () {}),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    ArchiveBetaMissionGate.enabledOverride = true;
    BetaRepairLabStore.repairModeOverrideForTest = null;
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaRepairLabStore.repairModeOverrideForTest = null;
  });

  group('BetaRepairLabBuildOverride paywallValue', () {
    test('paywallValue parsed only when beta mission is true', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'paywallValue';
      expect(
        BetaRepairLabStore.buildOverrideMode,
        BetaRepairLabMode.paywallValue,
      );
      expect(BetaRepairLabStore.activeMode, BetaRepairLabMode.paywallValue);
      expect(
        BetaRepairLabStore.buildOverrideActiveLabel,
        'Build override active: Paywall value repair',
      );
    });

    test('build override ignored when beta mission is false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      BetaRepairLabStore.repairModeOverrideForTest = 'paywallValue';
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(BetaRepairLabStore.activeMode, BetaRepairLabMode.none);
    });

    test('invalid mode falls back to proof protection in beta', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'not_a_mode';
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.proofSpecificityCaution,
      );
    });
  });

  group('PaywallValueRepairEngine', () {
    test('card appears only after useful/strong proof', () async {
      await BetaRepairLabStore.setModeForTest(BetaRepairLabMode.paywallValue);
      expect(PaywallValueRepairEngine.shouldShow(input: _input()), isTrue);
      final result = PaywallValueRepairEngine.build(input: _input());
      expect(result.shouldShow, isTrue);
      expect(result.title, PaywallValueRepairCopy.title);
      expect(result.bullets, PaywallValueRepairCopy.bullets);
    });

    test('blocked when repair mode is not paywallValue', () async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.proPlacementAfterUsefulProof,
      );
      expect(PaywallValueRepairEngine.shouldShow(input: _input()), isFalse);
    });

    test('blocked after Too vague / Not relevant', () async {
      await BetaRepairLabStore.setModeForTest(BetaRepairLabMode.paywallValue);
      for (final type in [
        BetaProofFeedbackType.tooVague,
        BetaProofFeedbackType.notRelevant,
      ]) {
        expect(
          PaywallValueRepairEngine.shouldShow(
            input: _input(feedbackType: type, isNegativeFeedback: true),
          ),
          isFalse,
        );
      }
    });

    test('blocked without useful/strong proof', () async {
      await BetaRepairLabStore.setModeForTest(BetaRepairLabMode.paywallValue);
      expect(
        PaywallValueRepairEngine.shouldShow(
          input: _input(
            feedbackType: null,
            confidenceLevel: ProofConfidenceLevel.watchOnly,
          ),
        ),
        isFalse,
      );
    });

    test('production behavior unchanged without beta mission', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        PaywallValueRepairEngine.shouldShow(
          input: _input(betaMissionEnabled: false),
        ),
        isFalse,
      );
    });

    test('no RevenueCat purchase pricing changes', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(PaywallSource.valueMoment.name, 'valueMoment');
    });

    test('retired beta repair CTA does not bypass the V1 paywall policy', () {
      final contents = readRecordingFeatureSource();
      expect(contents, isNot(contains('record_beta_repair_lab_paywall_value')));
      expect(contents, isNot(contains('PaywallSource.valueMoment')));
    });
  });

  group('copy guard', () {
    test('no private journal text', () {
      for (final line in PaywallValueRepairCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
      for (final line in BetaRepairLabCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('PaywallValueRepairCard', () {
    testWidgets('card renders outcome copy', (tester) async {
      await BetaRepairLabStore.setModeForTest(BetaRepairLabMode.paywallValue);
      final result = PaywallValueRepairEngine.build(input: _input());
      await _pumpCard(tester, result: result);

      expect(
        find.byKey(const Key('paywall_value_repair_card')),
        findsOneWidget,
      );
      expect(find.text(PaywallValueRepairCopy.title), findsOneWidget);
      expect(find.text(PaywallValueRepairCopy.body), findsOneWidget);
      expect(find.text(PaywallValueRepairCopy.support), findsOneWidget);
      expect(find.text(PaywallValueRepairCopy.primaryCta), findsOneWidget);
    });
  });
}
