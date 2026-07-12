import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../product_language_consistency/product_language_consistency_guard.dart';
import '../single_launch_checklist/single_launch_checklist.dart';
import 'b2b_workplace_pressure_future_copy.dart';

/// B2B workplace pressure future gate — future landing positioning only.
abstract final class B2bWorkplacePressureFutureGate {
  B2bWorkplacePressureFutureGate._();

  static const audienceCount = 6;
  static const prereqCount = 2;
  static const ruleCount = 5;

  static const canonicalAudienceOrder = [
    B2bWorkplacePressureAudienceId.founders,
    B2bWorkplacePressureAudienceId.managers,
    B2bWorkplacePressureAudienceId.carers,
    B2bWorkplacePressureAudienceId.highResponsibilityWorkers,
    B2bWorkplacePressureAudienceId.peopleWhoOvercommit,
    B2bWorkplacePressureAudienceId.peopleWhoSayYesWithNoCapacity,
  ];

  static const canonicalPrereqOrder = [
    B2bWorkplacePressureFuturePrereqId.testFlightUploaded,
    B2bWorkplacePressureFuturePrereqId.paidIntentBetaComplete,
  ];

  static const canonicalRuleOrder = [
    B2bWorkplacePressureFutureRuleId.noEmployerDashboard,
    B2bWorkplacePressureFutureRuleId.noEmployeeSurveillance,
    B2bWorkplacePressureFutureRuleId.noMedicalTherapyClaims,
    B2bWorkplacePressureFutureRuleId.noLiveB2bUi,
    B2bWorkplacePressureFutureRuleId.futureLandingPositioningOnly,
  ];

  static const audienceWedgeIdByAudience = {
    B2bWorkplacePressureAudienceId.founders: 'founders',
    B2bWorkplacePressureAudienceId.managers: 'managers',
    B2bWorkplacePressureAudienceId.carers: 'carers',
    B2bWorkplacePressureAudienceId.highResponsibilityWorkers:
        'highResponsibilityWorkers',
    B2bWorkplacePressureAudienceId.peopleWhoOvercommit: 'peopleWhoOvercommit',
    B2bWorkplacePressureAudienceId.peopleWhoSayYesWithNoCapacity:
        'peopleWhoSayYesWithNoCapacity',
  };

  static const employerDashboardViolationMarkers = [
    'employer dashboard for',
    'your employer dashboard',
    'manager dashboard for your team',
  ];

  static const employeeSurveillanceViolationMarkers = [
    'employee surveillance',
    'monitor your employees',
    'track employee wellbeing',
    'surveillance dashboard',
  ];

  static const medicalTherapyViolationMarkers = [
    'medical advice for',
    'therapy tool for',
    'clinical diagnosis of',
    'therapeutic treatment for',
  ];

  static B2bWorkplacePressureFutureGateResult build(
    B2bWorkplacePressureFutureGateInput input,
  ) {
    final rules = _buildRules(input);
    final prereqs = _buildPrereqs(input);
    final rulesPass = rules.every(
      (rule) => rule.status == B2bWorkplacePressureFutureRuleStatus.pass,
    );
    final betaProofComplete = rulesPass &&
        prereqs.every(
          (prereq) => prereq.status == B2bWorkplacePressureFuturePrereqStatus.pass,
        );
    final decision = betaProofComplete
        ? B2bWorkplacePressureFutureGateDecision.futureLandingPositioningDocumented
        : B2bWorkplacePressureFutureGateDecision.b2bFrozen;
    final audiences = _buildAudiences(betaProofComplete: betaProofComplete);
    return B2bWorkplacePressureFutureGateResult(
      decision: decision,
      message: B2bWorkplacePressureFutureCopy.messageFor(decision),
      recommendation: B2bWorkplacePressureFutureCopy.recommendationFor(decision),
      positioning: B2bWorkplacePressureFutureCopy.positioning,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      audiences: audiences,
      audienceOrder: canonicalAudienceOrder,
      betaProofComplete: betaProofComplete,
      v1LiveB2bUiBlocked: true,
      employerDashboardBlocked: true,
      employeeSurveillanceBlocked: true,
      medicalTherapyClaimsBlocked: true,
      earliestPrereqGap: prereqs
          .where(
            (prereq) =>
                prereq.status != B2bWorkplacePressureFuturePrereqStatus.pass,
          )
          .map((prereq) => prereq.id)
          .firstOrNull,
      earliestRuleFailure: rules
          .where(
            (rule) => rule.status == B2bWorkplacePressureFutureRuleStatus.fail,
          )
          .map((rule) => rule.id)
          .firstOrNull,
      documentedAudienceCount: audiences
          .where(
            (audience) =>
                audience.status ==
                B2bWorkplacePressureAudienceStatus
                    .futureLandingPositioningDocumented,
          )
          .length,
      blockedAudienceCount: audiences
          .where(
            (audience) =>
                audience.status ==
                B2bWorkplacePressureAudienceStatus.blockedBeforeBetaProof,
          )
          .length,
    );
  }

