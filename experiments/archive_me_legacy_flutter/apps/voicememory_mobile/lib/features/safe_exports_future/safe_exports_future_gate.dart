import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../product_language_consistency/product_language_consistency_guard.dart';
import '../single_launch_checklist/single_launch_checklist.dart';
import 'safe_exports_future_copy.dart';

/// Safe exports future gate — future paid expansion, not launch promise.
abstract final class SafeExportsFutureGate {
  SafeExportsFutureGate._();

  static const exportCount = 5;
  static const prereqCount = 2;
  static const ruleCount = 4;

  static const canonicalExportOrder = [
    SafeExportFutureId.proofTrailPdf,
    SafeExportFutureId.markdownArchive,
    SafeExportFutureId.localBackup,
    SafeExportFutureId.whatChangedMonthlyReport,
    SafeExportFutureId.evidenceTrailExport,
  ];

  static const canonicalPrereqOrder = [
    SafeExportFuturePrereqId.exportTestsPass,
    SafeExportFuturePrereqId.paidIntentBetaComplete,
  ];

  static const canonicalRuleOrder = [
    SafeExportsFutureRuleId.notPrimaryProPromise,
    SafeExportsFutureRuleId.noPrivateRawTextLeak,
    SafeExportsFutureRuleId.testedBeforeMarketing,
    SafeExportsFutureRuleId.noNewExportUiForV1,
  ];

  static const primaryProPromiseViolationMarkers = [
    'unlock exports',
    'exports are what pro',
    'main benefit: exports',
    'primary pro promise: exports',
    'pro gives you exports',
  ];

  static const privateRawTextLeakViolationMarkers = [
    'automatically export your entries',
    'background export sends',
    'share raw text without',
    'sends your raw text',
    'will leak private raw text',
  ];

