import 'package:archiveme_mobile/features/commercial_proof_executor/commercial_proof_executor.dart';
import 'package:archiveme_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:archiveme_mobile/features/release_evidence/release_evidence_pack.dart';
import 'package:archiveme_mobile/features/revenuecat_live_proof/revenuecat_live_proof_runner.dart';
import 'package:archiveme_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import 'package:archiveme_mobile/features/single_launch_checklist/single_launch_checklist_copy.dart';

/// Single launch checklist — one source of truth for launch readiness.
abstract final class SingleLaunchChecklist {
  SingleLaunchChecklist._();

  static const itemCount = 20;

  static const List<SingleLaunchChecklistItemId> canonicalChecklistOrder = [
    SingleLaunchChecklistItemId.cleanGit,
    SingleLaunchChecklistItemId.versionBuildSet,
    SingleLaunchChecklistItemId.physicalIphoneSmoke,
    SingleLaunchChecklistItemId.physicalIpadSmoke,
    SingleLaunchChecklistItemId.productionApiWorks,
    SingleLaunchChecklistItemId.voiceSaveWorks,
    SingleLaunchChecklistItemId.typedSaveWorks,
    SingleLaunchChecklistItemId.firstProofWorks,
    SingleLaunchChecklistItemId.proPromiseVisible,
    SingleLaunchChecklistItemId.revenueCatProductsLoad,
    SingleLaunchChecklistItemId.paywallPriceVisible,
    SingleLaunchChecklistItemId.sandboxPurchaseWorks,
    SingleLaunchChecklistItemId.entitlementUnlocks,
    SingleLaunchChecklistItemId.restoreWorks,
    SingleLaunchChecklistItemId.entitlementPersists,
    SingleLaunchChecklistItemId.supportPrivacyTermsWork,
    SingleLaunchChecklistItemId.screenshotsReady,
    SingleLaunchChecklistItemId.testFlightUploaded,
    SingleLaunchChecklistItemId.paidIntentBetaComplete,
    SingleLaunchChecklistItemId.secretsRotatedBeforeProduction,
  ];

  static const List<SingleLaunchChecklistItemId> testFlightRequiredItems = [
    SingleLaunchChecklistItemId.cleanGit,
    SingleLaunchChecklistItemId.versionBuildSet,
    SingleLaunchChecklistItemId.physicalIphoneSmoke,
    SingleLaunchChecklistItemId.physicalIpadSmoke,
    SingleLaunchChecklistItemId.productionApiWorks,
    SingleLaunchChecklistItemId.voiceSaveWorks,
    SingleLaunchChecklistItemId.typedSaveWorks,
    SingleLaunchChecklistItemId.firstProofWorks,
    SingleLaunchChecklistItemId.proPromiseVisible,
    SingleLaunchChecklistItemId.revenueCatProductsLoad,
    SingleLaunchChecklistItemId.paywallPriceVisible,
    SingleLaunchChecklistItemId.sandboxPurchaseWorks,
    SingleLaunchChecklistItemId.entitlementUnlocks,
    SingleLaunchChecklistItemId.restoreWorks,
    SingleLaunchChecklistItemId.entitlementPersists,
    SingleLaunchChecklistItemId.supportPrivacyTermsWork,
    SingleLaunchChecklistItemId.screenshotsReady,
    SingleLaunchChecklistItemId.testFlightUploaded,
    SingleLaunchChecklistItemId.paidIntentBetaComplete,
  ];

  static SingleLaunchChecklistResult build(SingleLaunchChecklistInput input) {
    final checks = _buildChecks(input);
    final status = _resolveStatus(input, checks);
    return SingleLaunchChecklistResult(
      status: status,
      message: SingleLaunchChecklistCopy.messageFor(status),
      recommendation: SingleLaunchChecklistCopy.recommendationFor(status),
      checks: checks,
      checklistOrder: canonicalChecklistOrder,
      earliestBlocker: checks
          .where(
            (check) => check.status == SingleLaunchChecklistCheckStatus.fail,
          )
          .map((check) => check.id)
          .firstOrNull,
      readyForTestFlight:
          status == SingleLaunchChecklistStatus.readyForTestFlight ||
          status == SingleLaunchChecklistStatus.readyForSubmission,
      readyForSubmission:
          status == SingleLaunchChecklistStatus.readyForSubmission,
    );
  }

