import 'package:archiveme_mobile/features/first_proof_success_beta/first_proof_success_beta_copy.dart';
import 'package:archiveme_mobile/features/first_proof_success_beta/first_proof_success_beta_guard.dart';
import 'package:archiveme_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:archiveme_mobile/features/single_launch_checklist/single_launch_checklist.dart';
import 'package:archiveme_mobile/features/three_day_proof_challenge/three_day_proof_challenge_copy.dart';

/// Three day proof challenge gate — future acquisition without V1 changes.
abstract final class ThreeDayProofChallengeGate {
  ThreeDayProofChallengeGate._();

  static const ruleCount = 4;
  static const String canonicalPromise = ThreeDayProofChallengeCopy.promise;

  static const List<ThreeDayProofChallengeRuleId> canonicalRuleOrder = [
    ThreeDayProofChallengeRuleId.futureAcquisitionOnly,
    ThreeDayProofChallengeRuleId.noStreaks,
    ThreeDayProofChallengeRuleId.noDailyPressure,
    ThreeDayProofChallengeRuleId.noRequiredCheckIn,
  ];

  static const streakViolationMarkers = [
    "don't break the chain",
    'keep your streak',
    'streak alive',
    'maintain your streak',
  ];

  static const dailyPressureViolationMarkers = [
    'daily journal required',
    'every single day',
    'must save daily',
  ];

  static const requiredCheckInViolationMarkers = [
    'must check in',
    'daily check-in',
    'daily check in',
  ];

