import 'dart:io';

import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/pro_visibility_lift/pro_visibility_lift_analytics.dart';
import 'package:archiveme_mobile/features/pro_visibility_lift/pro_visibility_lift_copy.dart';
import 'package:archiveme_mobile/features/pro_visibility_lift/pro_visibility_lift_engine.dart';
import 'package:archiveme_mobile/features/pro_visibility_lift/pro_visibility_lift_model.dart';
import 'package:archiveme_mobile/features/pro_visibility_lift/pro_visibility_lift_store.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/pro/pro_visibility_lift_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/pro_visibility_lift/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

ProVisibilityLiftResult _allowedResult() => ProVisibilityLiftEngine.build(
  surface: ProVisibilityLiftSurface.recordReady,
  source: 'test',
  entryCount: 4,
  isPro: false,
  hasUsefulProof: true,
  confidenceLevel: ProofConfidenceLevel.useful,
  feedbackState: ProofQualityFeedbackState.useful,
  hasPaywallSeen: false,
  hasFreshReturnAfterCorrection: false,
  hasChangeAnchor: false,
  isRecording: false,
  isDegradedTranscriptState: false,
  isPostSaveDegradedState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
);

void main() {
  setUp(() async {
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    ProVisibilityLiftAnalytics.resetForTest();
    await ProVisibilityLiftStore.resetForTest(_MemoryPrefs());
  });

  group('ProVisibilityLiftCopy', () {
    test('uses compact pro bridge copy', () {
      expect(ProVisibilityLiftCopy.title, 'Keep the longer trail');
      expect(
        ProVisibilityLiftCopy.body,
        'Free shows the first useful proof. Pro keeps tracking whether this pattern returns, changes, fades, or needs correcting.',
      );
      expect(ProVisibilityLiftCopy.primaryCta, 'See Pro timeline');
      expect(ProVisibilityLiftCopy.secondaryCta, 'Not now');
    });
  });

  group('ProVisibilityLiftEngine', () {
    test('hidden when beta off', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(_allowedResult().shouldShow, isFalse);
    });

    test('hidden for Pro users', () {
      expect(
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: 4,
          isPro: true,
          hasUsefulProof: true,
          confidenceLevel: ProofConfidenceLevel.useful,
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
        isFalse,
      );
    });

    test('hidden after paywall seen', () {
      expect(
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: 4,
          isPro: false,
          hasUsefulProof: true,
          confidenceLevel: ProofConfidenceLevel.useful,
          feedbackState: ProofQualityFeedbackState.useful,
          hasPaywallSeen: true,
          hasFreshReturnAfterCorrection: false,
          hasChangeAnchor: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden after too vague feedback', () {
      expect(
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: 4,
          isPro: false,
          hasUsefulProof: true,
          confidenceLevel: ProofConfidenceLevel.useful,
          feedbackState: ProofQualityFeedbackState.tooVague,
          hasPaywallSeen: false,
          hasFreshReturnAfterCorrection: false,
          hasChangeAnchor: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });
  });

  group('ProVisibilityLiftCard', () {
    testWidgets('primary CTA invokes handler', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProVisibilityLiftCard.test(
              result: _allowedResult(),
              onSeePro: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('pro_visibility_lift_primary_cta')),
      );
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('ProVisibilityLiftAnalytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      ProVisibilityLiftAnalytics.captureForTest = (event, props) {
        events.add(event);
        expect(props.containsKey('source'), isTrue);
        expect(props.containsKey('surface'), isTrue);
        expect(props.containsKey('transcript'), isFalse);
      };

      final result = _allowedResult();
      ProVisibilityLiftAnalytics.seen(result: result);
      ProVisibilityLiftAnalytics.ctaTapped(result: result);

      expect(events, [
        ProVisibilityLiftAnalytics.seenEvent,
        ProVisibilityLiftAnalytics.ctaTappedEvent,
      ]);
    });
  });

  group('SurfacePriorityEngine pro visibility lift', () {
    test('wins pro slot over preview and bridge visibility', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordReady(
          proVisibilityLift: true,
          proBridgeVisibility: true,
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
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      expect(result.proSlot, SurfacePriorityCardKey.proVisibilityLift);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.proBridgeVisibility,
          candidate: true,
        ),
        isFalse,
      );
    });
  });

  group('Integration placement', () {
    test('patterns screen integrates pro visibility lift card', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(source, contains('ProVisibilityLiftCard'));
      expect(source, contains('patterns_pro_visibility_lift'));
    });
  });
}
