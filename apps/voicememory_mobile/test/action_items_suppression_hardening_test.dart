import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/action_items/archive_action_item.dart';
import 'package:voicememory_mobile/features/action_items_v1_gate/action_items_suppression_hardening.dart';
import 'package:voicememory_mobile/features/action_items_v1_gate/action_items_v1_secondary_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/feature_noise_reduction/feature_noise_reduction.dart';
import 'package:voicememory_mobile/features/first_five_minutes/first_five_minutes_simplification.dart';
import 'package:voicememory_mobile/features/v1_surface_scope/v1_surface_scope_audit.dart';

const _docsPath = 'docs/ACTION_ITEMS_SUPPRESSION_HARDENING.md';
const _hardeningPath =
    'lib/features/action_items_v1_gate/action_items_suppression_hardening.dart';

ActionItemsSuppressionHardeningInput _input({
  bool hiddenInFirstFiveMinutes = true,
  bool notInProPromise = true,
  bool notRequiredOnboarding = true,
  bool notBlockingFirstProof = true,
  bool notTaskManagementPositioning = true,
  bool userConfirmedAccessOnly = true,
  bool noRemindersExpansion = true,
  bool actionItemsSecondary = true,
  bool storagePreserved = true,
}) => ActionItemsSuppressionHardeningInput(
  hiddenInFirstFiveMinutes: hiddenInFirstFiveMinutes,
  notInProPromise: notInProPromise,
  notRequiredOnboarding: notRequiredOnboarding,
  notBlockingFirstProof: notBlockingFirstProof,
  notTaskManagerPositioning: notTaskManagementPositioning,
  userConfirmedAccessOnly: userConfirmedAccessOnly,
  noRemindersExpansion: noRemindersExpansion,
  actionItemsSecondary: actionItemsSecondary,
  storagePreserved: storagePreserved,
);

