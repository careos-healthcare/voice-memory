import 'dart:io';

import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/first_save_lift/first_save_lift_engine.dart';
import 'package:archiveme_mobile/features/paywall_cta_lift/paywall_cta_lift_copy.dart';
import 'package:archiveme_mobile/features/paywall_cta_lift/paywall_cta_lift_engine.dart';
import 'package:archiveme_mobile/features/pro_visibility_lift/pro_visibility_lift_copy.dart';
import 'package:archiveme_mobile/features/pro_visibility_lift/pro_visibility_lift_engine.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_analytics.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_engine.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_model.dart';
import 'package:archiveme_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'package:archiveme_mobile/features/second_moment_return/second_moment_return_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/pro/paywall_cta_lift_block.dart';
import 'package:archiveme_mobile/widgets/record/first_save_lift_card.dart';
import 'package:archiveme_mobile/widgets/record/second_moment_return_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _privateTranscript =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? _now,
      transcript: transcript,
      durationSeconds: 24,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _threeRelatedEntries() => [
  _entry(
    '1',
    _privateTranscript,
    createdAt: _now.subtract(const Duration(days: 2)),
  ),
  _entry(
    '2',
    'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: _now.subtract(const Duration(days: 1)),
  ),
  _entry(
    '3',
    'I said yes again even though I had no capacity for one more ask.',
    createdAt: _now,
  ),
];

