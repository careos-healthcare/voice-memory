import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import '../secrets_rotation_gate/secrets_rotation_launch_gate_copy.dart';
import '../single_launch_checklist/single_launch_checklist.dart';
import 'android_after_ios_proof_copy.dart';

/// Android after iOS proof gate — block Android until iOS purchase/restore proven.
abstract final class AndroidAfterIosProofGate {
  AndroidAfterIosProofGate._();

  static const ruleCount = 2;
  static const prereqCount = 7;

  static const canonicalRuleOrder = [
    AndroidAfterIosProofRuleId.androidWorkBlockedUntilPrereqsPass,
    AndroidAfterIosProofRuleId.androidSetupDocumentedNotPrioritised,
  ];

  static const canonicalPrereqOrder = [
    AndroidAfterIosProofPrereqId.iosTestFlightUploaded,
    AndroidAfterIosProofPrereqId.iosRevenueCatProductsLoad,
    AndroidAfterIosProofPrereqId.iosSandboxPurchaseWorks,
    AndroidAfterIosProofPrereqId.iosRestoreWorks,
    AndroidAfterIosProofPrereqId.iosEntitlementPersists,
    AndroidAfterIosProofPrereqId.paidIntentBetaPromising,
    AndroidAfterIosProofPrereqId.noProductionSecretsBlocker,
  ];

