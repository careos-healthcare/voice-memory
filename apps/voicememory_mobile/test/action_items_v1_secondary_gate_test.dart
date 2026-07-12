import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/action_items/archive_action_item.dart';
import 'package:voicememory_mobile/features/action_items_v1_gate/action_items_v1_secondary_gate.dart';
import 'package:voicememory_mobile/features/action_items_v1_gate/action_items_v1_secondary_gate_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/feature_noise_reduction/feature_noise_reduction.dart';
import 'package:voicememory_mobile/features/first_five_minutes/first_five_minutes_simplification.dart';
import 'package:voicememory_mobile/features/no_dashboard_positioning/no_dashboard_positioning_guard.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/proof_trail_positioning/proof_trail_positioning.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/v1_surface_scope/v1_surface_scope_audit.dart';

ActionItemsV1SecondaryGateInput _input({
  bool actionItemsSecondary = true,
  bool hiddenInFirstFiveMinutes = true,
  bool notInProPromise = true,
  bool notBlockingFirstProof = true,
  bool notRequiredOnboarding = true,
  bool notTaskManagementPositioning = true,
  bool userConfirmedAccessOnly = true,
  bool noExpansionGuarded = true,
}) =>
    ActionItemsV1SecondaryGateInput(
      actionItemsSecondary: actionItemsSecondary,
      hiddenInFirstFiveMinutes: hiddenInFirstFiveMinutes,
      notInProPromise: notInProPromise,
      notBlockingFirstProof: notBlockingFirstProof,
      notRequiredOnboarding: notRequiredOnboarding,
      notTaskManagementPositioning: notTaskManagementPositioning,
      userConfirmedAccessOnly: userConfirmedAccessOnly,
      noExpansionGuarded: noExpansionGuarded,
    );