void main() {
  setUp(() {
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    RevenueLiftExperimentV2Analytics.resetForTest();
  });

  group('RevenueLiftExperimentV2Copy', () {
    test('first save copy renders sharper copy', () {
      expect(
        RevenueLiftExperimentV2Copy.firstSaveTitle,
        'Save the moment that keeps pulling at you',
      );
      expect(
        RevenueLiftExperimentV2Copy.firstSaveBody,
        contains('what comes back'),
      );
      expect(
        RevenueLiftExperimentV2Copy.firstSavePrimaryCta,
        'Type one sentence',
      );
      expect(
        RevenueLiftExperimentV2Copy.firstSaveSecondaryCta,
        'Record instead',
      );
    });

    test('pro visibility copy uses proof-connected framing', () {
      expect(
        ProVisibilityLiftCopy.title,
        RevenueLiftExperimentV2Copy.proVisibilityTitle,
      );
      expect(ProVisibilityLiftCopy.body, contains('first useful proof'));
    });

    test('no private journal text appears in copy', () {
      for (final line in RevenueLiftExperimentV2Copy.allVisibleStrings()) {
        expect(line, isNot(contains(_privateTranscript)));
        expect(line.toLowerCase(), isNot(contains('transcript')));
        expect(line.toLowerCase(), isNot(contains('journal_entry')));
      }
    });
  });

  group('First save card', () {
    testWidgets('renders sharpened first save copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstSaveLiftCard.test(
              result: FirstSaveLiftEngine.build(entryCount: 0, source: 'test'),
              onTypeOneSentence: () {},
              onRecordInstead: () {},
              onExampleSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(RevenueLiftExperimentV2Copy.firstSaveTitle),
        findsOneWidget,
      );
      expect(
        find.text(RevenueLiftExperimentV2Copy.firstSaveBody),
        findsOneWidget,
      );
    });
  });

  group('Return reason copy', () {
    test('visible at one entry', () {
      final result = SecondMomentReturnEngine.build(
        entries: [_entry('1', 'Something worth saving.')],
        source: 'test',
        now: _now,
      );
      expect(
        result.returnReasonLine,
        RevenueLiftExperimentV2Copy.returnReasonLine,
      );
    });

    test('visible at two entries', () {
      final result = SecondMomentReturnEngine.build(
        entries: [_entry('1', 'First moment.'), _entry('2', 'Second moment.')],
        source: 'test',
        now: _now,
      );
      expect(
        result.returnReasonLine,
        RevenueLiftExperimentV2Copy.returnReasonLine,
      );
    });

    testWidgets('renders return reason line on card', (tester) async {
      final result = SecondMomentReturnEngine.build(
        entries: [_entry('1', 'Something worth saving.')],
        source: 'test',
        now: _now,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondMomentReturnCard.test(
              result: result,
              onNoticedSomething: () {},
              onPromptSelected: (_) {},
              onSaveOneSentence: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(RevenueLiftExperimentV2Copy.returnReasonLine),
        findsOneWidget,
      );
    });
  });

  group('Proof payoff sharpen', () {
    test('visible after useful proof', () {
      final timeline = TimelineProofMomentEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(timeline, isNotNull);
      expect(timeline!.title, RevenueLiftExperimentV2Copy.proofPayoffTitle);
      expect(timeline.body, RevenueLiftExperimentV2Copy.proofPayoffBody);
    });

    test('engine returns sharpened copy for strong proof', () {
      final copy = RevenueLiftExperimentV2Engine.proofPayoffCopyFor(
        level: ProofConfidenceLevel.strong,
      );
      expect(copy?.title, RevenueLiftExperimentV2Copy.proofPayoffTitle);
      expect(copy?.body, RevenueLiftExperimentV2Copy.proofPayoffBody);
    });
  });

  group('Paywall CTA lift', () {
    test('block shows only for PaywallSource.valueMoment', () {
      expect(
        PaywallCtaLiftEngine.shouldShowBlock(
          source: PaywallSource.valueMoment,
          isPro: false,
        ),
        isTrue,
      );
      expect(
        PaywallCtaLiftEngine.shouldShowBlock(
          source: PaywallSource.generalPro,
          isPro: false,
        ),
        isFalse,
      );
    });

    testWidgets('renders sharpened paywall block copy', (tester) async {
      final result = PaywallCtaLiftEngine.build(
        source: PaywallSource.valueMoment,
        analyticsSource: 'test',
        isPro: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PaywallCtaLiftBlock.test(result: result)),
        ),
      );
      await tester.pump();

      expect(find.text(PaywallCtaLiftCopy.title), findsOneWidget);
      expect(find.text(PaywallCtaLiftCopy.supportLine), findsOneWidget);
    });

    testWidgets('purchase line appears above purchase CTA for valueMoment', (
      tester,
    ) async {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      final purchaseLineIndex = source.indexOf(
        'paywall_cta_lift_purchase_line',
      );
      final purchaseButtonIndex = source.indexOf(
        'onPressed: _busy ? null : _continue',
      );
      expect(purchaseLineIndex, greaterThan(0));
      expect(purchaseButtonIndex, greaterThan(purchaseLineIndex));
      expect(
        PaywallCtaLiftEngine.build(
          source: PaywallSource.valueMoment,
          analyticsSource: 'test',
          isPro: false,
        ).purchaseCtaLine,
        PaywallCtaLiftCopy.purchaseCtaLine,
      );
    });

    testWidgets('purchase line hidden for general Pro source', (tester) async {
      expect(
        PaywallCtaLiftEngine.build(
          source: PaywallSource.generalPro,
          analyticsSource: 'test',
          isPro: false,
        ).shouldShow,
        isFalse,
      );
    });
  });

  group('Dashboard lift focus', () {
    test('chooses paywall_cta when CTA tap is 4%', () {
      final focus = RevenueLiftExperimentV2Engine.resolveLiftFocus(
        const RevenueReadinessDashboardV2Input(
          paywallSeen: 25,
          paywallCtaTapped: 1,
        ),
      );
      expect(focus.focus, RevenueLiftExperimentV2Focus.paywallCta);
    });
  });

  group('RevenueLiftExperimentV2Analytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      RevenueLiftExperimentV2Analytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      RevenueLiftExperimentV2Analytics.seen(
        context: const RevenueLiftExperimentV2SeenContext(
          source: 'test',
          surface: 'record_screen',
          entryCount: 0,
          area: RevenueLiftExperimentV2Area.firstSave,
        ),
      );
      RevenueLiftExperimentV2Analytics.ctaTapped(
        context: const RevenueLiftExperimentV2CtaContext(
          source: 'test',
          surface: 'record_screen',
          entryCount: 0,
          area: RevenueLiftExperimentV2Area.firstSave,
        ),
      );
      RevenueLiftExperimentV2Analytics.paywallSeen(
        context: const RevenueLiftExperimentV2PaywallSeenContext(
          source: 'value_moment',
          surface: 'paywall_screen',
          entryCount: 3,
        ),
      );

      expect(events, [
        RevenueLiftExperimentV2Analytics.seenEvent,
        RevenueLiftExperimentV2Analytics.ctaTappedEvent,
        RevenueLiftExperimentV2Analytics.paywallSeenEvent,
      ]);
      for (final props in properties) {
        expect(RevenueLiftExperimentV2Analytics.isMetadataOnly(props), isTrue);
        expect(props.containsKey('transcript'), isFalse);
      }
    });
  });

  group('Surface priority pro cap', () {
    test('allows only one Pro card per surface', () {
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
      expect(
        result.isVisible(SurfacePriorityCardKey.proPreview, candidate: true),
        isFalse,
      );
    });
  });

  group('Protected integration areas', () {
    test('does not change purchase button wiring', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('FilledButton'));
      expect(source, contains('paywall_cta_lift_purchase_line'));
      expect(source, contains('RestorePurchasesCopy'));
    });

    test('pro visibility engine still gates on useful proof', () {
      expect(
        ProVisibilityLiftEngine.shouldShowCard(
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
        ),
        isTrue,
      );
    });
  });
}