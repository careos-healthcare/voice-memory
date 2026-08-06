import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../single_launch_checklist/single_launch_checklist.dart';
import 'contradiction_change_future_copy.dart';

/// Contradiction change future gate — future premium change detection only.
abstract final class ContradictionChangeFutureGate {
  ContradictionChangeFutureGate._();

  static const ruleCount = 7;
  static const prereqCount = 2;

  static const canonicalFutureValueLanguage = [
    'you used to say this',
    'now your saved moments show something different',
    'this repeat may be changing',
  ];

  static const canonicalRuleOrder = [
    ContradictionChangeFutureRuleId.futureValueLanguageDocumented,
    ContradictionChangeFutureRuleId.strongProofTrailRequired,
    ContradictionChangeFutureRuleId.correctionAllowed,
    ContradictionChangeFutureRuleId.noClinicalLabelFraming,
    ContradictionChangeFutureRuleId.noCoachingLanguage,
    ContradictionChangeFutureRuleId.noForecastLanguage,
    ContradictionChangeFutureRuleId.noNewLiveV1Ui,
  ];

  static const canonicalPrereqOrder = [
    ContradictionChangeFuturePrereqId.strongProofTrailComplete,
    ContradictionChangeFuturePrereqId.paidIntentBetaComplete,
  ];

  static const clinicalLabelViolationMarkers = [
    'clinical diagnosis',
    'diagnose you',
    'diagnosis report',
    'this means you have',
    'clinical-label report',
  ];

  static const coachingViolationMarkers = [
    'you should',
    'you need to',
    'try this',
    'recommendations',
    'what to try',
    'directive plan',
  ];

  static const forecastViolationMarkers = [
    'you will change',
    'this will happen',
    'predict that',
    'expect this to',
    'going to become',
    'forecast that',
  ];

