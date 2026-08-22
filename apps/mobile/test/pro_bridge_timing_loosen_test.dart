import 'dart:io';

import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/restore_purchases_copy.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_timing_loosen_analytics.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_timing_loosen_engine.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_copy.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import 'package:archiveme_mobile/features/pro_moment_timing/pro_moment_timing_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/widgets/pro/pro_bridge_visibility_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProBridgeVisibilityInput _input({
  bool hasFirstProof = true,
  int entryCount = 3,
  bool hasTimelineProofVisible = false,
  bool hasFirstProofPayoffVisible = false,
  bool hasBetaProofLiftVisible = false,
  bool hasReturnAfterProofStrengthenedVisible = false,
  ProofConfidenceLevel? confidenceLevel,
  bool hasSafeAnchor = false,
  bool hasFreshReturnAfterCorrection = false,
  bool hasSolidStrongPatternWithSafeAnchors = false,
  ProofQualityFeedbackState feedbackState = ProofQualityFeedbackState.none,
  bool isRecording = false,
  bool isDegradedTranscriptState = false,
  bool isPostSaveDegradedState = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  bool isZeroEntryState = false,
}) => ProBridgeVisibilityInput(
  surface: ProBridgeVisibilitySurface.recordReady,
  source: 'test',
  entryCount: entryCount,
  isPro: false,
  postProofProBridgeEnabled: true,
  hasFirstProof: hasFirstProof,
  isZeroEntryState: isZeroEntryState,
  hasTimelineProofVisible: hasTimelineProofVisible,
  hasFirstProofPayoffVisible: hasFirstProofPayoffVisible,
  hasBetaProofLiftVisible: hasBetaProofLiftVisible,
  hasReturnAfterProofStrengthenedVisible:
      hasReturnAfterProofStrengthenedVisible,
  confidenceLevel: confidenceLevel,
  hasSafeAnchor: hasSafeAnchor,
  hasFreshReturnAfterCorrection: hasFreshReturnAfterCorrection,
  hasSolidStrongPatternWithSafeAnchors: hasSolidStrongPatternWithSafeAnchors,
  feedbackState: feedbackState,
  isRecording: isRecording,
  isDegradedTranscriptState: isDegradedTranscriptState,
  isPostSaveDegradedState: isPostSaveDegradedState,
  whatChangedQuestionActive: whatChangedQuestionActive,
  patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
);

