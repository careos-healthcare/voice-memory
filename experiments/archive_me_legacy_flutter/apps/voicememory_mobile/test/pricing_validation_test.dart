import 'dart:io';

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
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_analytics.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_copy.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pro/pricing_validation_card.dart';

BetaRepairLabVisibilityInput _input({
  bool betaMissionEnabled = true,
  BetaRepairLabMode mode = BetaRepairLabMode.pricingValidation,
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
  required PricingValidationResult result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PricingValidationCard.test(result: result, onSeePro: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    await BetaRepairLabStore.resetForTest(null);
    ArchiveBetaMissionGate.enabledOverride = true;
    BetaRepairLabStore.repairModeOverrideForTest = null;
    PricingValidationAnalytics.resetForTest();
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaRepairLabStore.repairModeOverrideForTest = null;
    PricingValidationAnalytics.resetForTest();
  });

  group('BetaRepairLabBuildOverride pricingValidation', () {
    test('pricingValidation parsed only when beta mission is true', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        BetaRepairLabStore.buildOverrideMode,
        BetaRepairLabMode.pricingValidation,
      );
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.pricingValidation,
      );
      expect(
        BetaRepairLabStore.buildOverrideActiveLabel,
        'Build override active: Pricing validation',
      );
    });

    test('no override still resolves to proof protection baseline', () {
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.proofSpecificityCaution,
      );
    });

    test('build override ignored when beta mission is false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(BetaRepairLabStore.activeMode, BetaRepairLabMode.none);
    });

    test('invalid beta override falls back to proof protection', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'not_a_mode';
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.proofSpecificityCaution,
      );
    });
  });

  group('PricingValidationEngine', () {
    test(
      'card appears only after strong useful proof with pro engagement',
      () async {
        BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
        expect(
          PricingValidationEngine.shouldShow(
            input: _input(),
            hasProEngagement: true,
          ),
          isTrue,
        );
        final result = PricingValidationEngine.build(
          input: _input(),
          hasProEngagement: true,
        );
        expect(result.shouldShow, isTrue);
        expect(result.title, PricingValidationCopy.title);
        expect(result.body, PricingValidationCopy.body);
      },
    );

    test('blocked when repair mode is not pricingValidation', () async {
      BetaRepairLabStore.repairModeOverrideForTest = 'paywallValue';
      expect(
        PricingValidationEngine.shouldShow(
          input: _input(),
          hasProEngagement: true,
        ),
        isFalse,
      );
    });

    test('blocked without pro engagement', () async {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.shouldShow(
          input: _input(),
          hasProEngagement: false,
        ),
        isFalse,
      );
    });

    test('blocked after Too vague / Not relevant', () async {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      for (final type in [
        BetaProofFeedbackType.tooVague,
        BetaProofFeedbackType.notRelevant,
      ]) {
        expect(
          PricingValidationEngine.shouldShow(
            input: _input(feedbackType: type, isNegativeFeedback: true),
            hasProEngagement: true,
          ),
          isFalse,
        );
      }
    });

    test('blocked for weak/watch-only proof', () async {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      for (final level in [
        ProofConfidenceLevel.watchOnly,
        ProofConfidenceLevel.emerging,
      ]) {
        expect(
          PricingValidationEngine.shouldShow(
            input: _input(feedbackType: null, confidenceLevel: level),
            hasProEngagement: true,
          ),
          isFalse,
        );
      }
    });

    test('production behavior unchanged without beta mission', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.shouldShow(
          input: _input(betaMissionEnabled: false),
          hasProEngagement: true,
        ),
        isFalse,
      );
    });

    test('blocks other pro cards when active', () async {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.blocksOtherProCardsWhenPricingValidationActive(
          betaMissionEnabled: true,
          showPricingValidation: true,
        ),
        isTrue,
      );
    });

    test('CTA opens existing paywall source value moment', () {
      final source = File(
        'lib/features/recording/recording_state_controller.dart',
      );
      final contents = source.readAsStringSync();
      expect(contents, contains('record_beta_repair_lab_pricing_validation'));
      expect(contents, contains('PaywallSource.valueMoment'));
    });

    test('no RevenueCat product entitlement changes', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(PaywallSource.valueMoment.name, 'valueMoment');
    });
  });

  group('PricingValidationAnalytics', () {
    test('price and reason analytics are metadata only', () async {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      final result = PricingValidationEngine.build(
        input: _input(),
        hasProEngagement: true,
      );
      final captured = <PricingValidationEventType, PricingValidationEvent>{};
      PricingValidationAnalytics.captureForTest = (event) {
        captured[event.type] = event;
      };

      PricingValidationAnalytics.priceSelected(
        result: result,
        price: PricingValidationPriceOption.price499,
      );
      PricingValidationAnalytics.reasonSelected(
        result: result,
        reason: PricingValidationReasonOption.clearerTimeline,
      );

      final priceEvent = captured[PricingValidationEventType.priceSelected]!;
      final priceProps = priceEvent.analyticsProperties;
      expect(priceEvent.selectedPrice, PricingValidationPriceOption.price499);
      expect(priceProps['selected_price'], '4.99');
      expect(priceEvent.source, 'test');
      expect(priceEvent.entryCount, 4);
      expect(priceEvent.hasUsefulProof, isTrue);
      expect(priceEvent.activeRepairMode, 'pricing_validation');
      expect(priceProps.containsKey('journal'), isFalse);

      final reasonEvent = captured[PricingValidationEventType.reasonSelected]!;
      final reasonProps = reasonEvent.analyticsProperties;
      expect(
        reasonEvent.selectedReason,
        PricingValidationReasonOption.clearerTimeline,
      );
      expect(reasonProps['selected_reason'], 'clearer_timeline');
      expect(reasonProps.containsKey('transcript'), isFalse);
    });
  });

  group('copy guard', () {
    test('no private journal text', () {
      for (final line in PricingValidationCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
      for (final line in BetaRepairLabCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('PricingValidationCard', () {
    testWidgets('card renders pricing validation copy', (tester) async {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      final result = PricingValidationEngine.build(
        input: _input(),
        hasProEngagement: true,
      );
      await _pumpCard(tester, result: result);

      expect(find.byKey(const Key('pricing_validation_card')), findsOneWidget);
      expect(find.text(PricingValidationCopy.title), findsOneWidget);
      expect(find.text(PricingValidationCopy.body), findsOneWidget);
      expect(find.text(PricingValidationCopy.pricePrompt), findsOneWidget);
      expect(find.text(PricingValidationCopy.reasonPrompt), findsOneWidget);
      expect(find.text(PricingValidationCopy.primaryCta), findsOneWidget);
    });

    testWidgets('price selection emits analytics', (tester) async {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      final result = PricingValidationEngine.build(
        input: _input(),
        hasProEngagement: true,
      );
      final captured = <PricingValidationEventType>[];
      PricingValidationAnalytics.captureForTest = (event) {
        captured.add(event.type);
      };

      await _pumpCard(tester, result: result);
      await tester.tap(find.byKey(const Key('pricing_validation_price_4.99')));
      await tester.pump();

      expect(
        captured.contains(PricingValidationEventType.priceSelected),
        isTrue,
      );
    });
  });
}