  static ContradictionChangeFutureGateResult build(
    ContradictionChangeFutureGateInput input,
  ) {
    final rules = _buildRules(input);
    final prereqs = _buildPrereqs(input);
    final rulesPass = rules.every(
      (rule) => rule.status == ContradictionChangeFutureRuleStatus.pass,
    );
    final proofTrailComplete = prereqs.every(
      (prereq) => prereq.status == ContradictionChangeFuturePrereqStatus.pass,
    );
    final decision = rulesPass && proofTrailComplete
        ? ContradictionChangeFutureGateDecision.futureChangeDetectionDocumented
        : ContradictionChangeFutureGateDecision.changeFrozen;
    return ContradictionChangeFutureGateResult(
      decision: decision,
      message: ContradictionChangeFutureCopy.messageFor(decision),
      recommendation: ContradictionChangeFutureCopy.recommendationFor(decision),
      positioning: ContradictionChangeFutureCopy.positioning,
      futureValueLanguage: canonicalFutureValueLanguage,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      proofTrailComplete: proofTrailComplete,
      v1LiveUiBlocked: true,
      coachingLanguageBlocked: true,
      forecastLanguageBlocked: true,
      clinicalLabelBlocked: true,
      earliestPrereqGap: prereqs
          .where(
            (prereq) =>
                prereq.status != ContradictionChangeFuturePrereqStatus.pass,
          )
          .map((prereq) => prereq.id)
          .firstOrNull,
      earliestRuleFailure: rules
          .where(
            (rule) => rule.status == ContradictionChangeFutureRuleStatus.fail,
          )
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static ContradictionChangeFutureGateReport report(
    ContradictionChangeFutureGateResult result,
  ) => ContradictionChangeFutureGateReport(
    headline: ContradictionChangeFutureCopy.headline,
    body: ContradictionChangeFutureCopy.body,
    positioning: ContradictionChangeFutureCopy.positioning,
    futureValueLine: ContradictionChangeFutureCopy.futureValueLine,
    orderLine: ContradictionChangeFutureCopy.orderLine,
    prereqOrderLine: ContradictionChangeFutureCopy.prereqOrderLine,
    guardrail: ContradictionChangeFutureCopy.guardrail,
    result: result,
  );

  static ContradictionChangeFutureGateInput composeInput({
    bool? strongProofTrailComplete,
    bool? paidIntentBetaComplete,
    bool? v1ChangeDetectionUiRequested,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) => ContradictionChangeFutureGateInput(
    strongProofTrailComplete:
        strongProofTrailComplete ??
        _strongProofTrailCompleteFrom(paidIntentBeta),
    paidIntentBetaComplete:
        paidIntentBetaComplete ??
        launchChecklist?.paidIntentBetaComplete ??
        _paidIntentBetaCompleteFrom(paidIntentBeta),
    v1ChangeDetectionUiRequested: v1ChangeDetectionUiRequested,
  );

  static ContradictionChangeFutureGateInput fromRepoSignals({
    required String contradictionChangeFutureDocSource,
    required String gateCopySource,
    bool? strongProofTrailComplete,
    bool? paidIntentBetaComplete,
    bool? v1ChangeDetectionUiRequested,
  }) => ContradictionChangeFutureGateInput(
    strongProofTrailComplete: strongProofTrailComplete,
    paidIntentBetaComplete: paidIntentBetaComplete,
    v1ChangeDetectionUiRequested: v1ChangeDetectionUiRequested,
    docListsRules: detectDocListsRules(contradictionChangeFutureDocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
    futureValuePresentInCopy: detectFutureValuePresentInCopy(gateCopySource),
  );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'you used to say this',
      'now your saved moments show something different',
      'this repeat may be changing',
      'strong proof trail',
      'correction allowed',
      'clinical-label',
      'directive',
      'forecast',
      'no new live v1 ui',
      'future premium change detection',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('future premium change detection') &&
        lower.contains('strong proof trail') &&
        lower.contains('correction allowed') &&
        lower.contains('do not add clinical-label') &&
        lower.contains('directive') &&
        lower.contains('forecast') &&
        lower.contains('no new live v1 ui');
  }

  static bool detectFutureValuePresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return canonicalFutureValueLanguage.every(lower.contains);
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesClinicalLabel(copy) &&
      !_violatesCoaching(copy) &&
      !_violatesForecast(copy);

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static bool? _strongProofTrailCompleteFrom(
    PaidIntentBetaProofResult? result,
  ) {
    if (result == null) return null;
    return result.signals.any(
          (signal) =>
              signal.id == PaidIntentBetaProofSignalId.firstUsefulProofSeen &&
              signal.status == PaidIntentBetaProofSignalStatus.pass,
        ) &&
        result.signals.any(
          (signal) =>
              signal.id ==
                  PaidIntentBetaProofSignalId.proofAcceptedOrCorrected &&
              signal.status == PaidIntentBetaProofSignalStatus.pass,
        );
  }

  static List<ContradictionChangeFutureRule> _buildRules(
    ContradictionChangeFutureGateInput input,
  ) {
    final copyBundle = [
      ContradictionChangeFutureCopy.positioning,
      ContradictionChangeFutureCopy.futureValueLine,
      ContradictionChangeFutureCopy.guardrail,
      ContradictionChangeFutureCopy.body,
    ].join(' ');
    final guardrailLower = ContradictionChangeFutureCopy.guardrail
        .toLowerCase();
    final proofTrailComplete = input.strongProofTrailComplete ?? false;
    return [
      _rule(
        id: ContradictionChangeFutureRuleId.futureValueLanguageDocumented,
        passes: canonicalFutureValueLanguage.every(
          copyBundle.toLowerCase().contains,
        ),
      ),
      _rule(
        id: ContradictionChangeFutureRuleId.strongProofTrailRequired,
        passes:
            guardrailLower.contains('requires strong proof trail') &&
            (!(input.v1ChangeDetectionUiRequested ?? false) ||
                proofTrailComplete),
      ),
      _rule(
        id: ContradictionChangeFutureRuleId.correctionAllowed,
        passes: guardrailLower.contains('correction allowed'),
      ),
      _rule(
        id: ContradictionChangeFutureRuleId.noClinicalLabelFraming,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('clinical-label'),
      ),
      _rule(
        id: ContradictionChangeFutureRuleId.noCoachingLanguage,
        passes:
            !_violatesCoaching(copyBundle) &&
            guardrailLower.contains('directive'),
      ),
      _rule(
        id: ContradictionChangeFutureRuleId.noForecastLanguage,
        passes:
            !_violatesForecast(copyBundle) &&
            guardrailLower.contains('forecast'),
      ),
      _rule(
        id: ContradictionChangeFutureRuleId.noNewLiveV1Ui,
        passes:
            guardrailLower.contains('no new live v1 ui') &&
            (!(input.v1ChangeDetectionUiRequested ?? false) ||
                proofTrailComplete),
      ),
    ];
  }

  static List<ContradictionChangeFuturePrereq> _buildPrereqs(
    ContradictionChangeFutureGateInput input,
  ) => [
    _prereq(
      id: ContradictionChangeFuturePrereqId.strongProofTrailComplete,
      value: input.strongProofTrailComplete,
    ),
    _prereq(
      id: ContradictionChangeFuturePrereqId.paidIntentBetaComplete,
      value: input.paidIntentBetaComplete,
    ),
  ];

  static bool _violatesClinicalLabel(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in clinicalLabelViolationMarkers) {
      var index = 0;
      while (true) {
        index = lower.indexOf(marker, index);
        if (index < 0) break;
        if (!_markerInProhibitionContext(lower, index)) return true;
        index += marker.length;
      }
    }
    return false;
  }

  static bool _violatesCoaching(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in coachingViolationMarkers) {
      var index = 0;
      while (true) {
        index = lower.indexOf(marker, index);
        if (index < 0) break;
        if (!_markerInProhibitionContext(lower, index)) return true;
        index += marker.length;
      }
    }
    return false;
  }

  static bool _violatesForecast(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in forecastViolationMarkers) {
      var index = 0;
      while (true) {
        index = lower.indexOf(marker, index);
        if (index < 0) break;
        if (!_markerInProhibitionContext(lower, index)) return true;
        index += marker.length;
      }
    }
    return false;
  }

