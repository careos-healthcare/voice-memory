import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/android_after_ios_proof/android_after_ios_proof_copy.dart';
import 'package:voicememory_mobile/features/android_after_ios_proof/android_after_ios_proof_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/ANDROID_AFTER_IOS_PROOF.md';

AndroidAfterIosProofGateInput _input({
  bool? iosTestFlightUploaded = true,
  bool? iosRevenueCatProductsLoad = true,
  bool? iosSandboxPurchaseWorks = true,
  bool? iosRestoreWorks = true,
  bool? iosEntitlementPersists = true,
  bool? paidIntentBetaPromising = true,
  bool? noProductionSecretsBlocker = true,
  bool? androidWorkRequested,
  bool? androidPrioritisationRequested,
}) => AndroidAfterIosProofGateInput(
  iosTestFlightUploaded: iosTestFlightUploaded,
  iosRevenueCatProductsLoad: iosRevenueCatProductsLoad,
  iosSandboxPurchaseWorks: iosSandboxPurchaseWorks,
  iosRestoreWorks: iosRestoreWorks,
  iosEntitlementPersists: iosEntitlementPersists,
  paidIntentBetaPromising: paidIntentBetaPromising,
  noProductionSecretsBlocker: noProductionSecretsBlocker,
  androidWorkRequested: androidWorkRequested,
  androidPrioritisationRequested: androidPrioritisationRequested,
);

AndroidAfterIosProofPrereq _prereq(
  AndroidAfterIosProofGateResult result,
  AndroidAfterIosProofPrereqId id,
) => result.prereqs.firstWhere((prereq) => prereq.id == id);