  static SingleLaunchChecklistReport report(
    SingleLaunchChecklistResult result,
  ) => SingleLaunchChecklistReport(
    headline: SingleLaunchChecklistCopy.headline,
    body: SingleLaunchChecklistCopy.body,
    orderLine: SingleLaunchChecklistCopy.orderLine,
    guardrail: SingleLaunchChecklistCopy.guardrail,
    result: result,
  );

  static SingleLaunchChecklistInput fromReleaseEvidencePackInput(
    ReleaseEvidencePackInput input, {
    bool? paywallPriceVisible,
    bool? entitlementUnlocks,
    bool? paidIntentBetaComplete,
  }) => SingleLaunchChecklistInput(
    cleanGit: input.cleanGitStatus,
    versionBuildSet: input.versionBuildCaptured,
    physicalIphoneSmoke: input.physicalIphoneSmokeTest,
    physicalIpadSmoke: input.physicalIpadSmokeTest,
    productionApiWorks: input.productionApiSmokeTest,
    voiceSaveWorks: input.voiceSavePath,
    typedSaveWorks: input.typedSavePath,
    firstProofWorks: input.firstProofPath,
    proPromiseVisible: input.proPaywallRoute,
    revenueCatProductsLoad: input.revenueCatProductLoad,
    paywallPriceVisible: paywallPriceVisible,
    sandboxPurchaseWorks: input.sandboxPurchase,
    entitlementUnlocks: entitlementUnlocks ?? input.entitlementPersistence,
    restoreWorks: input.restorePurchases,
    entitlementPersists: input.entitlementPersistence,
    supportPrivacyTermsWork:
        input.supportUrl && input.privacyUrl && input.termsUrl,
    screenshotsReady: input.screenshots,
    testFlightUploaded: input.testFlightUploaded,
    paidIntentBetaComplete: paidIntentBetaComplete,
    secretsRotatedBeforeProduction: input.secretsRotated,
  );

  static SingleLaunchChecklistInput fromCommercialProofExecutorInput(
    CommercialProofExecutorInput input, {
    required ReleaseEvidencePackInput releaseEvidence,
  }) => composeInput(releaseEvidence: releaseEvidence, commercial: input);

  static SingleLaunchChecklistInput composeInput({
    required ReleaseEvidencePackInput releaseEvidence,
    CommercialProofExecutorInput? commercial,
    RevenueCatLiveProofInput? revenueCatLiveProof,
    PaidIntentBetaProofResult? paidIntentBeta,
    SecretsRotationLaunchGateResult? secretsRotation,
  }) {
    final commercialInput = commercial;
    final revenueCat = revenueCatLiveProof;
    return SingleLaunchChecklistInput(
      cleanGit: releaseEvidence.cleanGitStatus,
      versionBuildSet: releaseEvidence.versionBuildCaptured,
      physicalIphoneSmoke: releaseEvidence.physicalIphoneSmokeTest,
      physicalIpadSmoke: releaseEvidence.physicalIpadSmokeTest,
      productionApiWorks: releaseEvidence.productionApiSmokeTest,
      voiceSaveWorks: releaseEvidence.voiceSavePath,
      typedSaveWorks: releaseEvidence.typedSavePath,
      firstProofWorks: releaseEvidence.firstProofPath,
      proPromiseVisible:
          commercialInput?.proPromiseClear ?? releaseEvidence.proPaywallRoute,
      revenueCatProductsLoad:
          commercialInput?.revenueCatProductsLoad ??
          revenueCat?.offeringLoads ??
          releaseEvidence.revenueCatProductLoad,
      paywallPriceVisible:
          commercialInput?.paywallPriceVisible ?? revenueCat?.priceVisible,
      sandboxPurchaseWorks:
          commercialInput?.sandboxPurchaseWorks ??
          revenueCat?.sandboxPurchaseSucceeds ??
          releaseEvidence.sandboxPurchase,
      entitlementUnlocks:
          revenueCat?.proGateUnlocks ??
          revenueCat?.entitlementActiveAfterPurchase ??
          releaseEvidence.entitlementPersistence,
      restoreWorks:
          commercialInput?.restoreWorks ??
          revenueCat?.restorePurchasesSucceeds ??
          releaseEvidence.restorePurchases,
      entitlementPersists:
          commercialInput?.entitlementPersists ??
          revenueCat?.appRestartKeepsEntitlement ??
          releaseEvidence.entitlementPersistence,
      supportPrivacyTermsWork:
          releaseEvidence.supportUrl &&
          releaseEvidence.privacyUrl &&
          releaseEvidence.termsUrl,
      screenshotsReady: releaseEvidence.screenshots,
      testFlightUploaded:
          commercialInput?.testFlightUploaded ??
          releaseEvidence.testFlightUploaded,
      paidIntentBetaComplete:
          commercialInput?.paidIntentBetaComplete ??
          _paidIntentBetaCompleteFrom(paidIntentBeta),
      secretsRotatedBeforeProduction:
          _secretsRotatedFrom(secretsRotation) ??
          commercialInput?.secretsRotationComplete ??
          releaseEvidence.secretsRotated,
    );
  }

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static bool? _secretsRotatedFrom(SecretsRotationLaunchGateResult? result) {
    if (result == null) return null;
    return result.productionSubmissionReady;
  }