  static bool _markerInProhibitionContext(String lower, int markerStart) {
    final prefix = lower.substring(0, markerStart);
    const prohibitionMarkers = ['avoid ', 'without ', 'never ', 'no ', 'not '];
    for (final marker in prohibitionMarkers) {
      final index = prefix.lastIndexOf(marker);
      if (index < 0) continue;
      final between = prefix.substring(index + marker.length);
      if (!between.contains('. ')) return true;
    }
    return false;
  }

  static ContradictionChangeFuturePrereqStatus _statusFor(bool? value) =>
      switch (value) {
        true => ContradictionChangeFuturePrereqStatus.pass,
        false => ContradictionChangeFuturePrereqStatus.fail,
        null => ContradictionChangeFuturePrereqStatus.pending,
      };

  static ContradictionChangeFuturePrereq _prereq({
    required ContradictionChangeFuturePrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return ContradictionChangeFuturePrereq(
      id: id,
      label: ContradictionChangeFutureCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        ContradictionChangeFuturePrereqStatus.pass =>
          ContradictionChangeFutureCopy.detailPass,
        ContradictionChangeFuturePrereqStatus.pending =>
          ContradictionChangeFutureCopy.detailPending,
        ContradictionChangeFuturePrereqStatus.fail =>
          ContradictionChangeFutureCopy.detailFail,
      },
    );
  }

  static ContradictionChangeFutureRule _rule({
    required ContradictionChangeFutureRuleId id,
    required bool passes,
  }) => ContradictionChangeFutureRule(
    id: id,
    label: ContradictionChangeFutureCopy.ruleLabelFor(id),
    status: passes
        ? ContradictionChangeFutureRuleStatus.pass
        : ContradictionChangeFutureRuleStatus.fail,
    detailLabel: passes
        ? ContradictionChangeFutureCopy.detailPass
        : ContradictionChangeFutureCopy.detailFail,
  );
}

class ContradictionChangeFutureGateInput {
  const ContradictionChangeFutureGateInput({
    this.strongProofTrailComplete,
    this.paidIntentBetaComplete,
    this.v1ChangeDetectionUiRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
    this.futureValuePresentInCopy = true,
  });

  final bool? strongProofTrailComplete;
  final bool? paidIntentBetaComplete;
  final bool? v1ChangeDetectionUiRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
  final bool futureValuePresentInCopy;
}

class ContradictionChangeFutureRule {
  const ContradictionChangeFutureRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final ContradictionChangeFutureRuleId id;
  final String label;
  final ContradictionChangeFutureRuleStatus status;
  final String detailLabel;
}

class ContradictionChangeFuturePrereq {
  const ContradictionChangeFuturePrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final ContradictionChangeFuturePrereqId id;
  final String label;
  final ContradictionChangeFuturePrereqStatus status;
  final String detailLabel;
}

class ContradictionChangeFutureGateResult {
  const ContradictionChangeFutureGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.futureValueLanguage,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.prereqs,
    required this.prereqOrder,
    required this.proofTrailComplete,
    required this.v1LiveUiBlocked,
    required this.coachingLanguageBlocked,
    required this.forecastLanguageBlocked,
    required this.clinicalLabelBlocked,
    required this.earliestPrereqGap,
    required this.earliestRuleFailure,
  });

  final ContradictionChangeFutureGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<String> futureValueLanguage;
  final List<ContradictionChangeFutureRule> rules;
  final List<ContradictionChangeFutureRuleId> ruleOrder;
  final bool rulesPass;
  final List<ContradictionChangeFuturePrereq> prereqs;
  final List<ContradictionChangeFuturePrereqId> prereqOrder;
  final bool proofTrailComplete;
  final bool v1LiveUiBlocked;
  final bool coachingLanguageBlocked;
  final bool forecastLanguageBlocked;
  final bool clinicalLabelBlocked;
  final ContradictionChangeFuturePrereqId? earliestPrereqGap;
  final ContradictionChangeFutureRuleId? earliestRuleFailure;
}

class ContradictionChangeFutureGateReport {
  const ContradictionChangeFutureGateReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.futureValueLine,
    required this.orderLine,
    required this.prereqOrderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String futureValueLine;
  final String orderLine;
  final String prereqOrderLine;
  final String guardrail;
  final ContradictionChangeFutureGateResult result;
}
