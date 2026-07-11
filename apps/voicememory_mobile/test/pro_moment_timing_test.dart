import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/features/pro_moment_timing/pro_moment_timing_analytics.dart';
import 'package:voicememory_mobile/features/pro_moment_timing/pro_moment_timing_copy.dart';
import 'package:voicememory_mobile/features/pro_moment_timing/pro_moment_timing_engine.dart';
import 'package:voicememory_mobile/features/pro_moment_timing/pro_moment_timing_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

ProMomentTimingContext _baseContext({
  int entryCount = 3,
  bool hasFirstProof = true,
  bool hasTimelineProofVisible = false,
  bool hasFirstProofPayoffVisible = false,
  bool hasBetaTesterReportVisible = false,
  bool hasMonthlyPrivateReportPreviewVisible = false,
  bool hasCorrectionMemoryVisible = false,
  ProofQualityFeedbackState feedbackState = ProofQualityFeedbackState.none,
  bool isRecording = false,
  bool isZeroEntryState = false,
  bool isFirstRecordingState = false,
  bool isPostSaveDegradedState = false,
  bool isDegradedTranscriptState = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  bool proSlotAvailable = true,
  bool hasBetaProofLiftVisible = false,
  bool hasReturnAfterProofStrengthenedVisible = false,
  ProofConfidenceLevel? confidenceLevel,
  bool hasSafeAnchor = false,
  bool hasFreshReturnAfterCorrection = false,
  bool hasSolidStrongPatternWithSafeAnchors = false,
}) {
  return ProMomentTimingContext(
    surface: ProMomentTimingSurface.recordPostSave,
    source: 'test',
    entryCount: entryCount,
    isRecording: isRecording,
    isZeroEntryState: isZeroEntryState,
    isFirstRecordingState: isFirstRecordingState,
    isPostSaveDegradedState: isPostSaveDegradedState,
    isDegradedTranscriptState: isDegradedTranscriptState,
    hasFirstProof: hasFirstProof,
    hasTimelineProofVisible: hasTimelineProofVisible,
    hasFirstProofPayoffVisible: hasFirstProofPayoffVisible,
    hasBetaTesterReportVisible: hasBetaTesterReportVisible,
    hasMonthlyPrivateReportPreviewVisible:
        hasMonthlyPrivateReportPreviewVisible,
    hasCorrectionMemoryVisible: hasCorrectionMemoryVisible,
    feedbackState: feedbackState,
    whatChangedQuestionActive: whatChangedQuestionActive,
    patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    proSlotAvailable: proSlotAvailable,
    hasBetaProofLiftVisible: hasBetaProofLiftVisible,
    hasReturnAfterProofStrengthenedVisible:
        hasReturnAfterProofStrengthenedVisible,
    confidenceLevel: confidenceLevel,
    hasSafeAnchor: hasSafeAnchor,
    hasFreshReturnAfterCorrection: hasFreshReturnAfterCorrection,
    hasSolidStrongPatternWithSafeAnchors:
        hasSolidStrongPatternWithSafeAnchors,
  );
}

