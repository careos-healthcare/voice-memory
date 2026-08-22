import 'package:archiveme_mobile/features/first_proof_success_beta/first_proof_success_beta_guard.dart';
import 'package:archiveme_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:archiveme_mobile/features/product_language_consistency/product_language_consistency_guard.dart';
import 'package:archiveme_mobile/features/referral_after_proof/referral_after_proof_copy.dart';

/// Referral after proof gate — future referral only after proof value.
abstract final class ReferralAfterProofGate {
  ReferralAfterProofGate._();

  static const ruleCount = 6;

  static const List<ReferralAfterProofRuleId> canonicalRuleOrder = [
    ReferralAfterProofRuleId.onlyAfterProofValue,
    ReferralAfterProofRuleId.neverSharePrivateContent,
    ReferralAfterProofRuleId.inviteSharesProductNotArchive,
    ReferralAfterProofRuleId.notShownInFirstFiveMinutes,
    ReferralAfterProofRuleId.notPartOfPaidPromise,
    ReferralAfterProofRuleId.noLiveReferralUiUnlessGated,
  ];

  static const privateContentViolationMarkers = [
    'share your archive with',
    'share private content with',
    'share your entries with',
    'share my recording with',
    'we share your private content',
  ];

  static const archiveInviteViolationMarkers = [
    'here is my archive',
    'share my journal',
    'copy of my archive',
    'attached my recording',
  ];

  static const paidPromiseViolationMarkers = [
    'invite friends to unlock pro',
    'referral unlocks pro',
    'invite to get pro',
    'refer friends for pro',
  ];