  static List<SingleLaunchChecklistCheck> _buildChecks(
    SingleLaunchChecklistInput input,
  ) => [
    for (final id in canonicalChecklistOrder)
      SingleLaunchChecklistCheck(
        id: id,
        label: SingleLaunchChecklistCopy.labelFor(id),
        status: _statusFor(_valueFor(input, id)),
        detailLabel: _detailLabelFor(_statusFor(_valueFor(input, id))),
      ),
  ];

  static SingleLaunchChecklistStatus _resolveStatus(
    SingleLaunchChecklistInput input,
    List<SingleLaunchChecklistCheck> checks,
  ) {
    for (final id in testFlightRequiredItems) {
      final value = _valueFor(input, id);
      if (value != true) {
        return SingleLaunchChecklistStatus.notReady;
      }
    }

    if (input.secretsRotatedBeforeProduction != true) {
      return SingleLaunchChecklistStatus.readyForTestFlight;
    }

    final hasFailure = checks.any(
      (check) => check.status == SingleLaunchChecklistCheckStatus.fail,
    );
    if (hasFailure) {
      return SingleLaunchChecklistStatus.notReady;
    }

    return SingleLaunchChecklistStatus.readyForSubmission;
  }

  static bool? _valueFor(
    SingleLaunchChecklistInput input,
    SingleLaunchChecklistItemId id,
  ) => switch (id) {
    SingleLaunchChecklistItemId.cleanGit => input.cleanGit,
    SingleLaunchChecklistItemId.versionBuildSet => input.versionBuildSet,
    SingleLaunchChecklistItemId.physicalIphoneSmoke =>
      input.physicalIphoneSmoke,
    SingleLaunchChecklistItemId.physicalIpadSmoke => input.physicalIpadSmoke,
    SingleLaunchChecklistItemId.productionApiWorks => input.productionApiWorks,
    SingleLaunchChecklistItemId.voiceSaveWorks => input.voiceSaveWorks,
    SingleLaunchChecklistItemId.typedSaveWorks => input.typedSaveWorks,
    SingleLaunchChecklistItemId.firstProofWorks => input.firstProofWorks,
    SingleLaunchChecklistItemId.proPromiseVisible => input.proPromiseVisible,
    SingleLaunchChecklistItemId.revenueCatProductsLoad =>
      input.revenueCatProductsLoad,
    SingleLaunchChecklistItemId.paywallPriceVisible =>
      input.paywallPriceVisible,
    SingleLaunchChecklistItemId.sandboxPurchaseWorks =>
      input.sandboxPurchaseWorks,
    SingleLaunchChecklistItemId.entitlementUnlocks => input.entitlementUnlocks,
    SingleLaunchChecklistItemId.restoreWorks => input.restoreWorks,
    SingleLaunchChecklistItemId.entitlementPersists =>
      input.entitlementPersists,
    SingleLaunchChecklistItemId.supportPrivacyTermsWork =>
      input.supportPrivacyTermsWork,
    SingleLaunchChecklistItemId.screenshotsReady => input.screenshotsReady,
    SingleLaunchChecklistItemId.testFlightUploaded => input.testFlightUploaded,
    SingleLaunchChecklistItemId.paidIntentBetaComplete =>
      input.paidIntentBetaComplete,
    SingleLaunchChecklistItemId.secretsRotatedBeforeProduction =>
      input.secretsRotatedBeforeProduction,
  };