  static B2bWorkplacePressureFutureGateReport report(
    B2bWorkplacePressureFutureGateResult result,
  ) =>
      B2bWorkplacePressureFutureGateReport(
        headline: B2bWorkplacePressureFutureCopy.headline,
        body: B2bWorkplacePressureFutureCopy.body,
        positioning: B2bWorkplacePressureFutureCopy.positioning,
        orderLine: B2bWorkplacePressureFutureCopy.orderLine,
        prereqOrderLine: B2bWorkplacePressureFutureCopy.prereqOrderLine,
        guardrail: B2bWorkplacePressureFutureCopy.guardrail,
        result: result,
      );

  static B2bWorkplacePressureFutureGateInput composeInput({
    bool? testFlightUploaded,
    bool? paidIntentBetaComplete,
    bool? v1B2bUiRequested,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) =>
      B2bWorkplacePressureFutureGateInput(
        testFlightUploaded:
            testFlightUploaded ?? launchChecklist?.testFlightUploaded,
        paidIntentBetaComplete: paidIntentBetaComplete ??
            launchChecklist?.paidIntentBetaComplete ??
            _paidIntentBetaCompleteFrom(paidIntentBeta),
        v1B2bUiRequested: v1B2bUiRequested,
      );

  static B2bWorkplacePressureFutureGateInput fromRepoSignals({
    required String b2bWorkplacePressureFutureDocSource,
    required String gateCopySource,
    required String audienceWedgeModelSource,
    bool? testFlightUploaded,
    bool? paidIntentBetaComplete,
    bool? v1B2bUiRequested,
  }) =>
      B2bWorkplacePressureFutureGateInput(
        testFlightUploaded: testFlightUploaded,
        paidIntentBetaComplete: paidIntentBetaComplete,
        v1B2bUiRequested: v1B2bUiRequested,
        docListsRules: detectDocListsRules(b2bWorkplacePressureFutureDocSource),
        guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
        audienceWedgeIdsAligned:
            detectAudienceWedgeIdsAligned(audienceWedgeModelSource),
      );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'founders',
      'managers',
      'carers',
      'high-responsibility workers',
      'people who overcommit',
      'people who say yes with no capacity',
      'no employer dashboard',
      'no employee surveillance',
      'no live b2b ui',
      'future landing-page positioning',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('no employer dashboard') &&
        lower.contains('no employee surveillance') &&
        lower.contains('no live b2b ui') &&
        lower.contains('future landing-page positioning only');
  }

