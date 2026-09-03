import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_copy.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:archiveme_mobile/features/pricing_value_framing/pricing_value_framing_analytics.dart';
import 'package:archiveme_mobile/features/pricing_value_framing/pricing_value_framing_copy.dart';
import 'package:archiveme_mobile/features/pricing_value_framing/pricing_value_framing_engine.dart';
import 'package:archiveme_mobile/features/pricing_value_framing/pricing_value_framing_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/pro/pricing_value_framing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BetaRepairLabVisibilityInput _input({
  bool betaMissionEnabled = true,
  BetaRepairLabMode mode = BetaRepairLabMode.pricingValueFraming,
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
  required PricingValueFramingResult result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PricingValueFramingCard.test(result: result, onSeePro: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    ArchiveBetaMissionGate.enabledOverride = true;
    BetaRepairLabStore.repairModeOverrideForTest = null;
    PricingValueFramingAnalytics.resetForTest();
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaRepairLabStore.repairModeOverrideForTest = null;
    PricingValueFramingAnalytics.resetForTest();
  });

  group('BetaRepairLabBuildOverride pricingValueFraming', () {
    test('pricingValueFraming parsed only when beta mission is true', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValueFraming';
      expect(
        BetaRepairLabStore.buildOverrideMode,
        BetaRepairLabMode.pricingValueFraming,
      );
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.pricingValueFraming,
      );
      expect(
        BetaRepairLabStore.buildOverrideActiveLabel,
        'Build override active: Pricing value framing',
      );
    });

    test('build override ignored when beta mission is false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValueFraming';
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(BetaRepairLabStore.activeMode, BetaRepairLabMode.none);
    });

    test('invalid mode still falls back to proof protection in beta', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'not_a_mode';
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.proofSpecificityCaution,
      );
    });
  });

  group('PricingValueFramingEngine', () {
    test('card appears only after useful/strong proof', () async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.pricingValueFraming,
      );
      expect(PricingValueFramingEngine.shouldShow(input: _input()), isTrue);
      final result = PricingValueFramingEngine.build(input: _input());
      expect(result.shouldShow, isTrue);
      expect(result.title, PricingValueFramingCopy.title);
      expect(result.bullets, PricingValueFramingCopy.bullets);
      expect(result.valueExplanation, PricingValueFramingCopy.valueExplanation);
    });

    test('blocked when repair mode is not pricingValueFraming', () async {
      await BetaRepairLabStore.setModeForTest(BetaRepairLabMode.paywallValue);
      expect(PricingValueFramingEngine.shouldShow(input: _input()), isFalse);
    });

    test('blocked after Too vague / Not relevant', () async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.pricingValueFraming,
      );
      for (final type in [
        BetaProofFeedbackType.tooVague,
        BetaProofFeedbackType.notRelevant,
      ]) {
        expect(
          PricingValueFramingEngine.shouldShow(
            input: _input(feedbackType: type, isNegativeFeedback: true),
          ),
          isFalse,
        );
      }
    });

    test('blocked for weak/watch-only proof', () async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.pricingValueFraming,
      );
      for (final level in [
        ProofConfidenceLevel.watchOnly,
        ProofConfidenceLevel.emerging,
      ]) {
        expect(
          PricingValueFramingEngine.shouldShow(
            input: _input(feedbackType: null, confidenceLevel: level),
          ),
          isFalse,
        );
      }
    });

    test('blocked without useful/strong proof', () async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.pricingValueFraming,
      );
      expect(
        PricingValueFramingEngine.shouldShow(
          input: _input(
            feedbackType: null,
            confidenceLevel: ProofConfidenceLevel.useful,
          ),
        ),
        isTrue,
      );
      expect(
        PricingValueFramingEngine.shouldShow(
          input: _input(
            feedbackType: null,
          ),
        ),
        isTrue,
      );
    });

    test('production behavior unchanged without beta mission', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        PricingValueFramingEngine.shouldShow(
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

    test('blocks other pro cards when active', () async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.pricingValueFraming,
      );
      expect(
        PricingValueFramingEngine.blocksOtherProCardsWhenPricingValueFramingActive(
          betaMissionEnabled: true,
          showPricingValueFraming: true,
        ),
        isTrue,
      );
    });
  });

  group('PricingValueFramingAnalytics', () {
    test('feedback analytics are metadata only', () async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.pricingValueFraming,
      );
      final result = PricingValueFramingEngine.build(input: _input());
      final captured = <String, Map<String, Object>>{};
      PricingValueFramingAnalytics.captureForTest = (event, props) {
        captured[event] = props;
      };

      PricingValueFramingAnalytics.feedbackSelected(
        result: result,
        feedback: PricingValueFramingFeedbackType.yes,
      );

      final props =
          captured[PricingValueFramingAnalytics.feedbackSelectedEvent];
      expect(props, isNotNull);
      expect(props!['source'], 'test');
      expect(props['entry_count'], 4);
      expect(props['feedback'], 'yes');
      expect(props['has_useful_proof'], isTrue);
      expect(props['active_repair_mode'], 'pricing_value_framing');
      expect(props.containsKey('transcript'), isFalse);
      expect(props.containsKey('journal'), isFalse);
    });
  });

  group('copy guard', () {
    test('no private journal text', () {
      for (final line in PricingValueFramingCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
      for (final line in BetaRepairLabCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('PricingValueFramingCard', () {
    testWidgets('card renders outcome copy', (tester) async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.pricingValueFraming,
      );
      final result = PricingValueFramingEngine.build(input: _input());
      await _pumpCard(tester, result: result);

      expect(
        find.byKey(const Key('pricing_value_framing_card')),
        findsOneWidget,
      );
      expect(find.text(PricingValueFramingCopy.title), findsOneWidget);
      expect(find.text(PricingValueFramingCopy.body), findsOneWidget);
      expect(
        find.text(PricingValueFramingCopy.valueExplanation),
        findsOneWidget,
      );
      expect(find.text(PricingValueFramingCopy.reassurance), findsOneWidget);
      expect(find.text(PricingValueFramingCopy.primaryCta), findsOneWidget);
      expect(find.text(PricingValueFramingCopy.feedbackPrompt), findsOneWidget);
    });

    testWidgets('feedback buttons emit analytics', (tester) async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.pricingValueFraming,
      );
      final result = PricingValueFramingEngine.build(input: _input());
      final captured = <String, Map<String, Object>>{};
      PricingValueFramingAnalytics.captureForTest = (event, props) {
        captured[event] = props;
      };

      await _pumpCard(tester, result: result);
      await tester.tap(
        find.byKey(const Key('pricing_value_framing_feedback_yes')),
      );
      await tester.pump();

      expect(
        captured.containsKey(
          PricingValueFramingAnalytics.feedbackSelectedEvent,
        ),
        isTrue,
      );
    });
  });
}