  static SingleLaunchChecklistCheckStatus _statusFor(bool? value) =>
      switch (value) {
        true => SingleLaunchChecklistCheckStatus.pass,
        false => SingleLaunchChecklistCheckStatus.fail,
        null => SingleLaunchChecklistCheckStatus.pending,
      };

  static String _detailLabelFor(SingleLaunchChecklistCheckStatus status) =>
      switch (status) {
        SingleLaunchChecklistCheckStatus.pass =>
          SingleLaunchChecklistCopy.detailPass,
        SingleLaunchChecklistCheckStatus.fail =>
          SingleLaunchChecklistCopy.detailFail,
        SingleLaunchChecklistCheckStatus.pending =>
          SingleLaunchChecklistCopy.detailPending,
      };
}

class SingleLaunchChecklistInput {
  const SingleLaunchChecklistInput({
    this.cleanGit,
    this.versionBuildSet,
    this.physicalIphoneSmoke,
    this.physicalIpadSmoke,
    this.productionApiWorks,
    this.voiceSaveWorks,
    this.typedSaveWorks,
    this.firstProofWorks,
    this.proPromiseVisible,
    this.revenueCatProductsLoad,
    this.paywallPriceVisible,
    this.sandboxPurchaseWorks,
    this.entitlementUnlocks,
    this.restoreWorks,
    this.entitlementPersists,
    this.supportPrivacyTermsWork,
    this.screenshotsReady,
    this.testFlightUploaded,
    this.paidIntentBetaComplete,
    this.secretsRotatedBeforeProduction,
  });

  final bool? cleanGit;
  final bool? versionBuildSet;
  final bool? physicalIphoneSmoke;
  final bool? physicalIpadSmoke;
  final bool? productionApiWorks;
  final bool? voiceSaveWorks;
  final bool? typedSaveWorks;
  final bool? firstProofWorks;
  final bool? proPromiseVisible;
  final bool? revenueCatProductsLoad;
  final bool? paywallPriceVisible;
  final bool? sandboxPurchaseWorks;
  final bool? entitlementUnlocks;
  final bool? restoreWorks;
  final bool? entitlementPersists;
  final bool? supportPrivacyTermsWork;
  final bool? screenshotsReady;
  final bool? testFlightUploaded;
  final bool? paidIntentBetaComplete;
  final bool? secretsRotatedBeforeProduction;
}

class SingleLaunchChecklistCheck {
  const SingleLaunchChecklistCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final SingleLaunchChecklistItemId id;
  final String label;
  final SingleLaunchChecklistCheckStatus status;
  final String detailLabel;
}

class SingleLaunchChecklistResult {
  const SingleLaunchChecklistResult({
    required this.status,
    required this.message,
    required this.recommendation,
    required this.checks,
    required this.checklistOrder,
    required this.earliestBlocker,
    required this.readyForTestFlight,
    required this.readyForSubmission,
  });

  final SingleLaunchChecklistStatus status;
  final String message;
  final String recommendation;
  final List<SingleLaunchChecklistCheck> checks;
  final List<SingleLaunchChecklistItemId> checklistOrder;
  final SingleLaunchChecklistItemId? earliestBlocker;
  final bool readyForTestFlight;
  final bool readyForSubmission;
}

class SingleLaunchChecklistReport {
  const SingleLaunchChecklistReport({
    required this.headline,
    required this.body,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String orderLine;
  final String guardrail;
  final SingleLaunchChecklistResult result;
}