void main() {
  setUp(() async {
    ProBridgeTimingLoosenAnalytics.resetForTest();
    await ProEvidenceValueDismissStore.resetForTest();
  });

  group('ProBridgeTimingLoosenEngine', () {
    test('still hidden before proof', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _input(
            hasFirstProof: false,
            entryCount: 0,
            isZeroEntryState: true,
          ),
        ),
        isFalse,
      );
    });

    test('still hidden below 3 entries', () {
      expect(
        ProBridgeTimingLoosenEngine.evaluate(
          input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
            _input(entryCount: 2),
          ),
        ).allowed,
        isFalse,
      );
    });

    test('visible after useful proof confidence', () {
      final result = ProBridgeTimingLoosenEngine.evaluate(
        input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
          _input(
            confidenceLevel: ProofConfidenceLevel.useful,
            hasSafeAnchor: true,
          ),
        ),
      );
      expect(result.allowed, isTrue);
      expect(result.trigger, ProMomentTimingTrigger.usefulProofConfidence);
    });

    test('visible after strong proof confidence', () {
      final result = ProBridgeTimingLoosenEngine.evaluate(
        input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
          _input(
            confidenceLevel: ProofConfidenceLevel.strong,
            hasSafeAnchor: true,
          ),
        ),
      );
      expect(result.allowed, isTrue);
      expect(result.trigger, ProMomentTimingTrigger.strongProofConfidence);
    });

    test('visible after BetaProofLift under valid proof', () {
      final result = ProBridgeTimingLoosenEngine.evaluate(
        input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
          _input(
            hasBetaProofLiftVisible: true,
            confidenceLevel: ProofConfidenceLevel.useful,
            hasSafeAnchor: true,
          ),
        ),
      );
      expect(result.allowed, isTrue);
      expect(
        result.trigger,
        ProMomentTimingTrigger.betaProofLiftUnderValidProof,
      );
    });

    test('visible after ReturnAfterProofStrengthening target', () {
      final result = ProBridgeTimingLoosenEngine.evaluate(
        input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
          _input(hasReturnAfterProofStrengthenedVisible: true),
        ),
      );
      expect(result.allowed, isTrue);
      expect(
        result.trigger,
        ProMomentTimingTrigger.returnAfterProofStrengthened,
      );
    });

    test('visible after fresh return correction', () {
      final result = ProBridgeTimingLoosenEngine.evaluate(
        input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
          _input(
            entryCount: 4,
            hasFreshReturnAfterCorrection: true,
            confidenceLevel: ProofConfidenceLevel.freshReturn,
            hasSafeAnchor: true,
          ),
        ),
      );
      expect(result.allowed, isTrue);
      expect(result.trigger, ProMomentTimingTrigger.freshReturnAfterCorrection);
    });

    test('visible with 4+ entries solid/strong pattern and safe anchors', () {
      final result = ProBridgeTimingLoosenEngine.evaluate(
        input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
          _input(
            entryCount: 4,
            hasSolidStrongPatternWithSafeAnchors: true,
            hasSafeAnchor: true,
          ),
        ),
      );
      expect(result.allowed, isTrue);
      expect(
        result.trigger,
        ProMomentTimingTrigger.solidStrongPatternWithSafeAnchors,
      );
    });

    test('hidden after Too vague', () {
      expect(
        ProBridgeTimingLoosenEngine.evaluate(
          input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
            _input(
              feedbackState: ProofQualityFeedbackState.tooVague,
              confidenceLevel: ProofConfidenceLevel.useful,
            ),
          ),
        ).allowed,
        isFalse,
      );
    });

    test('hidden after Not relevant', () {
      expect(
        ProBridgeTimingLoosenEngine.evaluate(
          input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
            _input(
              feedbackState: ProofQualityFeedbackState.notRelevant,
              confidenceLevel: ProofConfidenceLevel.useful,
            ),
          ),
        ).allowed,
        isFalse,
      );
    });

    test('hidden recording/degraded/WhatChanged/inbox', () {
      for (final override in [
        {'isRecording': true},
        {'isDegradedTranscriptState': true},
        {'whatChangedQuestionActive': true},
        {'patternReviewInboxHasActiveItems': true},
      ]) {
        expect(
          ProBridgeTimingLoosenEngine.evaluate(
            input: ProBridgeTimingLoosenEngine.fromVisibilityInput(
              _input(
                hasTimelineProofVisible: true,
                isRecording: override['isRecording'] ?? false,
                isDegradedTranscriptState:
                    override['isDegradedTranscriptState'] ?? false,
                whatChangedQuestionActive:
                    override['whatChangedQuestionActive'] ?? false,
                patternReviewInboxHasActiveItems:
                    override['patternReviewInboxHasActiveItems'] ?? false,
              ),
            ),
          ).allowed,
          isFalse,
        );
      }
    });
  });

  group('ProBridgeVisibilityCard loosen analytics', () {
    testWidgets('CTA opens existing paywall path', (tester) async {
      var openedPaywall = false;
      final result = ProBridgeVisibilityEngine.build(
        input: _input(
          hasTimelineProofVisible: true,
          confidenceLevel: ProofConfidenceLevel.useful,
          hasSafeAnchor: true,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProBridgeVisibilityCard(
              result: result,
              onSeePro: () => openedPaywall = true,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('pro_bridge_visibility_cta')));
      await tester.pump();
      expect(openedPaywall, isTrue);
    });

    testWidgets('Not now dismisses', (tester) async {
      var dismissed = false;
      final result = ProBridgeVisibilityEngine.build(
        input: _input(hasTimelineProofVisible: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProBridgeVisibilityCard(
              result: result,
              onSeePro: () {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('pro_bridge_visibility_dismiss')));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  group('ProBridgeTimingLoosenAnalytics', () {
    test('metadata-only analytics', () {
      Map<String, Object>? seenProps;
      ProBridgeTimingLoosenAnalytics.captureForTest = (event, props) {
        if (event == ProBridgeTimingLoosenAnalytics.seenEvent) {
          seenProps = props;
        }
      };
      ProBridgeTimingLoosenAnalytics.seen(
        source: 'record_ready',
        surface: 'record_ready',
        entryCount: 3,
        triggerReason:
            ProMomentTimingTrigger.usefulProofConfidence.analyticsValue,
        confidenceLevel: ProofConfidenceLevel.useful.analyticsValue,
        hasSafeAnchor: true,
      );
      expect(seenProps!.keys.toSet(), {
        'entry_count',
        'source',
        'surface',
        'trigger_reason',
        'confidence_level',
        'has_safe_anchor',
      });
      expect(seenProps!.containsKey('product_id'), isFalse);
    });
  });

  group('SurfacePriorityEngine', () {
    test('allows max one Pro slot', () {
      final result = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: 3,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          whatChanged: false,
          firstProofPayoff: true,
          returnPayoff: false,
          timelineProofMomentPostSave: true,
          proofSpecificityPostSave: false,
          betaProofFeedback: false,
          proBridgeVisibility: true,
          proEvidenceValue: true,
          proLockMoment: true,
          privateReportProBridge: true,
        ),
      );
      expect(result.proSlot, SurfacePriorityCardKey.proBridgeVisibility);
    });
  });

  group('Protected billing areas', () {
    test('no billing constants changed', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
      expect(
        File('lib/billing/revenuecat_service.dart').readAsStringSync(),
        isNot(contains('archive_loop_pro_monthly_v2')),
      );
    });

    test('restore purchases unchanged', () {
      expect(RestorePurchasesCopy.restorePurchases, 'Restore purchases');
    });

    test('copy uses loosened timeline language', () {
      expect(ProBridgeVisibilityCopy.title, 'Keep the longer trail');
      expect(ProBridgeVisibilityCopy.body, contains('first useful proof'));
    });

    test('timing engine does not reference billing product IDs', () {
      final source = File(
        'lib/features/pro_bridge_visibility/pro_bridge_timing_loosen_engine.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('proEntitlementId')));
      expect(source, isNot(contains('archive_loop_pro_monthly')));
    });
  });
}