  static ReferralAfterProofGateResult build(ReferralAfterProofGateInput input) {
    final rules = _buildRules(input);
    final rulesPass = rules.every(
      (rule) => rule.status == ReferralAfterProofRuleStatus.pass,
    );
    final proofValueReached = input.proofValueReached ?? false;
    final decision = rulesPass && proofValueReached
        ? ReferralAfterProofGateDecision.referralAfterProofAllowed
        : ReferralAfterProofGateDecision.referralBlocked;
    return ReferralAfterProofGateResult(
      decision: decision,
      message: ReferralAfterProofCopy.messageFor(decision),
      recommendation: ReferralAfterProofCopy.recommendationFor(decision),
      positioning: ReferralAfterProofCopy.positioning,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      proofValueReached: proofValueReached,
      usefulProofAccepted: input.usefulProofAccepted ?? false,
      proPromiseUnderstood: input.proPromiseUnderstood ?? false,
      privateContentSharingBlocked: true,
      paidPromiseBlocked: true,
      firstFiveMinutesSurfacingBlocked: true,
      v1LiveUiBlocked:
          !(input.existingReferralRoutePresent ?? false) ||
          !(input.referralRouteGated ?? false),
      existingReferralRoutePresent: input.existingReferralRoutePresent ?? false,
      referralRouteGated: input.referralRouteGated ?? false,
      earliestRuleFailure: rules
          .where((rule) => rule.status == ReferralAfterProofRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static ReferralAfterProofGateReport report(
    ReferralAfterProofGateResult result,
  ) => ReferralAfterProofGateReport(
    headline: ReferralAfterProofCopy.headline,
    body: ReferralAfterProofCopy.body,
    positioning: ReferralAfterProofCopy.positioning,
    orderLine: ReferralAfterProofCopy.orderLine,
    guardrail: ReferralAfterProofCopy.guardrail,
    result: result,
  );

  static ReferralAfterProofGateInput composeInput({
    bool? usefulProofAccepted,
    bool? proPromiseUnderstood,
    bool? proofValueReached,
    bool? withinFirstFiveMinutes,
    bool? referralPromptRequested,
    bool? existingReferralRoutePresent,
    bool? referralRouteGated,
    FirstProofSuccessBetaInput? firstProofSuccessBeta,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) {
    final resolvedUsefulProofAccepted =
        usefulProofAccepted ??
        firstProofSuccessBeta?.proofAccepted ??
        _usefulProofAcceptedFromPaidIntent(paidIntentBeta);
    final resolvedProPromiseUnderstood =
        proPromiseUnderstood ??
        _proPromiseUnderstoodFromFirstProof(firstProofSuccessBeta) ??
        _proPromiseUnderstoodFromPaidIntent(paidIntentBeta);
    return ReferralAfterProofGateInput(
      usefulProofAccepted: resolvedUsefulProofAccepted,
      proPromiseUnderstood: resolvedProPromiseUnderstood,
      proofValueReached:
          proofValueReached ??
          (resolvedUsefulProofAccepted == true ||
              resolvedProPromiseUnderstood == true),
      withinFirstFiveMinutes: withinFirstFiveMinutes,
      referralPromptRequested: referralPromptRequested,
      existingReferralRoutePresent: existingReferralRoutePresent,
      referralRouteGated: referralRouteGated,
    );
  }

  static ReferralAfterProofGateInput fromRepoSignals({
    required String referralAfterProofDocSource,
    required String gateCopySource,
    required String appRouterSource,
    required String referralImplementationSource,
    bool? usefulProofAccepted,
    bool? proPromiseUnderstood,
    bool? proofValueReached,
    bool? withinFirstFiveMinutes,
    bool? referralPromptRequested,
  }) => ReferralAfterProofGateInput(
    usefulProofAccepted: usefulProofAccepted,
    proPromiseUnderstood: proPromiseUnderstood,
    proofValueReached: proofValueReached,
    withinFirstFiveMinutes: withinFirstFiveMinutes,
    referralPromptRequested: referralPromptRequested,
    existingReferralRoutePresent: detectExistingReferralRouteInRouter(
      appRouterSource,
    ),
    referralRouteGated: detectReferralRouteGatedInImplementation(
      referralImplementationSource,
    ),
    docListsRules: detectDocListsRules(referralAfterProofDocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
  );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'only after proof value',
      'never share private content',
      'invite shares product',
      'not shown in first five minutes',
      'not part of paid promise',
      'no live referral ui',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('proof value') &&
        lower.contains('never share private content') &&
        lower.contains('invite shares product') &&
        lower.contains('not shown in first five minutes') &&
        lower.contains('not part of paid promise') &&
        lower.contains('no live referral ui');
  }

  static bool detectExistingReferralRouteInRouter(String appRouterSource) =>
      appRouterSource.contains("path: '/invite'");

  static bool detectReferralRouteGatedInImplementation(
    String referralImplementationSource,
  ) {
    final lower = referralImplementationSource.toLowerCase();
    return lower.contains('shouldshow') &&
        lower.contains('entrycount <= 1') &&
        lower.contains('never before');
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesPrivateContentShare(copy) &&
      !_violatesArchiveInvite(copy) &&
      !_violatesPaidPromise(copy) &&
      ProductLanguageConsistencyGuard.passesProPromise(copy);

  static bool? _usefulProofAcceptedFromPaidIntent(
    PaidIntentBetaProofResult? result,
  ) => _signalPassed(
    result,
    PaidIntentBetaProofSignalId.proofAcceptedOrCorrected,
  );

  static bool? _proPromiseUnderstoodFromPaidIntent(
    PaidIntentBetaProofResult? result,
  ) => _signalPassed(result, PaidIntentBetaProofSignalId.proPromiseSeen);

  static bool? _signalPassed(
    PaidIntentBetaProofResult? result,
    PaidIntentBetaProofSignalId id,
  ) {
    if (result == null) return null;
    for (final signal in result.signals) {
      if (signal.id == id) {
        return signal.status == PaidIntentBetaProofSignalStatus.pass;
      }
    }
    return null;
  }

  static bool? _proPromiseUnderstoodFromFirstProof(
    FirstProofSuccessBetaInput? input,
  ) {
    if (input == null) return null;
    return input.proPromiseSeen && input.userUnderstoodWhy;
  }

  static List<ReferralAfterProofRule> _buildRules(
    ReferralAfterProofGateInput input,
  ) {
    final copyBundle = [
      ReferralAfterProofCopy.positioning,
      ReferralAfterProofCopy.guardrail,
      ReferralAfterProofCopy.body,
    ].join(' ');
    final guardrailLower = ReferralAfterProofCopy.guardrail.toLowerCase();
    final promptRequested = input.referralPromptRequested ?? false;
    final withinFirstFiveMinutes = input.withinFirstFiveMinutes ?? false;
    return [
      _rule(
        id: ReferralAfterProofRuleId.onlyAfterProofValue,
        passes:
            guardrailLower.contains('proof value') &&
            guardrailLower.contains('useful proof accepted') &&
            (!promptRequested || (input.proofValueReached ?? false)),
      ),
      _rule(
        id: ReferralAfterProofRuleId.neverSharePrivateContent,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('never share private content'),
      ),
      _rule(
        id: ReferralAfterProofRuleId.inviteSharesProductNotArchive,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('invite shares product') &&
            guardrailLower.contains('not user archive'),
      ),
      _rule(
        id: ReferralAfterProofRuleId.notShownInFirstFiveMinutes,
        passes:
            guardrailLower.contains('not shown in first five minutes') &&
            (!withinFirstFiveMinutes || !promptRequested),
      ),
      _rule(
        id: ReferralAfterProofRuleId.notPartOfPaidPromise,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('not part of paid promise'),
      ),
      _rule(
        id: ReferralAfterProofRuleId.noLiveReferralUiUnlessGated,
        passes:
            guardrailLower.contains('no live referral ui') &&
            (!(input.existingReferralRoutePresent ?? false) ||
                (input.referralRouteGated ?? false)),
      ),
    ];
  }

  static bool _violatesPrivateContentShare(String copy) =>
      privateContentViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesArchiveInvite(String copy) =>
      archiveInviteViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesPaidPromise(String copy) =>
      paidPromiseViolationMarkers.any(copy.toLowerCase().contains);

  static ReferralAfterProofRule _rule({
    required ReferralAfterProofRuleId id,
    required bool passes,
  }) => ReferralAfterProofRule(
    id: id,
    label: ReferralAfterProofCopy.ruleLabelFor(id),
    status: passes
        ? ReferralAfterProofRuleStatus.pass
        : ReferralAfterProofRuleStatus.fail,
    detailLabel: passes
        ? ReferralAfterProofCopy.detailPass
        : ReferralAfterProofCopy.detailFail,
  );
}

class ReferralAfterProofGateInput {
  const ReferralAfterProofGateInput({
    this.usefulProofAccepted,
    this.proPromiseUnderstood,
    this.proofValueReached,
    this.withinFirstFiveMinutes,
    this.referralPromptRequested,
    this.existingReferralRoutePresent,
    this.referralRouteGated,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
  });

  final bool? usefulProofAccepted;
  final bool? proPromiseUnderstood;
  final bool? proofValueReached;
  final bool? withinFirstFiveMinutes;
  final bool? referralPromptRequested;
  final bool? existingReferralRoutePresent;
  final bool? referralRouteGated;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
}

class ReferralAfterProofRule {
  const ReferralAfterProofRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final ReferralAfterProofRuleId id;
  final String label;
  final ReferralAfterProofRuleStatus status;
  final String detailLabel;
}

class ReferralAfterProofGateResult {
  const ReferralAfterProofGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.proofValueReached,
    required this.usefulProofAccepted,
    required this.proPromiseUnderstood,
    required this.privateContentSharingBlocked,
    required this.paidPromiseBlocked,
    required this.firstFiveMinutesSurfacingBlocked,
    required this.v1LiveUiBlocked,
    required this.existingReferralRoutePresent,
    required this.referralRouteGated,
    required this.earliestRuleFailure,
  });

  final ReferralAfterProofGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<ReferralAfterProofRule> rules;
  final List<ReferralAfterProofRuleId> ruleOrder;
  final bool rulesPass;
  final bool proofValueReached;
  final bool usefulProofAccepted;
  final bool proPromiseUnderstood;
  final bool privateContentSharingBlocked;
  final bool paidPromiseBlocked;
  final bool firstFiveMinutesSurfacingBlocked;
  final bool v1LiveUiBlocked;
  final bool existingReferralRoutePresent;
  final bool referralRouteGated;
  final ReferralAfterProofRuleId? earliestRuleFailure;
}

class ReferralAfterProofGateReport {
  const ReferralAfterProofGateReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String orderLine;
  final String guardrail;
  final ReferralAfterProofGateResult result;
}