  static SafeExportsFutureGateResult build(SafeExportsFutureGateInput input) {
    final rules = _buildRules(input);
    final prereqs = _buildPrereqs(input);
    final rulesPass = rules.every(
      (rule) => rule.status == SafeExportsFutureRuleStatus.pass,
    );
    final exportProofComplete =
        rulesPass &&
        prereqs.every(
          (prereq) => prereq.status == SafeExportFuturePrereqStatus.pass,
        );
    final decision = exportProofComplete
        ? SafeExportsFutureGateDecision.futurePaidExpansionDocumented
        : SafeExportsFutureGateDecision.exportsFrozen;
    final exports = _buildExports(exportProofComplete: exportProofComplete);
    return SafeExportsFutureGateResult(
      decision: decision,
      message: SafeExportsFutureCopy.messageFor(decision),
      recommendation: SafeExportsFutureCopy.recommendationFor(decision),
      positioning: SafeExportsFutureCopy.positioning,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      exports: exports,
      exportOrder: canonicalExportOrder,
      exportProofComplete: exportProofComplete,
      launchPromiseBlocked: true,
      primaryProPromiseBlocked: true,
      v1ExportUiBlocked: true,
      earliestPrereqGap: prereqs
          .where((prereq) => prereq.status != SafeExportFuturePrereqStatus.pass)
          .map((prereq) => prereq.id)
          .firstOrNull,
      earliestRuleFailure: rules
          .where((rule) => rule.status == SafeExportsFutureRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
      documentedExportCount: exports
          .where(
            (export) =>
                export.status ==
                SafeExportFutureStatus.futurePaidExpansionDocumented,
          )
          .length,
      blockedExportCount: exports
          .where(
            (export) =>
                export.status ==
                SafeExportFutureStatus.blockedBeforeExportProof,
          )
          .length,
    );
  }

  static SafeExportsFutureGateReport report(
    SafeExportsFutureGateResult result,
  ) => SafeExportsFutureGateReport(
    headline: SafeExportsFutureCopy.headline,
    body: SafeExportsFutureCopy.body,
    positioning: SafeExportsFutureCopy.positioning,
    orderLine: SafeExportsFutureCopy.orderLine,
    prereqOrderLine: SafeExportsFutureCopy.prereqOrderLine,
    guardrail: SafeExportsFutureCopy.guardrail,
    result: result,
  );

  static SafeExportsFutureGateInput composeInput({
    bool? exportTestsPass,
    bool? paidIntentBetaComplete,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) => SafeExportsFutureGateInput(
    exportTestsPass: exportTestsPass,
    paidIntentBetaComplete:
        paidIntentBetaComplete ??
        launchChecklist?.paidIntentBetaComplete ??
        _paidIntentBetaCompleteFrom(paidIntentBeta),
  );

  static SafeExportsFutureGateInput fromRepoSignals({
    required String safeExportsFutureDocSource,
    required String gateCopySource,
    bool? exportTestsPass,
    bool? paidIntentBetaComplete,
  }) => SafeExportsFutureGateInput(
    exportTestsPass: exportTestsPass,
    paidIntentBetaComplete: paidIntentBetaComplete,
    docListsRules: detectDocListsRules(safeExportsFutureDocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
  );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'not primary pro promise',
      'explicit user export action',
      'tested before marketing',
      'no new export ui',
      'future paid expansion',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('not the primary pro promise') &&
        lower.contains('explicit user export action') &&
        lower.contains('tested before marketing') &&
        lower.contains('no new export ui');
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesPrimaryProPromise(copy) &&
      !_violatesPrivateRawTextLeak(copy) &&
      ProductLanguageConsistencyGuard.passesProPromise(copy);

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static List<SafeExportsFutureRule> _buildRules(
    SafeExportsFutureGateInput input,
  ) {
    final copyBundle = [
      SafeExportsFutureCopy.positioning,
      SafeExportsFutureCopy.guardrail,
      SafeExportsFutureCopy.body,
    ].join(' ');
    final guardrailLower = SafeExportsFutureCopy.guardrail.toLowerCase();
    return [
      _rule(
        id: SafeExportsFutureRuleId.notPrimaryProPromise,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('not the primary pro promise'),
      ),
      _rule(
        id: SafeExportsFutureRuleId.noPrivateRawTextLeak,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('explicit user export action') &&
            guardrailLower.contains('never leak private raw text'),
      ),
      _rule(
        id: SafeExportsFutureRuleId.testedBeforeMarketing,
        passes:
            guardrailLower.contains('tested before marketing') &&
            (!(input.marketingExportsPlanned ?? false) ||
                (input.exportTestsPass ?? false)),
      ),
      _rule(
        id: SafeExportsFutureRuleId.noNewExportUiForV1,
        passes: guardrailLower.contains('no new export ui'),
      ),
    ];
  }

  static List<SafeExportFuturePrereq> _buildPrereqs(
    SafeExportsFutureGateInput input,
  ) => [
    _prereq(
      id: SafeExportFuturePrereqId.exportTestsPass,
      value: input.exportTestsPass,
    ),
    _prereq(
      id: SafeExportFuturePrereqId.paidIntentBetaComplete,
      value: input.paidIntentBetaComplete,
    ),
  ];

  static List<SafeExportFuture> _buildExports({
    required bool exportProofComplete,
  }) => canonicalExportOrder
      .map(
        (id) => SafeExportFuture(
          id: id,
          label: SafeExportsFutureCopy.labelFor(id),
          positioning: SafeExportsFutureCopy.positioningFor(id),
          status: exportProofComplete
              ? SafeExportFutureStatus.futurePaidExpansionDocumented
              : SafeExportFutureStatus.blockedBeforeExportProof,
          detailLabel: exportProofComplete
              ? SafeExportsFutureCopy.detailFuturePaidExpansionDocumented
              : SafeExportsFutureCopy.detailBlockedBeforeExportProof,
        ),
      )
      .toList();

  static bool _violatesPrimaryProPromise(String copy) =>
      primaryProPromiseViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesPrivateRawTextLeak(String copy) =>
      privateRawTextLeakViolationMarkers.any(copy.toLowerCase().contains);

  static SafeExportFuturePrereqStatus _statusFor(bool? value) =>
      switch (value) {
        true => SafeExportFuturePrereqStatus.pass,
        false => SafeExportFuturePrereqStatus.fail,
        null => SafeExportFuturePrereqStatus.pending,
      };

  static SafeExportFuturePrereq _prereq({
    required SafeExportFuturePrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return SafeExportFuturePrereq(
      id: id,
      label: SafeExportsFutureCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        SafeExportFuturePrereqStatus.pass => SafeExportsFutureCopy.detailPass,
        SafeExportFuturePrereqStatus.pending =>
          SafeExportsFutureCopy.detailPending,
        SafeExportFuturePrereqStatus.fail => SafeExportsFutureCopy.detailFail,
      },
    );
  }

  static SafeExportsFutureRule _rule({
    required SafeExportsFutureRuleId id,
    required bool passes,
  }) => SafeExportsFutureRule(
    id: id,
    label: SafeExportsFutureCopy.ruleLabelFor(id),
    status: passes
        ? SafeExportsFutureRuleStatus.pass
        : SafeExportsFutureRuleStatus.fail,
    detailLabel: passes
        ? SafeExportsFutureCopy.detailPass
        : SafeExportsFutureCopy.detailFail,
  );
}

class SafeExportsFutureGateInput {
  const SafeExportsFutureGateInput({
    this.exportTestsPass,
    this.paidIntentBetaComplete,
    this.marketingExportsPlanned,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
  });

  final bool? exportTestsPass;
  final bool? paidIntentBetaComplete;
  final bool? marketingExportsPlanned;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
}

class SafeExportsFutureRule {
  const SafeExportsFutureRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final SafeExportsFutureRuleId id;
  final String label;
  final SafeExportsFutureRuleStatus status;
  final String detailLabel;
}

class SafeExportFuturePrereq {
  const SafeExportFuturePrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final SafeExportFuturePrereqId id;
  final String label;
  final SafeExportFuturePrereqStatus status;
  final String detailLabel;
}

class SafeExportFuture {
  const SafeExportFuture({
    required this.id,
    required this.label,
    required this.positioning,
    required this.status,
    required this.detailLabel,
  });

  final SafeExportFutureId id;
  final String label;
  final String positioning;
  final SafeExportFutureStatus status;
  final String detailLabel;
}

class SafeExportsFutureGateResult {
  const SafeExportsFutureGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.prereqs,
    required this.prereqOrder,
    required this.exports,
    required this.exportOrder,
    required this.exportProofComplete,
    required this.launchPromiseBlocked,
    required this.primaryProPromiseBlocked,
    required this.v1ExportUiBlocked,
    required this.earliestPrereqGap,
    required this.earliestRuleFailure,
    required this.documentedExportCount,
    required this.blockedExportCount,
  });

  final SafeExportsFutureGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<SafeExportsFutureRule> rules;
  final List<SafeExportsFutureRuleId> ruleOrder;
  final bool rulesPass;
  final List<SafeExportFuturePrereq> prereqs;
  final List<SafeExportFuturePrereqId> prereqOrder;
  final List<SafeExportFuture> exports;
  final List<SafeExportFutureId> exportOrder;
  final bool exportProofComplete;
  final bool launchPromiseBlocked;
  final bool primaryProPromiseBlocked;
  final bool v1ExportUiBlocked;
  final SafeExportFuturePrereqId? earliestPrereqGap;
  final SafeExportsFutureRuleId? earliestRuleFailure;
  final int documentedExportCount;
  final int blockedExportCount;
}

class SafeExportsFutureGateReport {
  const SafeExportsFutureGateReport({
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
  final SafeExportsFutureGateResult result;
}