void main() {
  group('ActionItemsV1SecondaryGate.build', () {
    test('gate has eight canonical checks', () {
      final result = ActionItemsV1SecondaryGate.build(_input());
      expect(result.checks, hasLength(ActionItemsV1SecondaryGate.checkCount));
    });

    test('all checks pass -> actionItemsSecondaryOk', () {
      final result = ActionItemsV1SecondaryGate.build(_input());
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsSecondaryOk,
      );
      expect(result.violatesGate, isFalse);
    });

    test('action items in core tab -> actionItemsViolatesGate', () {
      final result = ActionItemsV1SecondaryGate.build(
        _input(actionItemsSecondary: false),
      );
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate,
      );
      expect(result.violatesGate, isTrue);
    });

    test('shown in first five minutes by default -> actionItemsViolatesGate', () {
      final result = ActionItemsV1SecondaryGate.build(
        _input(hiddenInFirstFiveMinutes: false),
      );
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate,
      );
    });

    test('part of Pro promise -> actionItemsViolatesGate', () {
      final result = ActionItemsV1SecondaryGate.build(
        _input(notInProPromise: false),
      );
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate,
      );
    });

    test('blocks first proof -> actionItemsViolatesGate', () {
      final result = ActionItemsV1SecondaryGate.build(
        _input(notBlockingFirstProof: false),
      );
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate,
      );
    });

    test('required onboarding -> actionItemsViolatesGate', () {
      final result = ActionItemsV1SecondaryGate.build(
        _input(notRequiredOnboarding: false),
      );
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate,
      );
    });

    test('task management positioning -> actionItemsViolatesGate', () {
      final result = ActionItemsV1SecondaryGate.build(
        _input(notTaskManagementPositioning: false),
      );
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate,
      );
    });

    test('reminders expansion requested -> actionItemsViolatesGate', () {
      final result = ActionItemsV1SecondaryGate.build(
        _input(noExpansionGuarded: false),
      );
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsViolatesGate,
      );
    });

    test('user-confirmed access soft failure -> actionItemsWarnReview', () {
      final result = ActionItemsV1SecondaryGate.build(
        _input(userConfirmedAccessOnly: false),
      );
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsWarnReview,
      );
      expect(result.violatesGate, isFalse);
    });
  });

  group('ActionItemsV1SecondaryGate.evaluateCopy', () {
    test('remember-this language allowed', () {
      expect(
        ActionItemsV1SecondaryGate.passesCopy(ActionItemsCopy.rememberThis),
        isTrue,
      );
      expect(
        ActionItemsV1SecondaryGate.passesCopy(ActionItemsCopy.settingsSubtitle),
        isTrue,
      );
    });

    test('task management positioning blocked', () {
      final result = ActionItemsV1SecondaryGate.evaluateCopy(
        'ArchiveMe is your task manager for life.',
      );
      expect(
        result.action,
        ActionItemsV1SecondaryGateCopyAction.block,
      );
      expect(
        result.reason,
        ActionItemsV1SecondaryGateCopyReason.blockedTaskManagement,
      );
    });

    test('anti-task-management instructional copy allowed', () {
      expect(
        ActionItemsV1SecondaryGate.evaluateCopy(
          ActionItemsV1SecondaryGateCopy.guardrail,
        ).action,
        ActionItemsV1SecondaryGateCopyAction.allowed,
      );
      expect(
        ActionItemsV1SecondaryGate.evaluateCopy(
          'No reports, dashboards, action items, or context work needed now.',
        ).action,
        ActionItemsV1SecondaryGateCopyAction.allowed,
      );
    });
  });

  group('ActionItemsV1SecondaryGate.fromRepoSignals', () {
    late String v1ScopeSource;
    late String firstFiveSource;
    late String proPromiseSource;
    late String featureNoiseSource;
    late String onboardingSource;
    late String rememberThisSource;
    late String freezeCopySource;
    late String releaseFreezeCopySource;
    late String archiveActionItemSource;

    setUpAll(() {
      v1ScopeSource =
          File('lib/features/v1_surface_scope/v1_surface_scope_audit.dart')
              .readAsStringSync();
      firstFiveSource =
          File('lib/features/first_five_minutes/first_five_minutes_simplification.dart')
              .readAsStringSync();
      proPromiseSource =
          File('lib/features/pro_single_promise/pro_single_promise_copy.dart')
              .readAsStringSync();
      featureNoiseSource =
          File('lib/features/feature_noise_reduction/feature_noise_reduction.dart')
              .readAsStringSync();
      onboardingSource =
          File('lib/onboarding/onboarding_pages.dart').readAsStringSync();
      rememberThisSource =
          File('lib/widgets/action_items/remember_this_button.dart')
              .readAsStringSync();
      freezeCopySource =
          File('lib/features/freeze_drift_scanner/freeze_drift_scanner_copy.dart')
              .readAsStringSync();
      releaseFreezeCopySource =
          File('lib/features/release_candidate_freeze/release_candidate_freeze_copy.dart')
              .readAsStringSync();
      archiveActionItemSource =
          File('lib/features/action_items/archive_action_item.dart')
              .readAsStringSync();
    });

    test('repo signals detect secondary scope', () {
      expect(
        ActionItemsV1SecondaryGate.detectSecondaryScope(v1ScopeSource),
        isTrue,
      );
      expect(
        V1SurfaceScopeAudit.scopeFor(V1VisibleSurface.actionItems),
        V1SurfaceScope.secondaryHidden,
      );
    });

    test('repo signals detect first-five-minute hide', () {
      expect(
        ActionItemsV1SecondaryGate.detectHiddenInFirstFiveMinutes(
          firstFiveSource,
        ),
        isTrue,
      );
      expect(
        FirstFiveMinutesSimplification.build(
          const FirstFiveMinutesInput(
            surface: FirstFiveMinutesSurface.actionItems,
            minuteIndex: 0,
            hasSavedFirstMoment: false,
            hasSavedSecondMoment: false,
            hasFirstUsefulProof: false,
            hasUserAskedForSurface: false,
            isStoreReadinessMode: false,
            isPostSave: false,
            userFeelsConfused: false,
          ),
        ).shouldShow,
        isFalse,
      );
    });

    test('repo signals detect Pro promise exclusion', () {
      expect(
        ActionItemsV1SecondaryGate.detectNotInProPromise(proPromiseSource),
        isTrue,
      );
    });

    test('repo signals detect first-proof non-blocker', () {
      expect(
        ActionItemsV1SecondaryGate.detectNotBlockingFirstProof(featureNoiseSource),
        isTrue,
      );
      expect(
        FeatureNoiseReduction.build(
          const FeatureNoiseReductionInput(
            surfaceType: FeatureSurfaceType.actionItems,
            isFirstSession: true,
            isRecordScreen: false,
            isPostSave: false,
            eligibleEntryCount: 0,
            hasFirstUsefulProof: false,
            hasConfirmedRepeat: false,
            hasLongerTrail: false,
            hasUserCorrection: false,
            userAskedForSurface: false,
            storeReadinessMode: false,
          ),
        ).shouldShow,
        isFalse,
      );
    });

    test('repo signals detect onboarding exclusion', () {
      expect(
        ActionItemsV1SecondaryGate.detectNotRequiredOnboarding(onboardingSource),
        isTrue,
      );
    });

    test('repo signals detect user-confirmed access', () {
      expect(
        ActionItemsV1SecondaryGate.detectUserConfirmedAccessOnly(
          rememberThisSource,
        ),
        isTrue,
      );
    });

    test('repo signals detect expansion guard', () {
      expect(
        ActionItemsV1SecondaryGate.detectNoExpansionGuarded(
          freezeDriftScannerCopySource: freezeCopySource,
          releaseCandidateFreezeCopySource: releaseFreezeCopySource,
        ),
        isTrue,
      );
    });

    test('repo signals detect safe action-items copy', () {
      expect(
        ActionItemsV1SecondaryGate.detectActionItemsCopySafe(
          archiveActionItemSource,
        ),
        isTrue,
      );
      for (final line in ActionItemsCopy.all) {
        expect(
          ActionItemsV1SecondaryGate.passesCopy(line),
          isTrue,
          reason: line,
        );
      }
    });

    test('fromRepoSignals passes gate for current repo', () {
      final result = ActionItemsV1SecondaryGate.build(
        ActionItemsV1SecondaryGate.fromRepoSignals(
          v1SurfaceScopeAuditSource: v1ScopeSource,
          firstFiveMinutesSimplificationSource: firstFiveSource,
          proSinglePromiseCopySource: proPromiseSource,
          featureNoiseReductionSource: featureNoiseSource,
          onboardingPagesSource: onboardingSource,
          rememberThisButtonSource: rememberThisSource,
          freezeDriftScannerCopySource: freezeCopySource,
          releaseCandidateFreezeCopySource: releaseFreezeCopySource,
          archiveActionItemSource: archiveActionItemSource,
        ),
      );
      expect(
        result.decision,
        ActionItemsV1SecondaryGateDecision.actionItemsSecondaryOk,
      );
    });
  });

  group('ActionItemsV1SecondaryGateCopy', () {
    test('guardrail blocks expansion and task manager positioning', () {
      final guardrail = ActionItemsV1SecondaryGateCopy.guardrail.toLowerCase();
      expect(guardrail, contains('do not delete action items'));
      expect(guardrail, contains('do not expand action items'));
      expect(guardrail, contains('no reminders expansion'));
      expect(guardrail, contains('no task manager positioning'));
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ActionItemsV1SecondaryGateCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not delete or expand action items in source', () {
      for (final path in [
        'lib/features/action_items_v1_gate/action_items_v1_secondary_gate.dart',
        'lib/features/action_items_v1_gate/action_items_v1_secondary_gate_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('deleteSync'), isFalse);
        expect(source.contains('ActionItemStore'), isFalse);
        expect(source.contains('paywall'), isFalse);
        expect(source.contains('RevenueCat'), isFalse);
      }
      expect(
        File('lib/features/action_items/action_item_store.dart').existsSync(),
        isTrue,
      );
    });

    test('proof_surface_advice_guard registers action items gate copy', () {
      final source =
          File('lib/features/archive_proof/proof_surface_advice_guard.dart')
              .readAsStringSync();
      expect(source, contains('action_items_v1_secondary_gate_copy.dart'));
      expect(
        source,
        contains('ActionItemsV1SecondaryGateCopy.allVisibleStrings()'),
      );
    });

    test('main proof surface copy does not block on task management framing', () {
      final offenders = <String>[];
      for (final text in ProofSurfaceAdviceGuard.mainProofSurfaceCopyBlocks()) {
        if (text.contains('never appear as a task manager')) continue;
        final result = ActionItemsV1SecondaryGate.evaluateCopy(text);
        if (result.action == ActionItemsV1SecondaryGateCopyAction.block) {
          offenders.add('${result.matchedPhrase}: $text');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('no dashboard positioning guard regressions unchanged', () {
      expect(
        NoDashboardPositioningGuard.evaluate(
          'ArchiveMe keeps your proof trail over time.',
        ).action,
        NoDashboardPositioningGuardAction.allowed,
      );
    });

    test('proof trail positioning still blocks dashboard maintenance', () {
      expect(
        ProofTrailPositioning.resolve(
          const ProofTrailPositioningInput(
            userThinksChatBox: false,
            userThinksStorageApp: false,
            userThinksSecondBrain: false,
            userThinksDashboardToMaintain: true,
            userUnderstandsProofTrail: true,
            userUnderstandsMeaningfulResurfacing: true,
            userUnderstandsSaveARepeat: true,
            userUnderstandsLowEffort: true,
            wouldPayYes: true,
            wouldPayMaybe: false,
          ),
        ).decision,
        ProofTrailPositioningDecision.clarifyNotDashboard,
      );
    });

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
    });

    test('record screen remains capture-first without stacking extra cards', () {
      final audit = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
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
          betaProofLift: true,
        ),
      );
      expect(audit.proofCardKey, 'timelineProofMoment');
      expect(audit.guidanceCardKey, isNull);
    });
  });
}
