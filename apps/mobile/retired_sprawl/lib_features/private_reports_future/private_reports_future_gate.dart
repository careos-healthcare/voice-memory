import 'package:archiveme_mobile/features/first_proof_success_beta/first_proof_success_beta_copy.dart';
import 'package:archiveme_mobile/features/first_proof_success_beta/first_proof_success_beta_guard.dart';
import 'package:archiveme_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:archiveme_mobile/features/private_reports_future/private_reports_future_copy.dart';
import 'package:archiveme_mobile/features/product_language_consistency/product_language_consistency_guard.dart';

/// Private reports future gate — later upgrade, not launch headline.
abstract final class PrivateReportsFutureGate {
  PrivateReportsFutureGate._();

  static const ruleCount = 7;

  static const List<PrivateReportsFutureRuleId> canonicalRuleOrder = [
    PrivateReportsFutureRuleId.onlyAfterFirstProof,
    PrivateReportsFutureRuleId.notTherapy,
    PrivateReportsFutureRuleId.notDiagnosis,
    PrivateReportsFutureRuleId.notMedical,
    PrivateReportsFutureRuleId.notTherapistReadyClaim,
    PrivateReportsFutureRuleId.notPrimaryProPromise,
    PrivateReportsFutureRuleId.futureProAddOnAfterTrailConverts,
  ];

  static const therapyViolationMarkers = [
    'therapy session',
    'therapy tool',
    'replace therapy',
    'therapeutic treatment',
  ];

  static const diagnosisViolationMarkers = [
    'clinical diagnosis',
    'diagnose you',
    'diagnosis report',
  ];

  static const medicalViolationMarkers = [
    'medical advice',
    'medical diagnosis',
    'medical report',
    'medical device',
  ];

  static const therapistReadyViolationMarkers = [
    'therapist-ready',
    'therapist ready',
    'share with your therapist automatically',
    'ready for your therapist',
  ];

  static const primaryProPromiseViolationMarkers = [
    'unlock reports',
    'reports are what pro',
    'main benefit: reports',
    'primary pro promise: reports',
    'pro gives you private reports',
  ];

