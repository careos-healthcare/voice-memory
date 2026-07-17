import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/restore_purchases_copy.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_analytics.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_copy.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import 'package:voicememory_mobile/features/pro_moment_timing/pro_moment_timing_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/pro/pro_bridge_visibility_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(file: File('test/tmp/pro_bridge_visibility/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

ProBridgeVisibilityInput _allowedInput({
  ProBridgeVisibilitySurface surface =
      ProBridgeVisibilitySurface.recordReady,
  int entryCount = 3,
  bool isPro = false,
  bool postProofProBridgeEnabled = true,
  bool hasFirstProof = true,
  bool hasTimelineProofVisible = true,
  bool hasFirstProofPayoffVisible = false,
  bool hasBetaTesterReportVisible = false,
  bool hasCorrectionMemoryVisible = false,
  bool hasBetaProofLiftVisible = false,
  bool hasReturnAfterProofStrengthenedVisible = false,
  ProofQualityFeedbackState feedbackState = ProofQualityFeedbackState.none,
  ProofConfidenceLevel? confidenceLevel,
  bool hasSafeAnchor = false,
  bool hasFreshReturnAfterCorrection = false,
  bool hasSolidStrongPatternWithSafeAnchors = false,
  bool isRecording = false,
  bool isZeroEntryState = false,
  bool isFirstRecordingState = false,
  bool isPostSaveDegradedState = false,
  bool isDegradedTranscriptState = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  bool hasSeenFirstRepeat = true,
  bool hasOpenedEvidenceTrail = true,
}) =>
    ProBridgeVisibilityInput(
      surface: surface,
      source: 'test',
      entryCount: entryCount,
      isPro: isPro,
      postProofProBridgeEnabled: postProofProBridgeEnabled,
      hasFirstProof: hasFirstProof,
      hasTimelineProofVisible: hasTimelineProofVisible,
      hasFirstProofPayoffVisible: hasFirstProofPayoffVisible,
      hasBetaTesterReportVisible: hasBetaTesterReportVisible,
      hasCorrectionMemoryVisible: hasCorrectionMemoryVisible,
      hasBetaProofLiftVisible: hasBetaProofLiftVisible,
      hasReturnAfterProofStrengthenedVisible:
          hasReturnAfterProofStrengthenedVisible,
      feedbackState: feedbackState,
      confidenceLevel: confidenceLevel,
      hasSafeAnchor: hasSafeAnchor,
      hasFreshReturnAfterCorrection: hasFreshReturnAfterCorrection,
      hasSolidStrongPatternWithSafeAnchors:
          hasSolidStrongPatternWithSafeAnchors,
      isRecording: isRecording,
      isZeroEntryState: isZeroEntryState,
      isFirstRecordingState: isFirstRecordingState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      hasSeenFirstRepeat: hasSeenFirstRepeat,
      hasOpenedEvidenceTrail: hasOpenedEvidenceTrail,
    );

ProBridgeVisibilityResult _result({
  ProBridgeVisibilityInput? input,
}) =>
    ProBridgeVisibilityEngine.build(
      input: input ?? _allowedInput(),
    );

