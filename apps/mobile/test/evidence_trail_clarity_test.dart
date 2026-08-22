import 'dart:io';
import 'support/record_screen_library_source.dart';

import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_copy.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:archiveme_mobile/features/evidence_trail_clarity/evidence_trail_clarity_analytics.dart';
import 'package:archiveme_mobile/features/evidence_trail_clarity/evidence_trail_clarity_copy.dart';
import 'package:archiveme_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:archiveme_mobile/features/evidence_trail_clarity/evidence_trail_clarity_model.dart';
import 'package:archiveme_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/pro/evidence_trail_clarity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BetaRepairLabVisibilityInput _input({
  bool betaMissionEnabled = true,
  int entryCount = 4,
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.strong,
  bool hasTimelineProofVisible = true,
  bool hasConfirmedRepeat = true,
  BetaProofFeedbackType? feedbackType = BetaProofFeedbackType.useful,
  bool isNegativeFeedback = false,
  bool isPro = false,
}) => BetaRepairLabVisibilityInput(
  mode: BetaRepairLabMode.evidenceTrailTimelineClarity,
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
  required EvidenceTrailClarityResult result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: EvidenceTrailClarityCard.test(result: result, onSeePro: () {}),
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
    EvidenceTrailClarityAnalytics.resetForTest();
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaRepairLabStore.repairModeOverrideForTest = null;
    EvidenceTrailClarityAnalytics.resetForTest();
  });

  group('BetaRepairLabBuildOverride evidenceTrailTimelineClarity', () {
    test('parses build override only when beta mission is true', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      expect(
        BetaRepairLabStore.buildOverrideMode,
        BetaRepairLabMode.evidenceTrailTimelineClarity,
      );
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.evidenceTrailTimelineClarity,
      );
      expect(
        BetaRepairLabStore.buildOverrideActiveLabel,
        'Build override active: Evidence trail timeline clarity',
      );
    });

    test('invalid override in beta falls back to proof protection', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'not_a_mode';
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.proofSpecificityCaution,
      );
    });

    test('invalid override outside beta returns none', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      BetaRepairLabStore.repairModeOverrideForTest = 'not_a_mode';
      expect(BetaRepairLabStore.activeMode, BetaRepairLabMode.none);
    });
  });

  group('EvidenceTrailClarityEngine', () {
    test('card appears after strong useful proof', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      expect(
        EvidenceTrailClarityEngine.shouldShow(
          input: _input(),
          hasSafeAnchor: true,
        ),
        isTrue,
      );
      final result = EvidenceTrailClarityEngine.build(
        input: _input(),
        hasSafeAnchor: true,
      );
      expect(result.shouldShow, isTrue);
      expect(result.title, EvidenceTrailClarityCopy.title);
      expect(result.supportLine, EvidenceTrailClarityCopy.supportLine);
    });

    test('blocked for watchOnly and emerging proof', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      for (final level in [
        ProofConfidenceLevel.watchOnly,
        ProofConfidenceLevel.emerging,
      ]) {
        expect(
          EvidenceTrailClarityEngine.shouldShow(
            input: _input(confidenceLevel: level, feedbackType: null),
            hasSafeAnchor: true,
          ),
          isFalse,
        );
      }
    });

    test('blocked after Too vague and Not relevant', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      for (final type in [
        BetaProofFeedbackType.tooVague,
        BetaProofFeedbackType.notRelevant,
      ]) {
        expect(
          EvidenceTrailClarityEngine.shouldShow(
            input: _input(feedbackType: type, isNegativeFeedback: true),
            hasSafeAnchor: true,
          ),
          isFalse,
        );
      }
    });

    test('blocked when no safe anchor', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      expect(
        EvidenceTrailClarityEngine.shouldShow(
          input: _input(),
          hasSafeAnchor: false,
        ),
        isFalse,
      );
    });

    test('blocked when proof protection blocks Pro cards', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      expect(
        EvidenceTrailClarityEngine.shouldShow(
          input: _input(),
          hasSafeAnchor: true,
          blocksProCards: true,
        ),
        isFalse,
      );
    });

    test('blocked when repair mode is not evidenceTrailTimelineClarity', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        EvidenceTrailClarityEngine.shouldShow(
          input: _input(),
          hasSafeAnchor: true,
        ),
        isFalse,
      );
    });

    test('suppresses other Pro value pricing cards when active', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      expect(
        EvidenceTrailClarityEngine.blocksOtherProCardsWhenEvidenceTrailClarityActive(
          betaMissionEnabled: true,
          showEvidenceTrailClarity: true,
        ),
        isTrue,
      );
      expect(
        PricingValidationEngine.blocksOtherProCardsWhenPricingValidationActive(
          betaMissionEnabled: true,
          showPricingValidation: true,
        ),
        isFalse,
      );
    });
  });

  group('EvidenceTrailClarityAnalytics', () {
    test('feedback analytics is metadata only', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      final result = EvidenceTrailClarityEngine.build(
        input: _input(),
        hasSafeAnchor: true,
      );
      final captured = <String, Map<String, Object>>{};
      EvidenceTrailClarityAnalytics.captureForTest = (event, props) {
        captured[event] = props;
      };

      EvidenceTrailClarityAnalytics.feedbackSelected(
        result: result,
        feedback: EvidenceTrailClarityFeedbackOption.notYet,
      );

      final props =
          captured[EvidenceTrailClarityAnalytics.feedbackSelectedEvent];
      expect(props!['feedback'], 'not_yet');
      expect(props['source'], 'test');
      expect(props['entry_count'], 4);
      expect(props['has_useful_proof'], isTrue);
      expect(props['confidence_level'], 'strong');
      expect(props['active_repair_mode'], 'evidence_trail_timeline_clarity');
      expect(props.containsKey('journal'), isFalse);
      expect(props.containsKey('transcript'), isFalse);
    });
  });

  group('Integration wiring', () {
    test('CTA opens existing PaywallSource.valueMoment', () {
      final source = readRecordScreenLibrarySource();
      expect(source, contains('record_beta_repair_lab_evidence_trail_clarity'));
      expect(source, contains('PaywallSource.valueMoment'));
    });

    test('no RevenueCat pricing purchase restore changes', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(PaywallSource.valueMoment.name, 'valueMoment');
      for (final path in [
        'lib/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart',
        'lib/features/evidence_trail_clarity/evidence_trail_clarity_analytics.dart',
      ]) {
        final contents = File(path).readAsStringSync();
        expect(contents.contains('billing/'), isFalse);
        expect(contents.contains('restorePurchases'), isFalse);
      }
    });
  });

  group('EvidenceTrailClarityCard', () {
    testWidgets('card copy contains timeline rows and Pro support line', (
      tester,
    ) async {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      final result = EvidenceTrailClarityEngine.build(
        input: _input(),
        hasSafeAnchor: true,
      );
      await _pumpCard(tester, result: result);

      expect(
        find.byKey(const Key('evidence_trail_clarity_card')),
        findsOneWidget,
      );
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('Next returns'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Correction'), findsOneWidget);
      expect(find.text('That longer trail is what Pro keeps.'), findsOneWidget);
      expect(find.text(EvidenceTrailClarityCopy.primaryCta), findsOneWidget);
    });

    testWidgets('feedback selection emits analytics', (tester) async {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      final result = EvidenceTrailClarityEngine.build(
        input: _input(),
        hasSafeAnchor: true,
      );
      final captured = <String, Map<String, Object>>{};
      EvidenceTrailClarityAnalytics.captureForTest = (event, props) {
        captured[event] = props;
      };

      await _pumpCard(tester, result: result);
      await tester.tap(
        find.byKey(const Key('evidence_trail_clarity_feedback_yes')),
      );
      await tester.pump();

      expect(
        captured.containsKey(
          EvidenceTrailClarityAnalytics.feedbackSelectedEvent,
        ),
        isTrue,
      );
    });
  });

  group('copy guard', () {
    test('passes metadata-safe guard', () {
      for (final text in EvidenceTrailClarityCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
      expect(
        BetaRepairLabCopy.modeLabel(
          BetaRepairLabMode.evidenceTrailTimelineClarity,
        ),
        'Evidence trail timeline clarity',
      );
    });
  });
}