void main() {
  setUp(ProMomentTimingAnalytics.resetForTest);

  group('ProMomentTimingCopy', () {
    test('uses longer proof trail language', () {
      expect(ProMomentTimingCopy.headline, 'Keep the longer proof trail');
      expect(
        ProMomentTimingCopy.body,
        PaywallAlignmentCopy.body,
      );
      expect(
        ProMomentTimingCopy.compactLine,
        'Pro keeps the longer proof trail over time.',
      );
      expect(
        ProMomentTimingCopy.coreRule,
        'Free shows the first useful proof. Pro keeps the longer proof trail over time.',
      );
    });
  });

  group('ProMomentTimingEngine blocked moments', () {
    test('blocks before first save', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(entryCount: 0, isZeroEntryState: true, hasFirstProof: false),
      );
      expect(result.allowed, isFalse);
      expect(
        result.blockedReason,
        ProMomentTimingBlockedReason.beforeFirstSave,
      );
    });

    test('blocks before first proof', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(hasFirstProof: false, hasFirstProofPayoffVisible: false),
      );
      expect(result.allowed, isFalse);
      expect(
        result.blockedReason,
        ProMomentTimingBlockedReason.beforeFirstProof,
      );
    });

    test('blocks while recording', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(isRecording: true, hasFirstProofPayoffVisible: true),
      );
      expect(result.allowed, isFalse);
      expect(result.blockedReason, ProMomentTimingBlockedReason.recording);
    });

    test('blocks degraded post-save', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(
          isPostSaveDegradedState: true,
          hasFirstProofPayoffVisible: true,
        ),
      );
      expect(result.allowed, isFalse);
      expect(
        result.blockedReason,
        ProMomentTimingBlockedReason.postSaveDegraded,
      );
    });

    test('blocks after Too vague feedback', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(
          feedbackState: ProofQualityFeedbackState.tooVague,
          hasFirstProofPayoffVisible: true,
        ),
      );
      expect(result.allowed, isFalse);
      expect(
        result.blockedReason,
        ProMomentTimingBlockedReason.feedbackTooVague,
      );
    });

    test('blocks after Not relevant feedback', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(
          feedbackState: ProofQualityFeedbackState.notRelevant,
          hasFirstProofPayoffVisible: true,
        ),
      );
      expect(result.allowed, isFalse);
      expect(
        result.blockedReason,
        ProMomentTimingBlockedReason.feedbackNotRelevant,
      );
    });

    test('blocks during WhatChanged', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(
          whatChangedQuestionActive: true,
          hasFirstProofPayoffVisible: true,
        ),
      );
      expect(result.allowed, isFalse);
      expect(
        result.blockedReason,
        ProMomentTimingBlockedReason.whatChangedActive,
      );
    });

    test('blocks when Pro slot already used', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(
          hasFirstProofPayoffVisible: true,
          proSlotAvailable: false,
        ),
      );
      expect(result.allowed, isFalse);
      expect(
        result.blockedReason,
        ProMomentTimingBlockedReason.proSlotAlreadyUsed,
      );
    });
  });

  group('ProMomentTimingEngine allowed moments', () {
    test('allows after TimelineProofMoment', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(hasTimelineProofVisible: true),
      );
      expect(result.allowed, isTrue);
      expect(result.trigger, ProMomentTimingTrigger.timelineProofMoment);
    });

    test('allows after FirstProofPayoff', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(hasFirstProofPayoffVisible: true),
      );
      expect(result.allowed, isTrue);
      expect(result.trigger, ProMomentTimingTrigger.firstProofPayoff);
    });

    test('allows after BetaTesterReport', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(hasBetaTesterReportVisible: true),
      );
      expect(result.allowed, isTrue);
      expect(result.trigger, ProMomentTimingTrigger.betaTesterReport);
    });

    test('allows after Useful feedback', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(feedbackState: ProofQualityFeedbackState.useful),
      );
      expect(result.allowed, isTrue);
      expect(result.trigger, ProMomentTimingTrigger.usefulFeedback);
    });

    test('allows after useful proof confidence loosen trigger', () {
      final result = ProMomentTimingEngine.evaluate(
        _baseContext(
          confidenceLevel: ProofConfidenceLevel.useful,
          hasSafeAnchor: true,
        ),
      );
      expect(result.allowed, isTrue);
      expect(result.trigger, ProMomentTimingTrigger.usefulProofConfidence);
    });
  });

  group('ProMomentTimingAnalytics', () {
    test('emits metadata only on allowed', () {
      Map<String, Object>? captured;
      ProMomentTimingAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      ProMomentTimingAnalytics.allowed(
        source: 'record_post_save',
        surface: 'record_post_save',
        entryCount: 3,
        reason: 'first_proof_payoff',
        hasTimelineProof: false,
        feedbackState: 'none',
      );

      expect(captured, isNotNull);
      expect(captured!.keys.toSet(), {
        'source',
        'surface',
        'entry_count',
        'reason',
        'has_timeline_proof',
        'feedback_state',
      });
    });

    test('applyGate emits blocked analytics when candidate is true', () {
      final events = <String>[];
      ProMomentTimingAnalytics.captureForTest = (event, props) {
        events.add(event);
      };

      final allowed = ProMomentTimingEngine.applyGate(
        candidate: true,
        timing: _baseContext(
          feedbackState: ProofQualityFeedbackState.tooVague,
          hasFirstProofPayoffVisible: true,
        ),
      );

      expect(allowed, isFalse);
      expect(events, contains(ProMomentTimingAnalytics.blockedEvent));
      expect(events, isNot(contains(ProMomentTimingAnalytics.seenEvent)));
    });
  });

  group('SurfacePriorityEngine Pro slot cap', () {
    test('allows max one Pro slot on record post save', () {
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
          proEvidenceValue: true,
          proLockMoment: true,
          privateReportProBridge: true,
        ),
      );

      final proVisible = result.visibleCardKeys
          .where(
            (key) =>
                key == SurfacePriorityCardKey.proBridgeVisibility ||
                key == SurfacePriorityCardKey.proEvidenceValue ||
                key == SurfacePriorityCardKey.proLockMoment ||
                key == SurfacePriorityCardKey.privateReportProBridge,
          )
          .length;
      expect(proVisible, 1);
      expect(result.proSlot, isNotNull);
    });
  });

  group('Protected billing areas', () {
    test('entitlement IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('billing constants not referenced by timing module', () {
      final source =
          File('lib/features/pro_moment_timing/pro_moment_timing_engine.dart')
              .readAsStringSync();
      expect(source, isNot(contains('proEntitlementId')));
      expect(source, isNot(contains('archive_loop_pro_monthly')));
    });
  });
}