  static AndroidAfterIosProofGateResult build(
    AndroidAfterIosProofGateInput input,
  ) {
    final rules = _buildRules(input);
    final prereqs = _buildPrereqs(input);
    final rulesPass = rules.every(
      (rule) => rule.status == AndroidAfterIosProofRuleStatus.pass,
    );
    final iosProofComplete = prereqs.every(
      (prereq) => prereq.status == AndroidAfterIosProofPrereqStatus.pass,
    );
    final decision = rulesPass && iosProofComplete
        ? AndroidAfterIosProofGateDecision.androidExpansionUnblocked
        : AndroidAfterIosProofGateDecision.androidFrozen;
    return AndroidAfterIosProofGateResult(
      decision: decision,
      message: AndroidAfterIosProofCopy.messageFor(decision),
      recommendation: AndroidAfterIosProofCopy.recommendationFor(decision),
      positioning: AndroidAfterIosProofCopy.positioning,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      iosProofComplete: iosProofComplete,
      androidWorkBlocked: true,
      androidPrioritisationBlocked: !iosProofComplete,
      earliestPrereqGap: prereqs
          .where(
            (prereq) => prereq.status != AndroidAfterIosProofPrereqStatus.pass,
          )
          .map((prereq) => prereq.id)
          .firstOrNull,
      earliestRuleFailure: rules
          .where((rule) => rule.status == AndroidAfterIosProofRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static AndroidAfterIosProofGateReport report(
    AndroidAfterIosProofGateResult result,
  ) =>
      AndroidAfterIosProofGateReport(
        headline: AndroidAfterIosProofCopy.headline,
        body: AndroidAfterIosProofCopy.body,
        positioning: AndroidAfterIosProofCopy.positioning,
        orderLine: AndroidAfterIosProofCopy.orderLine,
        prereqOrderLine: AndroidAfterIosProofCopy.prereqOrderLine,
        guardrail: AndroidAfterIosProofCopy.guardrail,
        result: result,
      );

  static AndroidAfterIosProofGateInput composeInput({
    bool? iosTestFlightUploaded,
    bool? iosRevenueCatProductsLoad,
    bool? iosSandboxPurchaseWorks,
    bool? iosRestoreWorks,
    bool? iosEntitlementPersists,
    bool? paidIntentBetaPromising,
    bool? noProductionSecretsBlocker,
    bool? androidWorkRequested,
    bool? androidPrioritisationRequested,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
    SecretsRotationLaunchGateResult? secretsRotation,
  }) =>
      AndroidAfterIosProofGateInput(
        iosTestFlightUploaded: iosTestFlightUploaded ??
            launchChecklist?.testFlightUploaded,
        iosRevenueCatProductsLoad: iosRevenueCatProductsLoad ??
            launchChecklist?.revenueCatProductsLoad,
        iosSandboxPurchaseWorks: iosSandboxPurchaseWorks ??
            launchChecklist?.sandboxPurchaseWorks,
        iosRestoreWorks:
            iosRestoreWorks ?? launchChecklist?.restoreWorks,
        iosEntitlementPersists: iosEntitlementPersists ??
            launchChecklist?.entitlementPersists,
        paidIntentBetaPromising: paidIntentBetaPromising ??
            launchChecklist?.paidIntentBetaComplete ??
            _paidIntentBetaPromisingFrom(paidIntentBeta),
        noProductionSecretsBlocker: noProductionSecretsBlocker ??
            _noProductionSecretsBlockerFrom(secretsRotation) ??
            launchChecklist?.secretsRotatedBeforeProduction,
        androidWorkRequested: androidWorkRequested,
        androidPrioritisationRequested: androidPrioritisationRequested,
      );

  static AndroidAfterIosProofGateInput fromRepoSignals({
    required String androidAfterIosProofDocSource,
    required String gateCopySource,
    bool? iosTestFlightUploaded,
    bool? iosRevenueCatProductsLoad,
    bool? iosSandboxPurchaseWorks,
    bool? iosRestoreWorks,
    bool? iosEntitlementPersists,
    bool? paidIntentBetaPromising,
    bool? noProductionSecretsBlocker,
    bool? androidWorkRequested,
    bool? androidPrioritisationRequested,
  }) =>
      AndroidAfterIosProofGateInput(
        iosTestFlightUploaded: iosTestFlightUploaded,
        iosRevenueCatProductsLoad: iosRevenueCatProductsLoad,
        iosSandboxPurchaseWorks: iosSandboxPurchaseWorks,
        iosRestoreWorks: iosRestoreWorks,
        iosEntitlementPersists: iosEntitlementPersists,
        paidIntentBetaPromising: paidIntentBetaPromising,
        noProductionSecretsBlocker: noProductionSecretsBlocker,
        androidWorkRequested: androidWorkRequested,
        androidPrioritisationRequested: androidPrioritisationRequested,
        docListsRules: detectDocListsRules(androidAfterIosProofDocSource),
        guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
      );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'ios testflight uploaded',
      'revenuecat products load',
      'sandbox purchase works',
      'restore works',
      'entitlement persists',
      'paid-intent beta promising',
      'no production secrets blocker',
      'android work blocked until prerequisites pass',
      'documented but not prioritised',
      'android after ios proof',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('android after ios proof') &&
        lower.contains('android work blocked until prerequisites pass') &&
        lower.contains('documented but not prioritised') &&
        lower.contains('ios purchase, restore, and paid intent');
  }

  static bool? _paidIntentBetaPromisingFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static bool? _noProductionSecretsBlockerFrom(
    SecretsRotationLaunchGateResult? result,
  ) {
    if (result == null) return null;
    return result.status !=
        SecretsRotationLaunchGateStatus.blockedForProductionSubmission;
  }

  static List<AndroidAfterIosProofRule> _buildRules(
    AndroidAfterIosProofGateInput input,
  ) {
    final guardrailLower = AndroidAfterIosProofCopy.guardrail.toLowerCase();
    final iosProofComplete = _iosProofCompleteFrom(input);
    final androidWorkRequested = input.androidWorkRequested ?? false;
    final androidPrioritisationRequested =
        input.androidPrioritisationRequested ?? false;
    return [
      _rule(
        id: AndroidAfterIosProofRuleId.androidWorkBlockedUntilPrereqsPass,
        passes: guardrailLower.contains('android work blocked until prerequisites pass') &&
            (!androidWorkRequested || iosProofComplete),
      ),
      _rule(
        id: AndroidAfterIosProofRuleId.androidSetupDocumentedNotPrioritised,
        passes: guardrailLower.contains('documented but not prioritised') &&
            (!androidPrioritisationRequested || iosProofComplete),
      ),
    ];
  }

  static List<AndroidAfterIosProofPrereq> _buildPrereqs(
    AndroidAfterIosProofGateInput input,
  ) =>
      [
        _prereq(
          id: AndroidAfterIosProofPrereqId.iosTestFlightUploaded,
          value: input.iosTestFlightUploaded,
        ),
        _prereq(
          id: AndroidAfterIosProofPrereqId.iosRevenueCatProductsLoad,
          value: input.iosRevenueCatProductsLoad,
        ),
        _prereq(
          id: AndroidAfterIosProofPrereqId.iosSandboxPurchaseWorks,
          value: input.iosSandboxPurchaseWorks,
        ),
        _prereq(
          id: AndroidAfterIosProofPrereqId.iosRestoreWorks,
          value: input.iosRestoreWorks,
        ),
        _prereq(
          id: AndroidAfterIosProofPrereqId.iosEntitlementPersists,
          value: input.iosEntitlementPersists,
        ),
        _prereq(
          id: AndroidAfterIosProofPrereqId.paidIntentBetaPromising,
          value: input.paidIntentBetaPromising,
        ),
        _prereq(
          id: AndroidAfterIosProofPrereqId.noProductionSecretsBlocker,
          value: input.noProductionSecretsBlocker,
        ),
      ];

  static bool _iosProofCompleteFrom(AndroidAfterIosProofGateInput input) =>
      (input.iosTestFlightUploaded ?? false) &&
      (input.iosRevenueCatProductsLoad ?? false) &&
      (input.iosSandboxPurchaseWorks ?? false) &&
      (input.iosRestoreWorks ?? false) &&
      (input.iosEntitlementPersists ?? false) &&
      (input.paidIntentBetaPromising ?? false) &&
      (input.noProductionSecretsBlocker ?? false);

  static AndroidAfterIosProofPrereqStatus _statusFor(bool? value) =>
      switch (value) {
        true => AndroidAfterIosProofPrereqStatus.pass,
        false => AndroidAfterIosProofPrereqStatus.fail,
        null => AndroidAfterIosProofPrereqStatus.pending,
      };

  static AndroidAfterIosProofPrereq _prereq({
    required AndroidAfterIosProofPrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return AndroidAfterIosProofPrereq(
      id: id,
      label: AndroidAfterIosProofCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        AndroidAfterIosProofPrereqStatus.pass => AndroidAfterIosProofCopy.detailPass,
        AndroidAfterIosProofPrereqStatus.pending =>
          AndroidAfterIosProofCopy.detailPending,
        AndroidAfterIosProofPrereqStatus.fail => AndroidAfterIosProofCopy.detailFail,
      },
    );
  }

  static AndroidAfterIosProofRule _rule({
    required AndroidAfterIosProofRuleId id,
    required bool passes,
  }) =>
      AndroidAfterIosProofRule(
        id: id,
        label: AndroidAfterIosProofCopy.ruleLabelFor(id),
        status: passes
            ? AndroidAfterIosProofRuleStatus.pass
            : AndroidAfterIosProofRuleStatus.fail,
        detailLabel: passes
            ? AndroidAfterIosProofCopy.detailPass
            : AndroidAfterIosProofCopy.detailFail,
      );
}

class AndroidAfterIosProofGateInput {
  const AndroidAfterIosProofGateInput({
    this.iosTestFlightUploaded,
    this.iosRevenueCatProductsLoad,
    this.iosSandboxPurchaseWorks,
    this.iosRestoreWorks,
    this.iosEntitlementPersists,
    this.paidIntentBetaPromising,
    this.noProductionSecretsBlocker,
    this.androidWorkRequested,
    this.androidPrioritisationRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
  });

  final bool? iosTestFlightUploaded;
  final bool? iosRevenueCatProductsLoad;
  final bool? iosSandboxPurchaseWorks;
  final bool? iosRestoreWorks;
  final bool? iosEntitlementPersists;
  final bool? paidIntentBetaPromising;
  final bool? noProductionSecretsBlocker;
  final bool? androidWorkRequested;
  final bool? androidPrioritisationRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
}

class AndroidAfterIosProofRule {
  const AndroidAfterIosProofRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final AndroidAfterIosProofRuleId id;
  final String label;
  final AndroidAfterIosProofRuleStatus status;
  final String detailLabel;
}

class AndroidAfterIosProofPrereq {
  const AndroidAfterIosProofPrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final AndroidAfterIosProofPrereqId id;
  final String label;
  final AndroidAfterIosProofPrereqStatus status;
  final String detailLabel;
}

class AndroidAfterIosProofGateResult {
  const AndroidAfterIosProofGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.prereqs,
    required this.prereqOrder,
    required this.iosProofComplete,
    required this.androidWorkBlocked,
    required this.androidPrioritisationBlocked,
    required this.earliestPrereqGap,
    required this.earliestRuleFailure,
  });

  final AndroidAfterIosProofGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<AndroidAfterIosProofRule> rules;
  final List<AndroidAfterIosProofRuleId> ruleOrder;
  final bool rulesPass;
  final List<AndroidAfterIosProofPrereq> prereqs;
  final List<AndroidAfterIosProofPrereqId> prereqOrder;
  final bool iosProofComplete;
  final bool androidWorkBlocked;
  final bool androidPrioritisationBlocked;
  final AndroidAfterIosProofPrereqId? earliestPrereqGap;
  final AndroidAfterIosProofRuleId? earliestRuleFailure;
}

class AndroidAfterIosProofGateReport {
  const AndroidAfterIosProofGateReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.orderLine,
    required this.prereqOrderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String orderLine;
  final String prereqOrderLine;
  final String guardrail;
  final AndroidAfterIosProofGateResult result;
}
