import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_analytics.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_copy.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_engine.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/first_session_proof_repair/first_session_proof_repair_engine.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_copy.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_engine.dart';
import 'package:voicememory_mobile/features/pro_understanding_lift/pro_understanding_lift_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_engine.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/pro_visibility_lift/pro_visibility_lift_engine.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/beta/beta_repair_lab_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/beta_repair_lab/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

BetaRepairLabVisibilityInput _input({
  BetaRepairLabMode mode = BetaRepairLabMode.none,
  int entryCount = 4,
  bool hasTimelineProofVisible = true,
  bool hasConfirmedRepeat = true,
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.watchOnly,
  BetaProofFeedbackType? feedbackType,
  bool isNegativeFeedback = false,
  bool betaMissionEnabled = true,
}) => BetaRepairLabVisibilityInput(
  mode: mode,
  entryCount: entryCount,
  source: 'test',
  isPro: false,
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

void main() {
  setUp(() async {
    await BetaRepairLabStore.resetForTest(null);
    BetaRepairLabAnalytics.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaRepairLabStore.repairModeOverrideForTest = null;
  });

  group('BetaRepairLabBuildOverride', () {
    test(
      'default active mode is proof protection baseline in beta mission',
      () {
        expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
        expect(
          BetaRepairLabStore.activeMode,
          BetaRepairLabMode.proofSpecificityCaution,
        );
        expect(BetaRepairLabStore.isDefaultBaselineActive, isTrue);
        expect(
          BetaRepairLabEngine.defaultBaselineStatusLabel(),
          'Default beta baseline active: Proof protection',
        );
      },
    );

    test('default active mode is none outside beta mission', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(BetaRepairLabStore.activeMode, BetaRepairLabMode.none);
      expect(BetaRepairLabStore.isDefaultBaselineActive, isFalse);
    });

    test(
      'build override activates proPlacementAfterUsefulProof when beta mission is true',
      () {
        BetaRepairLabStore.repairModeOverrideForTest =
            'proPlacementAfterUsefulProof';
        expect(
          BetaRepairLabStore.buildOverrideMode,
          BetaRepairLabMode.proPlacementAfterUsefulProof,
        );
        expect(
          BetaRepairLabStore.activeMode,
          BetaRepairLabMode.proPlacementAfterUsefulProof,
        );
        expect(
          BetaRepairLabEngine.isRepairActive(
            BetaRepairLabMode.proPlacementAfterUsefulProof,
          ),
          isTrue,
        );
      },
    );

    test('build override activates paywallValue when beta mission is true', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'paywallValue';
      expect(
        BetaRepairLabStore.buildOverrideMode,
        BetaRepairLabMode.paywallValue,
      );
      expect(
        BetaRepairLabStore.buildOverrideActiveLabel,
        'Build override active: Paywall value repair',
      );
    });

    test(
      'build override activates pricingValueFraming when beta mission is true',
      () {
        BetaRepairLabStore.repairModeOverrideForTest = 'pricingValueFraming';
        expect(
          BetaRepairLabStore.buildOverrideMode,
          BetaRepairLabMode.pricingValueFraming,
        );
        expect(
          BetaRepairLabStore.buildOverrideActiveLabel,
          'Build override active: Pricing value framing',
        );
      },
    );

    test(
      'build override activates pricingValidation when beta mission is true',
      () {
        BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
        expect(
          BetaRepairLabStore.buildOverrideMode,
          BetaRepairLabMode.pricingValidation,
        );
        expect(
          BetaRepairLabStore.buildOverrideActiveLabel,
          'Build override active: Pricing validation',
        );
      },
    );

    test(
      'build override activates evidenceTrailTimelineClarity when beta mission is true',
      () {
        BetaRepairLabStore.repairModeOverrideForTest =
            'evidenceTrailTimelineClarity';
        expect(
          BetaRepairLabStore.buildOverrideMode,
          BetaRepairLabMode.evidenceTrailTimelineClarity,
        );
        expect(
          BetaRepairLabStore.buildOverrideActiveLabel,
          'Build override active: Evidence trail timeline clarity',
        );
      },
    );

    test('build override ignored when beta mission is false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      BetaRepairLabStore.repairModeOverrideForTest =
          'proPlacementAfterUsefulProof';
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(BetaRepairLabStore.activeMode, BetaRepairLabMode.none);
    });

    test('invalid build override falls back to proof protection in beta', () {
      BetaRepairLabStore.repairModeOverrideForTest = 'not_a_real_repair_mode';
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(
        BetaRepairLabStore.activeMode,
        BetaRepairLabMode.proofSpecificityCaution,
      );
      expect(BetaRepairLabStore.isDefaultBaselineActive, isTrue);
    });

    test('invalid build override falls back to none outside beta', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      BetaRepairLabStore.repairModeOverrideForTest = 'not_a_real_repair_mode';
      expect(BetaRepairLabStore.buildOverrideMode, BetaRepairLabMode.none);
      expect(BetaRepairLabStore.activeMode, BetaRepairLabMode.none);
    });

    test(
      'build override takes precedence over local stored selection',
      () async {
        BetaRepairLabStore.repairModeOverrideForTest =
            'proPlacementAfterUsefulProof';
        await BetaRepairLabStore.setModeForTest(
          BetaRepairLabMode.openingScreenSimplification,
        );
        expect(
          BetaRepairLabStore.localMode,
          BetaRepairLabMode.openingScreenSimplification,
        );
        expect(
          BetaRepairLabStore.activeMode,
          BetaRepairLabMode.proPlacementAfterUsefulProof,
        );
      },
    );

    test('testing screen build override label', () {
      BetaRepairLabStore.repairModeOverrideForTest =
          'proPlacementAfterUsefulProof';
      expect(
        BetaRepairLabEngine.buildOverrideStatusLabel(),
        'Build override active: Pro placement after useful proof',
      );
      final state = BetaRepairLabEngine.currentState();
      expect(state.buildOverrideActive, isTrue);
      expect(state.defaultBaselineActive, isFalse);
      expect(
        state.buildOverrideLabel,
        'Build override active: Pro placement after useful proof',
      );
      expect(state.warning, BetaRepairLabCopy.buildOverrideWarning);
    });

    test('testing screen default baseline label', () {
      final state = BetaRepairLabEngine.currentState();
      expect(state.buildOverrideActive, isFalse);
      expect(state.defaultBaselineActive, isTrue);
      expect(
        state.defaultBaselineStatusLabel,
        'Default beta baseline active: Proof protection',
      );
    });
  });

  group('BetaRepairLabStore', () {
    test('default mode is none', () {
      expect(BetaRepairLabStore.mode, BetaRepairLabMode.none);
    });

    test('selecting one mode clears previous mode', () async {
      final prefs = _MemoryPrefs();
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.openingScreenSimplification,
        prefs: prefs,
      );
      await BetaRepairLabStore.selectMode(
        BetaRepairLabMode.proExplanation,
        source: 'test',
      );
      expect(BetaRepairLabStore.mode, BetaRepairLabMode.proExplanation);
      await BetaRepairLabStore.selectMode(
        BetaRepairLabMode.none,
        source: 'test',
      );
      expect(BetaRepairLabStore.mode, BetaRepairLabMode.none);
    });
  });

  group('BetaRepairLabEngine opening repair', () {
    test('changes 0-entry copy only when active', () {
      final base = FirstSessionProofRepairEngine.buildCapture(
        entryCount: 0,
        source: 'record',
      );
      final override = BetaRepairLabEngine.openingCaptureOverride(
        base: base,
        betaMissionEnabled: true,
      );
      expect(override, isNull);

      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.openingScreenSimplification,
      );
      final active = BetaRepairLabEngine.openingCaptureOverride(
        base: base,
        betaMissionEnabled: true,
      );
      expect(active?.title, BetaRepairLabCopy.openingTitle);
      expect(active?.primaryCta, BetaRepairLabCopy.openingPrimaryCta);
      expect(active?.body, BetaRepairLabCopy.openingBody);
    });

    test('hidden after first save', () {
      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.openingScreenSimplification,
      );
      final base = FirstSessionProofRepairEngine.buildCapture(
        entryCount: 1,
        source: 'record',
      );
      expect(
        BetaRepairLabEngine.openingCaptureOverride(
          base: base,
          betaMissionEnabled: true,
        ),
        isNull,
      );
    });
  });

  group('BetaRepairLabEngine proof repair', () {
    test('proof protection baseline active without explicit selection', () {
      expect(
        BetaRepairLabEngine.isRepairActive(
          BetaRepairLabMode.proofSpecificityCaution,
        ),
        isTrue,
      );
      final result = BetaRepairLabEngine.buildProof(
        input: _input(
          mode: BetaRepairLabMode.proofSpecificityCaution,
          confidenceLevel: ProofConfidenceLevel.watchOnly,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.title, BetaRepairLabCopy.proofWeakTitle);
    });

    test('changes weak proof copy only when active', () {
      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.proofSpecificityCaution,
      );
      final result = BetaRepairLabEngine.buildProof(
        input: _input(
          mode: BetaRepairLabMode.proofSpecificityCaution,
          confidenceLevel: ProofConfidenceLevel.watchOnly,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.title, BetaRepairLabCopy.proofWeakTitle);
      expect(result.body, BetaRepairLabCopy.proofWeakBody);
      expect(result.feedbackPrompt, BetaRepairLabCopy.proofFeedbackPrompt);
      expect(result.whyAppearedLine, isEmpty);
    });

    test('strong proof includes why appeared line', () {
      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.proofSpecificityCaution,
      );
      final result = BetaRepairLabEngine.buildProof(
        input: _input(
          mode: BetaRepairLabMode.proofSpecificityCaution,
          confidenceLevel: ProofConfidenceLevel.strong,
          feedbackType: BetaProofFeedbackType.useful,
        ),
      );
      expect(result.whyAppearedLine, BetaRepairLabCopy.proofStrongWhyAppeared);
    });

    test('does not change proof thresholds', () {
      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.proofSpecificityCaution,
      );
      final input = ProofFloorRescueInput(
        entryCount: 4,
        source: 'test',
        isPro: false,
        hasTimelineProofVisible: true,
        hasConfirmedRepeat: true,
        confidenceLevel: ProofConfidenceLevel.watchOnly,
        hasSafeAnchor: false,
        hasLowMatchQuality: true,
        usefulFeedbackCount: 0,
        isRecording: false,
        isDegradedTranscriptState: false,
        whatChangedQuestionActive: false,
        patternReviewInboxHasActiveItems: false,
      );
      expect(ProofFloorRescueEngine.resolveState(input), isNotNull);
      expect(
        BetaRepairLabEngine.buildProof(
          input: _input(mode: BetaRepairLabMode.proofSpecificityCaution),
        ).shouldShow,
        isTrue,
      );
    });

    test('blocks Pro after weak proof with default baseline', () {
      expect(
        BetaRepairLabEngine.blocksProWhenProofProtectionActive(
          input: _input(
            mode: BetaRepairLabMode.proofSpecificityCaution,
            confidenceLevel: ProofConfidenceLevel.watchOnly,
          ),
        ),
        isTrue,
      );
    });

    test('blocks Pro after Too vague / Not relevant with default baseline', () {
      for (final type in [
        BetaProofFeedbackType.tooVague,
        BetaProofFeedbackType.notRelevant,
      ]) {
        expect(
          BetaRepairLabEngine.blocksProWhenProofProtectionActive(
            input: _input(
              mode: BetaRepairLabMode.proofSpecificityCaution,
              confidenceLevel: ProofConfidenceLevel.strong,
              feedbackType: type,
              isNegativeFeedback: true,
            ),
          ),
          isTrue,
        );
      }
    });

    test('blocks Pro after weak proof', () {
      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.proofSpecificityCaution,
      );
      expect(
        BetaRepairLabEngine.blocksProWhenProofRepairActive(
          input: _input(
            mode: BetaRepairLabMode.proofSpecificityCaution,
            confidenceLevel: ProofConfidenceLevel.watchOnly,
          ),
          showProofRepair: true,
        ),
        isTrue,
      );
    });
  });

  group('BetaRepairLabEngine pro placement repair', () {
    test('Pro placement only after strong useful proof', () {
      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.proPlacementAfterUsefulProof,
      );
      expect(
        BetaRepairLabEngine.shouldShowProPlacement(
          input: _input(
            mode: BetaRepairLabMode.proPlacementAfterUsefulProof,
            confidenceLevel: ProofConfidenceLevel.watchOnly,
          ),
        ),
        isFalse,
      );
      final placement = BetaRepairLabEngine.buildProPlacement(
        input: _input(
          mode: BetaRepairLabMode.proPlacementAfterUsefulProof,
          confidenceLevel: ProofConfidenceLevel.strong,
          feedbackType: BetaProofFeedbackType.useful,
        ),
      );
      expect(placement.shouldShow, isTrue);
      expect(placement.title, BetaRepairLabCopy.proPlacementTitle);
      expect(placement.body, BetaRepairLabCopy.proPlacementBody);
      expect(placement.primaryCta, BetaRepairLabCopy.proPlacementPrimaryCta);
    });

    test('blocks Pro after Too vague / Not relevant', () {
      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.proPlacementAfterUsefulProof,
      );
      for (final type in [
        BetaProofFeedbackType.tooVague,
        BetaProofFeedbackType.notRelevant,
      ]) {
        expect(
          BetaRepairLabEngine.shouldShowProPlacement(
            input: _input(
              mode: BetaRepairLabMode.proPlacementAfterUsefulProof,
              confidenceLevel: ProofConfidenceLevel.strong,
              feedbackType: type,
              isNegativeFeedback: true,
            ),
          ),
          isFalse,
        );
      }
    });
  });

  group('BetaRepairLabEngine pro explanation repair', () {
    test('changes explanation copy but not placement eligibility', () {
      BetaRepairLabStore.setModeForTest(BetaRepairLabMode.proExplanation);
      final base = ProUnderstandingLiftEngine.build(
        input: ProUnderstandingLiftVisibilityInput(
          surface: ProUnderstandingLiftSurface.recordReady,
          source: 'record_ready',
          entryCount: 4,
          isPro: false,
          hasUsefulProof: true,
          confidenceLevel: ProofConfidenceLevel.strong,
          feedbackState: ProofQualityFeedbackState.useful,
          hasProEngagement: false,
          hasFreshReturnAfterCorrection: false,
          hasChangeAnchor: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
      );
      final override = BetaRepairLabEngine.applyProExplanationCopy(
        base: base,
        betaMissionEnabled: true,
      );
      expect(override?.title, BetaRepairLabCopy.proExplanationTitle);
      expect(override?.body, BetaRepairLabCopy.proExplanationBody);
      expect(override?.primaryCta, BetaRepairLabCopy.proExplanationPrimaryCta);
      expect(base.shouldShow, override?.shouldShow);
      expect(base.surface, override?.surface);
    });
  });

  group('production safety', () {
    test('no repair changes when beta mode off', () {
      BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.openingScreenSimplification,
      );
      final base = FirstSessionProofRepairEngine.buildCapture(
        entryCount: 0,
        source: 'record',
      );
      expect(
        BetaRepairLabEngine.openingCaptureOverride(
          base: base,
          betaMissionEnabled: false,
        ),
        isNull,
      );
    });

    test('production default mode behavior unchanged when beta off', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(BetaRepairLabStore.mode, BetaRepairLabMode.none);
      expect(BetaRepairLabStore.activeMode, BetaRepairLabMode.none);
      expect(
        BetaRepairLabEngine.shouldShowProof(
          input: _input(
            mode: BetaRepairLabMode.none,
            betaMissionEnabled: false,
          ),
        ),
        isFalse,
      );
      expect(
        BetaRepairLabEngine.shouldShowProPlacement(
          input: _input(
            mode: BetaRepairLabMode.none,
            betaMissionEnabled: false,
          ),
        ),
        isFalse,
      );
    });

    test('pro visibility lift eligibility unchanged without repair', () {
      expect(
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: 4,
          isPro: false,
          hasUsefulProof: true,
          confidenceLevel: ProofConfidenceLevel.strong,
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

  group('analytics', () {
    test('metadata-only analytics', () {
      final events = <String, Map<String, Object>>{};
      BetaRepairLabAnalytics.captureForTest = (event, props) {
        events[event] = props;
      };
      BetaRepairLabAnalytics.modeSelected(
        source: 'testing_archiveme',
        selectedMode: BetaRepairLabMode.proExplanation,
        previousMode: BetaRepairLabMode.none,
      );
      final props = events[BetaRepairLabAnalytics.modeSelectedEvent]!;
      expect(
        props.keys,
        containsAll(['source', 'selected_mode', 'previous_mode']),
      );
      expect(props['source'], 'testing_archiveme');
      expect(props['selected_mode'], 'pro_explanation');
      expect(props['previous_mode'], 'none');
      for (final value in props.values) {
        expect(value.toString().toLowerCase(), isNot(contains('journal')));
      }
    });
  });

  group('copy guard', () {
    test('no private journal text in copy or analytics metadata', () {
      for (final line in BetaRepairLabCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('BetaRepairLabCard', () {
    test('only beta/testing screen shows repair lab', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        BetaRepairLabEngine.shouldShowLab(betaMissionEnabled: false),
        isFalse,
      );

      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaRepairLabEngine.shouldShowLab(betaMissionEnabled: true),
        isTrue,
      );
    });

    testWidgets('testing screen renders active mode and warning', (
      tester,
    ) async {
      await BetaRepairLabStore.setModeForTest(
        BetaRepairLabMode.proofSpecificityCaution,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BetaRepairLabCard(source: 'testing_archiveme')),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('beta_repair_lab_card')), findsOneWidget);
      expect(
        find.byKey(const Key('beta_repair_lab_active_mode')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('beta_repair_lab_warning')), findsOneWidget);
      expect(
        find.textContaining('Proof specificity and caution'),
        findsWidgets,
      );
      expect(find.text(BetaRepairLabCopy.warning), findsOneWidget);
    });

    testWidgets('shows build override active on repair lab card', (
      tester,
    ) async {
      BetaRepairLabStore.repairModeOverrideForTest =
          'proPlacementAfterUsefulProof';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BetaRepairLabCard(source: 'testing_archiveme')),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('beta_repair_lab_build_override_active')),
        findsOneWidget,
      );
      expect(
        find.text('Build override active: Pro placement after useful proof'),
        findsOneWidget,
      );
      expect(find.text(BetaRepairLabCopy.buildOverrideWarning), findsOneWidget);
    });

    testWidgets('hidden when beta mission disabled', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BetaRepairLabCard(source: 'testing_archiveme')),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('beta_repair_lab_card_hidden')),
        findsOneWidget,
      );
    });
  });
}