void main() {
  setUp(() async {
    ProBridgeVisibilityAnalytics.captureForTest = null;
    await ProEvidenceValueDismissStore.resetForTest();
    await BetaProofFeedbackStore.resetForTest(_MemoryPrefs());
  });

  group('ProBridgeVisibilityCopy', () {
    test('uses post-proof timeline copy', () {
      expect(ProBridgeVisibilityCopy.title, 'Keep the longer trail');
      expect(
        ProBridgeVisibilityCopy.body,
        'Free shows the first useful proof. Pro keeps tracking whether this pattern '
        'returns, changes, fades, or needs correcting.',
      );
      expect(
        ProBridgeVisibilityCopy.compactBody,
        'Pro keeps tracking whether this pattern returns, changes, or fades.',
      );
      expect(ProBridgeVisibilityCopy.cta, 'See Pro timeline');
      expect(ProBridgeVisibilityCopy.secondary, 'Not now');
    });
  });

  group('ProBridgeVisibilityEngine visibility', () {
    test('hidden before proof', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(hasFirstProof: false, hasTimelineProofVisible: false),
        ),
        isFalse,
      );
    });

    test('hidden before first repeat seen', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(hasSeenFirstRepeat: false),
        ),
        isFalse,
      );
    });

    test('hidden before evidence trail opened', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(hasOpenedEvidenceTrail: false),
        ),
        isFalse,
      );
    });

    test('hidden zero-entry', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(
            entryCount: 0,
            isZeroEntryState: true,
            hasFirstProof: false,
            hasTimelineProofVisible: false,
          ),
        ),
        isFalse,
      );
    });

    test('visible after TimelineProofMoment', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(hasTimelineProofVisible: true),
        ),
        isTrue,
      );
    });

    test('standalone bridge hidden on post-save first proof payoff surface', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(
            surface: ProBridgeVisibilitySurface.recordPostSaveAfterPayoff,
            hasTimelineProofVisible: false,
            hasFirstProofPayoffVisible: true,
          ),
        ),
        isFalse,
      );
    });

    test('visible after BetaTesterReport', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(
            hasTimelineProofVisible: false,
            hasBetaTesterReportVisible: true,
          ),
        ),
        isTrue,
      );
    });

    test('visible after Useful feedback', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(
            hasTimelineProofVisible: false,
            feedbackState: ProofQualityFeedbackState.useful,
          ),
        ),
        isTrue,
      );
    });

    test('hidden after Too vague feedback', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(
            feedbackState: ProofQualityFeedbackState.tooVague,
          ),
        ),
        isFalse,
      );
    });

    test('hidden after Not relevant feedback', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(
            feedbackState: ProofQualityFeedbackState.notRelevant,
          ),
        ),
        isFalse,
      );
    });

    test('hidden degraded', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(isDegradedTranscriptState: true),
        ),
        isFalse,
      );
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(
            surface: ProBridgeVisibilitySurface.recordPostSaveAfterPayoff,
            isPostSaveDegradedState: true,
            hasFirstProofPayoffVisible: true,
            hasTimelineProofVisible: false,
          ),
        ),
        isFalse,
      );
    });

    test('hidden recording', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(isRecording: true),
        ),
        isFalse,
      );
    });

    test('hidden during WhatChanged', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(whatChangedQuestionActive: true),
        ),
        isFalse,
      );
    });

    test('hidden during Pattern Review Inbox', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(patternReviewInboxHasActiveItems: true),
        ),
        isFalse,
      );
    });

    test('hidden for Pro subscribers', () {
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: _allowedInput(isPro: true),
        ),
        isFalse,
      );
    });
  });

  group('ProBridgeVisibilityCard', () {
    testWidgets('CTA routes through existing paywall handler', (tester) async {
      var openedPaywall = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProBridgeVisibilityCard(
              result: _result(),
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

    testWidgets('Not now dismisses through handler', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProBridgeVisibilityCard(
              result: _result(),
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

    test('dismiss store blocks visibility after Not now', () async {
      await ProBridgeVisibilityEngine.dismiss();
      expect(
        ProBridgeVisibilityEngine.shouldShow(input: _allowedInput()),
        isFalse,
      );
      expect(ProEvidenceValueDismissStore.isDismissed(), isTrue);
    });
  });

  group('ProBridgeVisibilityAnalytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      ProBridgeVisibilityAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      ProBridgeVisibilityAnalytics.seen(
        source: 'record_ready',
        surface: 'record_ready',
        entryCount: 3,
        triggerReason: ProMomentTimingTrigger.timelineProofMoment.analyticsValue,
        hasTimelineProof: true,
        feedbackState: ProofQualityFeedbackState.none.analyticsValue,
      );
      ProBridgeVisibilityAnalytics.ctaTapped(
        source: 'record_ready',
        surface: 'record_ready',
        entryCount: 3,
        triggerReason: ProMomentTimingTrigger.timelineProofMoment.analyticsValue,
        hasTimelineProof: true,
        feedbackState: ProofQualityFeedbackState.none.analyticsValue,
      );
      ProBridgeVisibilityAnalytics.dismissed(
        source: 'record_ready',
        surface: 'record_ready',
        entryCount: 3,
        triggerReason: ProMomentTimingTrigger.timelineProofMoment.analyticsValue,
        hasTimelineProof: true,
        feedbackState: ProofQualityFeedbackState.none.analyticsValue,
      );

      expect(events, [
        ProBridgeVisibilityAnalytics.seenEvent,
        ProBridgeVisibilityAnalytics.ctaTappedEvent,
        ProBridgeVisibilityAnalytics.dismissedEvent,
      ]);
      for (final props in properties) {
        expect(props.keys, containsAll([
          'entry_count',
          'source',
          'surface',
          'trigger_reason',
          'has_timeline_proof',
          'feedback_state',
        ]));
        expect(props.containsKey('product_id'), isFalse);
        expect(props.containsKey('price'), isFalse);
      }
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
          proBridgeVisibility: true,
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
      expect(result.proSlot, SurfacePriorityCardKey.proBridgeVisibility);
    });

    test('pro bridge visibility wins over evidence value on patterns', () {
      final result = SurfacePriorityEngine.auditPatterns(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.patterns(
          archiveBeliefSurface: true,
          timelineProofMoment: true,
          archiveTimelineSpine: true,
          betaTesterReport: true,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          patternConfidence: false,
          evidenceWeighting: false,
          currentRelevance: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          timelinePositioning: false,
          proBridgeVisibility: true,
          proEvidenceValue: true,
          archiveIntelligenceProBridge: true,
          privateReportProBridge: true,
          archiveBackupBridge: true,
          suppressLegacyEducation: false,
        ),
      );

      expect(result.proSlot, SurfacePriorityCardKey.proBridgeVisibility);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.proEvidenceValue,
          candidate: true,
        ),
        isFalse,
      );
      expect(result.hiddenReasons, contains(SurfacePriorityCopy.hiddenReasonProCap));
    });
  });

  group('Protected billing areas', () {
    test('entitlement IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('restore purchases unchanged', () {
      expect(RestorePurchasesCopy.restorePurchases, 'Restore purchases');
      expect(
        RestorePurchasesCopy.restoreScreenTitle,
        'Restore purchases',
      );
    });

    test('record screen routes Pro bridge through existing paywall handler', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source, contains('ProBridgeVisibilityCard'));
      expect(source, contains('_openProEvidenceValueSubscription'));
      expect(source, contains("context.push(\n      '/subscription'"));
      expect(source, isNot(contains('ProBridgeVisibilityPurchase')));
    });
  });
}