  static ThreeDayProofChallengeGateResult build(
    ThreeDayProofChallengeGateInput input,
  ) {
    final rules = _buildRules(input);
    final rulesPass = rules.every(
      (rule) => rule.status == ThreeDayProofChallengeRuleStatus.pass,
    );
    final v1SurfacingAllowed =
        rulesPass &&
        (input.paidIntentBetaComplete ?? false) &&
        (input.usersNeedThreeDayChallenge ?? false);
    final decision = v1SurfacingAllowed
        ? ThreeDayProofChallengeGateDecision.v1SurfacingAllowed
        : ThreeDayProofChallengeGateDecision.futureAcquisitionOnly;
    return ThreeDayProofChallengeGateResult(
      decision: decision,
      message: ThreeDayProofChallengeCopy.messageFor(decision),
      recommendation: ThreeDayProofChallengeCopy.recommendationFor(decision),
      promise: canonicalPromise,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      v1SurfacingBlocked: !v1SurfacingAllowed,
      paidIntentBetaComplete: input.paidIntentBetaComplete ?? false,
      usersNeedThreeDayChallenge: input.usersNeedThreeDayChallenge ?? false,
      earliestRuleFailure: rules
          .where((rule) => rule.status == ThreeDayProofChallengeRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static ThreeDayProofChallengeGateReport report(
    ThreeDayProofChallengeGateResult result,
  ) => ThreeDayProofChallengeGateReport(
    headline: ThreeDayProofChallengeCopy.headline,
    body: ThreeDayProofChallengeCopy.body,
    promise: ThreeDayProofChallengeCopy.promise,
    orderLine: ThreeDayProofChallengeCopy.orderLine,
    guardrail: ThreeDayProofChallengeCopy.guardrail,
    result: result,
  );

  static ThreeDayProofChallengeGateInput composeInput({
    bool? paidIntentBetaComplete,
    bool? usersNeedThreeDayChallenge,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
    FirstProofSuccessBetaResult? firstProofSuccessBeta,
  }) => ThreeDayProofChallengeGateInput(
    paidIntentBetaComplete:
        paidIntentBetaComplete ??
        launchChecklist?.paidIntentBetaComplete ??
        _paidIntentBetaCompleteFrom(paidIntentBeta),
    usersNeedThreeDayChallenge:
        usersNeedThreeDayChallenge ??
        _usersNeedFromFirstProof(firstProofSuccessBeta) ??
        _usersNeedFromPaidIntent(paidIntentBeta),
  );

  static ThreeDayProofChallengeGateInput fromRepoSignals({
    required String threeDayProofChallengeDocSource,
    required String gateCopySource,
    bool? paidIntentBetaComplete,
    bool? usersNeedThreeDayChallenge,
  }) => ThreeDayProofChallengeGateInput(
    paidIntentBetaComplete: paidIntentBetaComplete,
    usersNeedThreeDayChallenge: usersNeedThreeDayChallenge,
    docListsPromise: detectDocListsPromise(threeDayProofChallengeDocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
  );

  static bool detectDocListsPromise(String docSource) =>
      docSource.contains(canonicalPromise);

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('do not add') &&
        lower.contains('streaks') &&
        lower.contains('daily pressure') &&
        lower.contains('required check-ins') &&
        lower.contains('paid-intent beta shows users need this');
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesNoStreaks(copy) &&
      !_violatesNoDailyPressure(copy) &&
      !_violatesNoRequiredCheckIn(copy);

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static bool? _usersNeedFromFirstProof(FirstProofSuccessBetaResult? result) {
    if (result == null) return null;
    return result.decision == FirstProofSuccessBetaDecision.notEnoughMoments;
  }

  static bool? _usersNeedFromPaidIntent(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.decision == PaidIntentBetaProofDecision.proofNotReached;
  }

  static List<ThreeDayProofChallengeRule> _buildRules(
    ThreeDayProofChallengeGateInput input,
  ) {
    final copyBundle = [
      canonicalPromise,
      ThreeDayProofChallengeCopy.guardrail,
      ThreeDayProofChallengeCopy.body,
    ].join(' ');
    return [
      _rule(
        id: ThreeDayProofChallengeRuleId.futureAcquisitionOnly,
        passes: ThreeDayProofChallengeCopy.guardrail.toLowerCase().contains(
          'future acquisition',
        ),
      ),
      _rule(
        id: ThreeDayProofChallengeRuleId.noStreaks,
        passes: evaluateCopyPassesRules(copyBundle),
      ),
      _rule(
        id: ThreeDayProofChallengeRuleId.noDailyPressure,
        passes: evaluateCopyPassesRules(copyBundle),
      ),
      _rule(
        id: ThreeDayProofChallengeRuleId.noRequiredCheckIn,
        passes: evaluateCopyPassesRules(copyBundle),
      ),
    ];
  }

  static bool _violatesNoStreaks(String copy) =>
      streakViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesNoDailyPressure(String copy) =>
      dailyPressureViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesNoRequiredCheckIn(String copy) =>
      requiredCheckInViolationMarkers.any(copy.toLowerCase().contains);

  static ThreeDayProofChallengeRule _rule({
    required ThreeDayProofChallengeRuleId id,
    required bool passes,
  }) => ThreeDayProofChallengeRule(
    id: id,
    label: ThreeDayProofChallengeCopy.ruleLabelFor(id),
    status: passes
        ? ThreeDayProofChallengeRuleStatus.pass
        : ThreeDayProofChallengeRuleStatus.fail,
    detailLabel: passes
        ? ThreeDayProofChallengeCopy.detailPass
        : ThreeDayProofChallengeCopy.detailFail,
  );
}

class ThreeDayProofChallengeGateInput {
  const ThreeDayProofChallengeGateInput({
    this.paidIntentBetaComplete,
    this.usersNeedThreeDayChallenge,
    this.docListsPromise = true,
    this.guardrailPresentInCopy = true,
  });

  final bool? paidIntentBetaComplete;
  final bool? usersNeedThreeDayChallenge;
  final bool docListsPromise;
  final bool guardrailPresentInCopy;
}

class ThreeDayProofChallengeRule {
  const ThreeDayProofChallengeRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final ThreeDayProofChallengeRuleId id;
  final String label;
  final ThreeDayProofChallengeRuleStatus status;
  final String detailLabel;
}

class ThreeDayProofChallengeGateResult {
  const ThreeDayProofChallengeGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.promise,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.v1SurfacingBlocked,
    required this.paidIntentBetaComplete,
    required this.usersNeedThreeDayChallenge,
    required this.earliestRuleFailure,
  });

  final ThreeDayProofChallengeGateDecision decision;
  final String message;
  final String recommendation;
  final String promise;
  final List<ThreeDayProofChallengeRule> rules;
  final List<ThreeDayProofChallengeRuleId> ruleOrder;
  final bool rulesPass;
  final bool v1SurfacingBlocked;
  final bool paidIntentBetaComplete;
  final bool usersNeedThreeDayChallenge;
  final ThreeDayProofChallengeRuleId? earliestRuleFailure;
}

class ThreeDayProofChallengeGateReport {
  const ThreeDayProofChallengeGateReport({
    required this.headline,
    required this.body,
    required this.promise,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String promise;
  final String orderLine;
  final String guardrail;
  final ThreeDayProofChallengeGateResult result;
}