void main() {
  group('ActionItemsSuppressionHardening.build', () {
    test('hardening has ten canonical rules', () {
      final result = ActionItemsSuppressionHardening.build(_input());
      expect(
        result.rules,
        hasLength(ActionItemsSuppressionHardening.ruleCount),
      );
      expect(ActionItemsSuppressionHardening.canonicalRules, hasLength(10));
    });

    test('all rules pass -> hardened', () {
      final result = ActionItemsSuppressionHardening.build(_input());
      expect(result.decision, ActionItemsSuppressionHardeningDecision.hardened);
      expect(result.hardened, isTrue);
    });

    test('first five minutes violation -> violated', () {
      final result = ActionItemsSuppressionHardening.build(
        _input(hiddenInFirstFiveMinutes: false),
      );
      expect(result.decision, ActionItemsSuppressionHardeningDecision.violated);
    });

    test('remember-this soft failure -> needsReview', () {
      final result = ActionItemsSuppressionHardening.build(
        _input(userConfirmedAccessOnly: false),
      );
      expect(
        result.decision,
        ActionItemsSuppressionHardeningDecision.needsReview,
      );
      expect(result.hardened, isFalse);
    });
  });

  group('ActionItemsSuppressionHardening.fromRepoSignals', () {
    late String firstFiveSource;
    late String proPromiseSource;
    late String onboardingSource;
    late String rememberThisSource;
    late String archiveActionItemSource;
    late String actionItemStoreSource;

    setUpAll(() {
      firstFiveSource = File(
        'lib/features/first_five_minutes/first_five_minutes_simplification.dart',
      ).readAsStringSync();
      proPromiseSource = File(
        'lib/features/pro_single_promise/pro_single_promise_copy.dart',
      ).readAsStringSync();
      onboardingSource = File(
        'lib/onboarding/onboarding_pages.dart',
      ).readAsStringSync();
      rememberThisSource = File(
        'lib/widgets/action_items/remember_this_button.dart',
      ).readAsStringSync();
      archiveActionItemSource = File(
        'lib/features/action_items/archive_action_item.dart',
      ).readAsStringSync();
      actionItemStoreSource = File(
        'lib/features/action_items/action_item_store.dart',
      ).readAsStringSync();
    });

    test('first five minutes source keeps action items hidden', () {
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

    test('Pro promise source contains no action-items promise', () {
      expect(
        ActionItemsV1SecondaryGate.detectNotInProPromise(proPromiseSource),
        isTrue,
      );
      expect(proPromiseSource.toLowerCase(), isNot(contains('action items')));
    });

    test('onboarding contains no required action-items step', () {
      expect(
        ActionItemsV1SecondaryGate.detectNotRequiredOnboarding(
          onboardingSource,
        ),
        isTrue,
      );
      expect(onboardingSource.toLowerCase(), isNot(contains('action items')));
    });

    test('action-items copy avoids task manager language', () {
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

    test('remember-this path is user-confirmed only', () {
      expect(
        ActionItemsV1SecondaryGate.detectUserConfirmedAccessOnly(
          rememberThisSource,
        ),
        isTrue,
      );
      expect(rememberThisSource, contains('Creates nothing until the'));
      expect(rememberThisSource, contains('no auto-extraction'));
    });

    test('fromRepoSignals passes hardening for current repo', () {
      final result = ActionItemsSuppressionHardening.build(
        ActionItemsSuppressionHardening.fromRepoSignals(
          v1SurfaceScopeAuditSource: File(
            'lib/features/v1_surface_scope/v1_surface_scope_audit.dart',
          ).readAsStringSync(),
          firstFiveMinutesSimplificationSource: firstFiveSource,
          proSinglePromiseCopySource: proPromiseSource,
          featureNoiseReductionSource: File(
            'lib/features/feature_noise_reduction/feature_noise_reduction.dart',
          ).readAsStringSync(),
          onboardingPagesSource: onboardingSource,
          rememberThisButtonSource: rememberThisSource,
          freezeDriftScannerCopySource: File(
            'lib/features/freeze_drift_scanner/freeze_drift_scanner_copy.dart',
          ).readAsStringSync(),
          releaseCandidateFreezeCopySource: File(
            'lib/features/release_candidate_freeze/release_candidate_freeze_copy.dart',
          ).readAsStringSync(),
          archiveActionItemSource: archiveActionItemSource,
          actionItemStoreSource: actionItemStoreSource,
        ),
      );
      expect(result.decision, ActionItemsSuppressionHardeningDecision.hardened);
      expect(
        V1SurfaceScopeAudit.scopeFor(V1VisibleSurface.actionItems),
        V1SurfaceScope.secondaryHidden,
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
  });

  group('protected regression', () {
    test('no new UI imports', () {
      final source = File(_hardeningPath).readAsStringSync();
      expect(
        ActionItemsSuppressionHardening.detectModuleHasNoUiImports(source),
        isTrue,
      );
      for (final line in source.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('import ')) continue;
        expect(trimmed.contains('package:flutter/'), isFalse);
        expect(trimmed.contains('widgets/action_items/'), isFalse);
        expect(trimmed.contains('screens/'), isFalse);
      }
    });

    test('storage preserved and not deleted by hardening module', () {
      final storeSource = File(
        'lib/features/action_items/action_item_store.dart',
      ).readAsStringSync();
      expect(
        ActionItemsSuppressionHardening.detectStoragePreserved(storeSource),
        isTrue,
      );
      final hardeningSource = File(_hardeningPath).readAsStringSync();
      expect(hardeningSource.contains("action_item_store.dart"), isFalse);
    });

    test('docs include canonical suppression rules', () {
      final docs = File(_docsPath).readAsStringSync();
      expect(docs, contains('## Canonical rules'));
      for (final rule in ActionItemsSuppressionHardening.canonicalRules) {
        expect(docs, contains(rule), reason: rule);
      }
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final text in ActionItemsSuppressionHardening.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });
}