  static bool detectAudienceWedgeIdsAligned(String audienceWedgeModelSource) {
    for (final wedgeId in audienceWedgeIdByAudience.values) {
      if (!audienceWedgeModelSource.contains(wedgeId)) {
        return false;
      }
    }
    return true;
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesEmployerDashboard(copy) &&
      !_violatesEmployeeSurveillance(copy) &&
      !_violatesMedicalTherapyClaims(copy) &&
      ProductLanguageConsistencyGuard.passesProPromise(copy);

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static List<B2bWorkplacePressureFutureRule> _buildRules(
    B2bWorkplacePressureFutureGateInput input,
  ) {
    final copyBundle = [
      B2bWorkplacePressureFutureCopy.positioning,
      B2bWorkplacePressureFutureCopy.guardrail,
      B2bWorkplacePressureFutureCopy.body,
    ].join(' ');
    final guardrailLower = B2bWorkplacePressureFutureCopy.guardrail.toLowerCase();
    final betaProofComplete = (input.testFlightUploaded ?? false) &&
        (input.paidIntentBetaComplete ?? false);
    return [
      _rule(
        id: B2bWorkplacePressureFutureRuleId.noEmployerDashboard,
        passes: evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('no employer dashboard'),
      ),
      _rule(
        id: B2bWorkplacePressureFutureRuleId.noEmployeeSurveillance,
        passes: evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('no employee surveillance'),
      ),
      _rule(
        id: B2bWorkplacePressureFutureRuleId.noMedicalTherapyClaims,
        passes: evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('no medical or treatment-style claims'),
      ),
      _rule(
        id: B2bWorkplacePressureFutureRuleId.noLiveB2bUi,
        passes: guardrailLower.contains('no live b2b ui') &&
            (!(input.v1B2bUiRequested ?? false) || betaProofComplete),
      ),
      _rule(
        id: B2bWorkplacePressureFutureRuleId.futureLandingPositioningOnly,
        passes: guardrailLower.contains('future landing-page positioning only'),
      ),
    ];
  }

  static List<B2bWorkplacePressureFuturePrereq> _buildPrereqs(
    B2bWorkplacePressureFutureGateInput input,
  ) =>
      [
        _prereq(
          id: B2bWorkplacePressureFuturePrereqId.testFlightUploaded,
          value: input.testFlightUploaded,
        ),
        _prereq(
          id: B2bWorkplacePressureFuturePrereqId.paidIntentBetaComplete,
          value: input.paidIntentBetaComplete,
        ),
      ];

  static List<B2bWorkplacePressureAudience> _buildAudiences({
    required bool betaProofComplete,
  }) =>
      canonicalAudienceOrder
          .map(
            (id) => B2bWorkplacePressureAudience(
              id: id,
              label: B2bWorkplacePressureFutureCopy.labelFor(id),
              positioning: B2bWorkplacePressureFutureCopy.positioningFor(id),
              status: betaProofComplete
                  ? B2bWorkplacePressureAudienceStatus
                      .futureLandingPositioningDocumented
                  : B2bWorkplacePressureAudienceStatus.blockedBeforeBetaProof,
              detailLabel: betaProofComplete
                  ? B2bWorkplacePressureFutureCopy
                      .detailFutureLandingPositioningDocumented
                  : B2bWorkplacePressureFutureCopy.detailBlockedBeforeBetaProof,
              audienceWedgeId: audienceWedgeIdByAudience[id]!,
            ),
          )
          .toList();

  static bool _violatesEmployerDashboard(String copy) =>
      employerDashboardViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesEmployeeSurveillance(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in employeeSurveillanceViolationMarkers) {
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

  static bool _violatesMedicalTherapyClaims(String copy) =>
      medicalTherapyViolationMarkers.any(copy.toLowerCase().contains);

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

  static B2bWorkplacePressureFuturePrereqStatus _statusFor(bool? value) =>
      switch (value) {
        true => B2bWorkplacePressureFuturePrereqStatus.pass,
        false => B2bWorkplacePressureFuturePrereqStatus.fail,
        null => B2bWorkplacePressureFuturePrereqStatus.pending,
      };

  static B2bWorkplacePressureFuturePrereq _prereq({
    required B2bWorkplacePressureFuturePrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return B2bWorkplacePressureFuturePrereq(
      id: id,
      label: B2bWorkplacePressureFutureCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        B2bWorkplacePressureFuturePrereqStatus.pass =>
          B2bWorkplacePressureFutureCopy.detailPass,
        B2bWorkplacePressureFuturePrereqStatus.pending =>
          B2bWorkplacePressureFutureCopy.detailPending,
        B2bWorkplacePressureFuturePrereqStatus.fail =>
          B2bWorkplacePressureFutureCopy.detailFail,
      },
    );
  }

  static B2bWorkplacePressureFutureRule _rule({
    required B2bWorkplacePressureFutureRuleId id,
    required bool passes,
  }) =>
      B2bWorkplacePressureFutureRule(
        id: id,
        label: B2bWorkplacePressureFutureCopy.ruleLabelFor(id),
        status: passes
            ? B2bWorkplacePressureFutureRuleStatus.pass
            : B2bWorkplacePressureFutureRuleStatus.fail,
        detailLabel: passes
            ? B2bWorkplacePressureFutureCopy.detailPass
            : B2bWorkplacePressureFutureCopy.detailFail,
      );
}

class B2bWorkplacePressureFutureGateInput {
  const B2bWorkplacePressureFutureGateInput({
    this.testFlightUploaded,
    this.paidIntentBetaComplete,
    this.v1B2bUiRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
    this.audienceWedgeIdsAligned = true,
  });

  final bool? testFlightUploaded;
  final bool? paidIntentBetaComplete;
  final bool? v1B2bUiRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
  final bool audienceWedgeIdsAligned;
}

class B2bWorkplacePressureFutureRule {
  const B2bWorkplacePressureFutureRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final B2bWorkplacePressureFutureRuleId id;
  final String label;
  final B2bWorkplacePressureFutureRuleStatus status;
  final String detailLabel;
}

class B2bWorkplacePressureFuturePrereq {
  const B2bWorkplacePressureFuturePrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final B2bWorkplacePressureFuturePrereqId id;
  final String label;
  final B2bWorkplacePressureFuturePrereqStatus status;
  final String detailLabel;
}

class B2bWorkplacePressureAudience {
  const B2bWorkplacePressureAudience({
    required this.id,
    required this.label,
    required this.positioning,
    required this.status,
    required this.detailLabel,
    required this.audienceWedgeId,
  });

  final B2bWorkplacePressureAudienceId id;
  final String label;
  final String positioning;
  final B2bWorkplacePressureAudienceStatus status;
  final String detailLabel;
  final String audienceWedgeId;
}

class B2bWorkplacePressureFutureGateResult {
  const B2bWorkplacePressureFutureGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.prereqs,
    required this.prereqOrder,
    required this.audiences,
    required this.audienceOrder,
    required this.betaProofComplete,
    required this.v1LiveB2bUiBlocked,
    required this.employerDashboardBlocked,
    required this.employeeSurveillanceBlocked,
    required this.medicalTherapyClaimsBlocked,
    required this.earliestPrereqGap,
    required this.earliestRuleFailure,
    required this.documentedAudienceCount,
    required this.blockedAudienceCount,
  });

  final B2bWorkplacePressureFutureGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<B2bWorkplacePressureFutureRule> rules;
  final List<B2bWorkplacePressureFutureRuleId> ruleOrder;
  final bool rulesPass;
  final List<B2bWorkplacePressureFuturePrereq> prereqs;
  final List<B2bWorkplacePressureFuturePrereqId> prereqOrder;
  final List<B2bWorkplacePressureAudience> audiences;
  final List<B2bWorkplacePressureAudienceId> audienceOrder;
  final bool betaProofComplete;
  final bool v1LiveB2bUiBlocked;
  final bool employerDashboardBlocked;
  final bool employeeSurveillanceBlocked;
  final bool medicalTherapyClaimsBlocked;
  final B2bWorkplacePressureFuturePrereqId? earliestPrereqGap;
  final B2bWorkplacePressureFutureRuleId? earliestRuleFailure;
  final int documentedAudienceCount;
  final int blockedAudienceCount;
}

class B2bWorkplacePressureFutureGateReport {
  const B2bWorkplacePressureFutureGateReport({
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
  final B2bWorkplacePressureFutureGateResult result;
}