  static PrivateReportsFutureGateResult build(
    PrivateReportsFutureGateInput input,
  ) {
    final rules = _buildRules(input);
    final rulesPass = rules.every(
      (rule) => rule.status == PrivateReportsFutureRuleStatus.pass,
    );
    final trailConverts = input.longerProofTrailConverts ?? false;
    final firstProofSeen = input.firstProofSeen ?? false;
    final futureAddOnAllowed = rulesPass && firstProofSeen && trailConverts;
    final decision = futureAddOnAllowed
        ? PrivateReportsFutureGateDecision.futureProAddOnAllowed
        : PrivateReportsFutureGateDecision.laterUpgradeOnly;
    return PrivateReportsFutureGateResult(
      decision: decision,
      message: PrivateReportsFutureCopy.messageFor(decision),
      recommendation: PrivateReportsFutureCopy.recommendationFor(decision),
      positioning: PrivateReportsFutureCopy.positioning,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      launchHeadlineBlocked: true,
      primaryProPromiseBlocked: true,
      firstProofSeen: firstProofSeen,
      longerProofTrailConverts: trailConverts,
      earliestRuleFailure: rules
          .where((rule) => rule.status == PrivateReportsFutureRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static PrivateReportsFutureGateReport report(
    PrivateReportsFutureGateResult result,
  ) => PrivateReportsFutureGateReport(
    headline: PrivateReportsFutureCopy.headline,
    body: PrivateReportsFutureCopy.body,
    positioning: PrivateReportsFutureCopy.positioning,
    orderLine: PrivateReportsFutureCopy.orderLine,
    guardrail: PrivateReportsFutureCopy.guardrail,
    result: result,
  );

  static PrivateReportsFutureGateInput composeInput({
    bool? firstProofSeen,
    bool? longerProofTrailConverts,
    FirstProofSuccessBetaResult? firstProofSuccessBeta,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) => PrivateReportsFutureGateInput(
    firstProofSeen:
        firstProofSeen ??
        _firstProofSeenFrom(firstProofSuccessBeta) ??
        _firstProofSeenFromPaidIntent(paidIntentBeta),
    longerProofTrailConverts:
        longerProofTrailConverts ??
        _trailConvertsFromFirstProof(firstProofSuccessBeta) ??
        _trailConvertsFromPaidIntent(paidIntentBeta),
  );

  static PrivateReportsFutureGateInput fromRepoSignals({
    required String privateReportsFutureDocSource,
    required String gateCopySource,
    bool? firstProofSeen,
    bool? longerProofTrailConverts,
  }) => PrivateReportsFutureGateInput(
    firstProofSeen: firstProofSeen,
    longerProofTrailConverts: longerProofTrailConverts,
    docListsRules: detectDocListsRules(privateReportsFutureDocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
  );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'only after first proof',
      'not primary pro promise',
      'future pro add-on',
      'later upgrade',
      'launch headline',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('later upgrade') &&
        lower.contains('only after first proof') &&
        lower.contains('not the primary pro promise') &&
        lower.contains('therapist-ready');
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesTherapy(copy) &&
      !_violatesDiagnosis(copy) &&
      !_violatesMedical(copy) &&
      !_violatesTherapistReadyClaim(copy) &&
      !_violatesPrimaryProPromise(copy) &&
      ProductLanguageConsistencyGuard.passesProPromise(copy);

  static bool? _firstProofSeenFrom(FirstProofSuccessBetaResult? result) {
    if (result == null) return null;
    return result.proofWorking;
  }

  static bool? _trailConvertsFromFirstProof(
    FirstProofSuccessBetaResult? result,
  ) {
    if (result == null) return null;
    return result.decision ==
        FirstProofSuccessBetaDecision.proofStrongEnoughForPro;
  }

  static bool? _firstProofSeenFromPaidIntent(
    PaidIntentBetaProofResult? result,
  ) {
    if (result == null) return null;
    return result.decision != PaidIntentBetaProofDecision.insufficientData &&
        result.decision != PaidIntentBetaProofDecision.proofNotReached;
  }

  static bool? _trailConvertsFromPaidIntent(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static List<PrivateReportsFutureRule> _buildRules(
    PrivateReportsFutureGateInput input,
  ) {
    final copyBundle = [
      PrivateReportsFutureCopy.positioning,
      PrivateReportsFutureCopy.guardrail,
      PrivateReportsFutureCopy.body,
    ].join(' ');
    return [
      _rule(
        id: PrivateReportsFutureRuleId.onlyAfterFirstProof,
        passes: PrivateReportsFutureCopy.guardrail.toLowerCase().contains(
          'only after first proof',
        ),
      ),
      _rule(
        id: PrivateReportsFutureRuleId.notTherapy,
        passes: evaluateCopyPassesRules(copyBundle),
      ),
      _rule(
        id: PrivateReportsFutureRuleId.notDiagnosis,
        passes: evaluateCopyPassesRules(copyBundle),
      ),
      _rule(
        id: PrivateReportsFutureRuleId.notMedical,
        passes: evaluateCopyPassesRules(copyBundle),
      ),
      _rule(
        id: PrivateReportsFutureRuleId.notTherapistReadyClaim,
        passes: evaluateCopyPassesRules(copyBundle),
      ),
      _rule(
        id: PrivateReportsFutureRuleId.notPrimaryProPromise,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            PrivateReportsFutureCopy.guardrail.toLowerCase().contains(
              'not the primary pro promise',
            ),
      ),
      _rule(
        id: PrivateReportsFutureRuleId.futureProAddOnAfterTrailConverts,
        passes:
            !(input.longerProofTrailConverts ?? false) ||
            (input.firstProofSeen ?? false),
      ),
    ];
  }

  static bool _violatesTherapy(String copy) =>
      therapyViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesDiagnosis(String copy) =>
      diagnosisViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesMedical(String copy) =>
      medicalViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesTherapistReadyClaim(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in therapistReadyViolationMarkers) {
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

  static bool _violatesPrimaryProPromise(String copy) =>
      primaryProPromiseViolationMarkers.any(copy.toLowerCase().contains);

  static PrivateReportsFutureRule _rule({
    required PrivateReportsFutureRuleId id,
    required bool passes,
  }) => PrivateReportsFutureRule(
    id: id,
    label: PrivateReportsFutureCopy.ruleLabelFor(id),
    status: passes
        ? PrivateReportsFutureRuleStatus.pass
        : PrivateReportsFutureRuleStatus.fail,
    detailLabel: passes
        ? PrivateReportsFutureCopy.detailPass
        : PrivateReportsFutureCopy.detailFail,
  );
}

class PrivateReportsFutureGateInput {
  const PrivateReportsFutureGateInput({
    this.firstProofSeen,
    this.longerProofTrailConverts,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
  });

  final bool? firstProofSeen;
  final bool? longerProofTrailConverts;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
}

class PrivateReportsFutureRule {
  const PrivateReportsFutureRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PrivateReportsFutureRuleId id;
  final String label;
  final PrivateReportsFutureRuleStatus status;
  final String detailLabel;
}

class PrivateReportsFutureGateResult {
  const PrivateReportsFutureGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.launchHeadlineBlocked,
    required this.primaryProPromiseBlocked,
    required this.firstProofSeen,
    required this.longerProofTrailConverts,
    required this.earliestRuleFailure,
  });

  final PrivateReportsFutureGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<PrivateReportsFutureRule> rules;
  final List<PrivateReportsFutureRuleId> ruleOrder;
  final bool rulesPass;
  final bool launchHeadlineBlocked;
  final bool primaryProPromiseBlocked;
  final bool firstProofSeen;
  final bool longerProofTrailConverts;
  final PrivateReportsFutureRuleId? earliestRuleFailure;
}

class PrivateReportsFutureGateReport {
  const PrivateReportsFutureGateReport({
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
  final PrivateReportsFutureGateResult result;
}