AndroidAfterIosProofRule _rule(
  AndroidAfterIosProofGateResult result,
  AndroidAfterIosProofRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('AndroidAfterIosProofGate.build', () {
    test('gate tracks seven prerequisites and two rules in order', () {
      final result = AndroidAfterIosProofGate.build(_input());
      expect(result.prereqs.length, AndroidAfterIosProofGate.prereqCount);
      expect(result.rules.length, AndroidAfterIosProofGate.ruleCount);
      expect(result.prereqOrder, AndroidAfterIosProofGate.canonicalPrereqOrder);
      expect(result.ruleOrder, AndroidAfterIosProofGate.canonicalRuleOrder);
    });

    test('default input without explicit prereqs -> androidFrozen', () {
      final result = AndroidAfterIosProofGate.build(
        const AndroidAfterIosProofGateInput(),
      );
      expect(result.decision, AndroidAfterIosProofGateDecision.androidFrozen);
      expect(result.iosProofComplete, isFalse);
      expect(result.androidWorkBlocked, isTrue);
      expect(result.androidPrioritisationBlocked, isTrue);
    });

    test('all iOS proof prereqs pass -> androidExpansionUnblocked', () {
      final result = AndroidAfterIosProofGate.build(_input());
      expect(
        result.decision,
        AndroidAfterIosProofGateDecision.androidExpansionUnblocked,
      );
      expect(result.iosProofComplete, isTrue);
      expect(result.rulesPass, isTrue);
      expect(result.earliestPrereqGap, isNull);
    });

    test('pending TestFlight -> androidFrozen', () {
      final result = AndroidAfterIosProofGate.build(
        _input(iosTestFlightUploaded: null),
      );
      expect(result.decision, AndroidAfterIosProofGateDecision.androidFrozen);
      expect(
        result.earliestPrereqGap,
        AndroidAfterIosProofPrereqId.iosTestFlightUploaded,
      );
    });

    test('sandbox purchase incomplete -> androidFrozen', () {
      final result = AndroidAfterIosProofGate.build(
        _input(iosSandboxPurchaseWorks: false),
      );
      expect(result.decision, AndroidAfterIosProofGateDecision.androidFrozen);
      expect(
        _prereq(
          result,
          AndroidAfterIosProofPrereqId.iosSandboxPurchaseWorks,
        ).status,
        AndroidAfterIosProofPrereqStatus.fail,
      );
    });

    test('production secrets blocker -> androidFrozen', () {
      final result = AndroidAfterIosProofGate.build(
        _input(noProductionSecretsBlocker: false),
      );
      expect(result.decision, AndroidAfterIosProofGateDecision.androidFrozen);
      expect(
        _prereq(
          result,
          AndroidAfterIosProofPrereqId.noProductionSecretsBlocker,
        ).status,
        AndroidAfterIosProofPrereqStatus.fail,
      );
    });

    test('android work requested before proof fails work rule', () {
      final result = AndroidAfterIosProofGate.build(
        _input(iosTestFlightUploaded: false, androidWorkRequested: true),
      );
      expect(
        _rule(
          result,
          AndroidAfterIosProofRuleId.androidWorkBlockedUntilPrereqsPass,
        ).status,
        AndroidAfterIosProofRuleStatus.fail,
      );
    });

    test('android prioritisation requested before proof fails setup rule', () {
      final result = AndroidAfterIosProofGate.build(
        _input(
          paidIntentBetaPromising: false,
          androidPrioritisationRequested: true,
        ),
      );
      expect(
        _rule(
          result,
          AndroidAfterIosProofRuleId.androidSetupDocumentedNotPrioritised,
        ).status,
        AndroidAfterIosProofRuleStatus.fail,
      );
    });

    test('canonical rules pass for gate copy', () {
      final result = AndroidAfterIosProofGate.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          AndroidAfterIosProofRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('report exposes canonical copy', () {
      final report = AndroidAfterIosProofGate.report(
        AndroidAfterIosProofGate.build(_input()),
      );
      expect(report.headline, AndroidAfterIosProofCopy.headline);
      expect(report.prereqOrderLine, AndroidAfterIosProofCopy.prereqOrderLine);
      expect(report.guardrail, AndroidAfterIosProofCopy.guardrail);
    });
  });

  group('AndroidAfterIosProofGate.composeInput', () {
    test('bridges launch checklist iOS proof signals', () {
      final input = AndroidAfterIosProofGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          testFlightUploaded: true,
          revenueCatProductsLoad: true,
          sandboxPurchaseWorks: true,
          restoreWorks: true,
          entitlementPersists: true,
          paidIntentBetaComplete: true,
          secretsRotatedBeforeProduction: true,
        ),
      );
      expect(input.iosTestFlightUploaded, isTrue);
      expect(input.iosRevenueCatProductsLoad, isTrue);
      expect(input.iosSandboxPurchaseWorks, isTrue);
      expect(input.iosRestoreWorks, isTrue);
      expect(input.iosEntitlementPersists, isTrue);
      expect(input.paidIntentBetaPromising, isTrue);
      expect(input.noProductionSecretsBlocker, isTrue);
    });

    test('bridges paid-intent beta promising', () {
      final input = AndroidAfterIosProofGate.composeInput(
        paidIntentBeta: PaidIntentBetaProof.build(
          const PaidIntentBetaProofInput(
            firstSaveCompleted: true,
            firstUsefulProofSeen: true,
            proofAcceptedOrCorrected: true,
            proPromiseSeen: true,
            proTapped: true,
            purchaseAttempted: true,
            purchaseCompleted: true,
          ),
        ),
      );
      expect(input.paidIntentBetaPromising, isTrue);
    });

    test(
      'bridges secrets rotation not blocked as no production secrets blocker',
      () {
        final input = AndroidAfterIosProofGate.composeInput(
          secretsRotation: SecretsRotationLaunchGate.build(
            const SecretsRotationLaunchGateInput(
              stripeSecretKeyRotated: null,
              stripeWebhookSecretRotated: null,
              productionEnvUpdated: null,
              oldWebhookDisabled: null,
              vercelEnvProductionVerified: null,
              revenueCatApiKeySeparatedFromDocsLogs: true,
              noSecretValuesCommitted: true,
              noSecretValuesPrintedInLogs: true,
            ),
          ),
        );
        expect(input.noProductionSecretsBlocker, isTrue);
      },
    );
  });

  group('AndroidAfterIosProofGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/android_after_ios_proof/android_after_ios_proof_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(AndroidAfterIosProofGate.detectDocListsRules(docsSource), isTrue);
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        AndroidAfterIosProofGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to androidFrozen', () {
      final result = AndroidAfterIosProofGate.build(
        AndroidAfterIosProofGate.fromRepoSignals(
          androidAfterIosProofDocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(result.decision, AndroidAfterIosProofGateDecision.androidFrozen);
      expect(
        _prereq(
          result,
          AndroidAfterIosProofPrereqId.iosTestFlightUploaded,
        ).status,
        AndroidAfterIosProofPrereqStatus.pending,
      );
    });
  });

  group('protected regression', () {
    test('docs describe Android after iOS proof scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('android after ios proof'));
      expect(doc, contains('ios testflight uploaded'));
      expect(doc, contains('revenuecat products load'));
      expect(doc, contains('sandbox purchase works'));
      expect(doc, contains('restore works'));
      expect(doc, contains('entitlement persists'));
      expect(doc, contains('paid-intent beta promising'));
      expect(doc, contains('no production secrets blocker'));
      expect(doc, contains('android work blocked until prerequisites pass'));
      expect(doc, contains('documented but not prioritised'));
    });

    test('guardrail blocks Android work before iOS proof', () {
      final guardrail = AndroidAfterIosProofCopy.guardrail.toLowerCase();
      expect(guardrail, contains('android after ios proof'));
      expect(
        guardrail,
        contains('android work blocked until prerequisites pass'),
      );
      expect(guardrail, contains('documented but not prioritised'));
      expect(guardrail, contains('ios purchase, restore, and paid intent'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in AndroidAfterIosProofCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import Android build or paywall UI', () {
      for (final path in [
        'lib/features/android_after_ios_proof/android_after_ios_proof_gate.dart',
        'lib/features/android_after_ios_proof/android_after_ios_proof_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('android/app/build.gradle'), isFalse);
      }
    });

    test('advice guard registers android after iOS proof copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('AndroidAfterIosProofCopy.allVisibleStrings()'),
      );
    });
  });
}
