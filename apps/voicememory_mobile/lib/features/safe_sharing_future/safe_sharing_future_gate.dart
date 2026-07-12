import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../single_launch_checklist/single_launch_checklist.dart';
import 'safe_sharing_future_copy.dart';

/// Safe sharing future gate — future growth sharing without private text leak.
abstract final class SafeSharingFutureGate {
  SafeSharingFutureGate._();

  static const ruleCount = 6;
  static const prereqCount = 2;

  static const canonicalRuleOrder = [
    SafeSharingFutureRuleId.noRawPrivateTextByDefault,
    SafeSharingFutureRuleId.explicitUserShareOrExport,
    SafeSharingFutureRuleId.shareProductInsightNotArchive,
    SafeSharingFutureRuleId.noSharingInFirstFiveMinutes,
    SafeSharingFutureRuleId.noSharingBeforeFirstUsefulProof,
    SafeSharingFutureRuleId.noLiveV1SharingExpansion,
  ];

  static const canonicalPrereqOrder = [
    SafeSharingFuturePrereqId.firstUsefulProofSeen,
    SafeSharingFuturePrereqId.paidIntentBetaComplete,
  ];

  static const rawPrivateTextLeakViolationMarkers = [
    'share raw text by default',
    'automatically share your entries',
    'background share sends',
    'share raw private text',
    'sends your raw text',
    'will leak private raw text',
  ];

  static const archiveContentShareViolationMarkers = [
    'share your archive with',
    'share private content with',
    'share your entries with',
    'share my journal',
    'here is my archive',
    'copy of my archive',
  ];

  static SafeSharingFutureGateResult build(SafeSharingFutureGateInput input) {
    final rules = _buildRules(input);
    final prereqs = _buildPrereqs(input);
    final rulesPass = rules.every(
      (rule) => rule.status == SafeSharingFutureRuleStatus.pass,
    );
    final sharingProofComplete = prereqs.every(
      (prereq) => prereq.status == SafeSharingFuturePrereqStatus.pass,
    );
    final decision = rulesPass && sharingProofComplete
        ? SafeSharingFutureGateDecision.futureGrowthSharingDocumented
        : SafeSharingFutureGateDecision.sharingFrozen;
    return SafeSharingFutureGateResult(
      decision: decision,
      message: SafeSharingFutureCopy.messageFor(decision),
      recommendation: SafeSharingFutureCopy.recommendationFor(decision),
      positioning: SafeSharingFutureCopy.positioning,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      sharingProofComplete: sharingProofComplete,
      rawPrivateTextBlocked: true,
      explicitShareRequired: true,
      archiveContentSharingBlocked: true,
      firstFiveMinutesSharingBlocked: true,
      v1SharingExpansionBlocked: true,
      earliestPrereqGap: prereqs
          .where(
            (prereq) => prereq.status != SafeSharingFuturePrereqStatus.pass,
          )
          .map((prereq) => prereq.id)
          .firstOrNull,
      earliestRuleFailure: rules
          .where((rule) => rule.status == SafeSharingFutureRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static SafeSharingFutureGateReport report(SafeSharingFutureGateResult result) =>
      SafeSharingFutureGateReport(
        headline: SafeSharingFutureCopy.headline,
        body: SafeSharingFutureCopy.body,
        positioning: SafeSharingFutureCopy.positioning,
        orderLine: SafeSharingFutureCopy.orderLine,
        prereqOrderLine: SafeSharingFutureCopy.prereqOrderLine,
        guardrail: SafeSharingFutureCopy.guardrail,
        result: result,
      );

  static SafeSharingFutureGateInput composeInput({
    bool? firstUsefulProofSeen,
    bool? paidIntentBetaComplete,
    bool? withinFirstFiveMinutes,
    bool? sharingPromptRequested,
    bool? v1SharingExpansionRequested,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) =>
      SafeSharingFutureGateInput(
        firstUsefulProofSeen: firstUsefulProofSeen ??
            _firstUsefulProofSeenFrom(paidIntentBeta),
        paidIntentBetaComplete: paidIntentBetaComplete ??
            launchChecklist?.paidIntentBetaComplete ??
            _paidIntentBetaCompleteFrom(paidIntentBeta),
        withinFirstFiveMinutes: withinFirstFiveMinutes,
        sharingPromptRequested: sharingPromptRequested,
        v1SharingExpansionRequested: v1SharingExpansionRequested,
      );

  static SafeSharingFutureGateInput fromRepoSignals({
    required String safeSharingFutureDocSource,
    required String gateCopySource,
    bool? firstUsefulProofSeen,
    bool? paidIntentBetaComplete,
    bool? withinFirstFiveMinutes,
    bool? sharingPromptRequested,
    bool? v1SharingExpansionRequested,
  }) =>
      SafeSharingFutureGateInput(
        firstUsefulProofSeen: firstUsefulProofSeen,
        paidIntentBetaComplete: paidIntentBetaComplete,
        withinFirstFiveMinutes: withinFirstFiveMinutes,
        sharingPromptRequested: sharingPromptRequested,
        v1SharingExpansionRequested: v1SharingExpansionRequested,
        docListsRules: detectDocListsRules(safeSharingFutureDocSource),
        guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
      );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'never share raw private text by default',
      'explicit user share',
      'product insight',
      'not archive content',
      'first five minutes',
      'first useful proof',
      'no new live v1 sharing',
      'future growth sharing',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('future growth sharing') &&
        lower.contains('never share raw private text by default') &&
        lower.contains('explicit user share or export') &&
        lower.contains('product insight') &&
        lower.contains('not archive content') &&
        lower.contains('first five minutes') &&
        lower.contains('first useful proof') &&
        lower.contains('no new live v1 sharing');
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesRawPrivateTextLeak(copy) &&
      !_violatesArchiveContentShare(copy);

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static bool? _firstUsefulProofSeenFrom(PaidIntentBetaProofResult? result) =>
      _signalPassed(result, PaidIntentBetaProofSignalId.firstUsefulProofSeen);

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

  static List<SafeSharingFutureRule> _buildRules(
    SafeSharingFutureGateInput input,
  ) {
    final copyBundle = [
      SafeSharingFutureCopy.positioning,
      SafeSharingFutureCopy.guardrail,
      SafeSharingFutureCopy.body,
    ].join(' ');
    final guardrailLower = SafeSharingFutureCopy.guardrail.toLowerCase();
    final sharingPromptRequested = input.sharingPromptRequested ?? false;
    final withinFirstFiveMinutes = input.withinFirstFiveMinutes ?? false;
    final firstUsefulProofSeen = input.firstUsefulProofSeen ?? false;
    final sharingProofComplete =
        firstUsefulProofSeen && (input.paidIntentBetaComplete ?? false);
    return [
      _rule(
        id: SafeSharingFutureRuleId.noRawPrivateTextByDefault,
        passes: evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('never share raw private text by default'),
      ),
      _rule(
        id: SafeSharingFutureRuleId.explicitUserShareOrExport,
        passes: guardrailLower.contains('explicit user share or export'),
      ),
      _rule(
        id: SafeSharingFutureRuleId.shareProductInsightNotArchive,
        passes: evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('product insight') &&
            guardrailLower.contains('not archive content'),
      ),
      _rule(
        id: SafeSharingFutureRuleId.noSharingInFirstFiveMinutes,
        passes: guardrailLower.contains('first five minutes') &&
            (!withinFirstFiveMinutes || !sharingPromptRequested),
      ),
      _rule(
        id: SafeSharingFutureRuleId.noSharingBeforeFirstUsefulProof,
        passes: guardrailLower.contains('first useful proof') &&
            (!sharingPromptRequested || firstUsefulProofSeen),
      ),
      _rule(
        id: SafeSharingFutureRuleId.noLiveV1SharingExpansion,
        passes: guardrailLower.contains('no new live v1 sharing') &&
            (!(input.v1SharingExpansionRequested ?? false) ||
                sharingProofComplete),
      ),
    ];
  }

  static List<SafeSharingFuturePrereq> _buildPrereqs(
    SafeSharingFutureGateInput input,
  ) =>
      [
        _prereq(
          id: SafeSharingFuturePrereqId.firstUsefulProofSeen,
          value: input.firstUsefulProofSeen,
        ),
        _prereq(
          id: SafeSharingFuturePrereqId.paidIntentBetaComplete,
          value: input.paidIntentBetaComplete,
        ),
      ];

  static bool _violatesRawPrivateTextLeak(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in rawPrivateTextLeakViolationMarkers) {
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

  static bool _violatesArchiveContentShare(String copy) =>
      archiveContentShareViolationMarkers.any(copy.toLowerCase().contains);

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

  static SafeSharingFuturePrereqStatus _statusFor(bool? value) => switch (value) {
        true => SafeSharingFuturePrereqStatus.pass,
        false => SafeSharingFuturePrereqStatus.fail,
        null => SafeSharingFuturePrereqStatus.pending,
      };

  static SafeSharingFuturePrereq _prereq({
    required SafeSharingFuturePrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return SafeSharingFuturePrereq(
      id: id,
      label: SafeSharingFutureCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        SafeSharingFuturePrereqStatus.pass => SafeSharingFutureCopy.detailPass,
        SafeSharingFuturePrereqStatus.pending =>
          SafeSharingFutureCopy.detailPending,
        SafeSharingFuturePrereqStatus.fail => SafeSharingFutureCopy.detailFail,
      },
    );
  }

  static SafeSharingFutureRule _rule({
    required SafeSharingFutureRuleId id,
    required bool passes,
  }) =>
      SafeSharingFutureRule(
        id: id,
        label: SafeSharingFutureCopy.ruleLabelFor(id),
        status: passes
            ? SafeSharingFutureRuleStatus.pass
            : SafeSharingFutureRuleStatus.fail,
        detailLabel: passes
            ? SafeSharingFutureCopy.detailPass
            : SafeSharingFutureCopy.detailFail,
      );
}

class SafeSharingFutureGateInput {
  const SafeSharingFutureGateInput({
    this.firstUsefulProofSeen,
    this.paidIntentBetaComplete,
    this.withinFirstFiveMinutes,
    this.sharingPromptRequested,
    this.v1SharingExpansionRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
  });

  final bool? firstUsefulProofSeen;
  final bool? paidIntentBetaComplete;
  final bool? withinFirstFiveMinutes;
  final bool? sharingPromptRequested;
  final bool? v1SharingExpansionRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
}

class SafeSharingFutureRule {
  const SafeSharingFutureRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final SafeSharingFutureRuleId id;
  final String label;
  final SafeSharingFutureRuleStatus status;
  final String detailLabel;
}

class SafeSharingFuturePrereq {
  const SafeSharingFuturePrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final SafeSharingFuturePrereqId id;
  final String label;
  final SafeSharingFuturePrereqStatus status;
  final String detailLabel;
}

class SafeSharingFutureGateResult {
  const SafeSharingFutureGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.prereqs,
    required this.prereqOrder,
    required this.sharingProofComplete,
    required this.rawPrivateTextBlocked,
    required this.explicitShareRequired,
    required this.archiveContentSharingBlocked,
    required this.firstFiveMinutesSharingBlocked,
    required this.v1SharingExpansionBlocked,
    required this.earliestPrereqGap,
    required this.earliestRuleFailure,
  });

  final SafeSharingFutureGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<SafeSharingFutureRule> rules;
  final List<SafeSharingFutureRuleId> ruleOrder;
  final bool rulesPass;
  final List<SafeSharingFuturePrereq> prereqs;
  final List<SafeSharingFuturePrereqId> prereqOrder;
  final bool sharingProofComplete;
  final bool rawPrivateTextBlocked;
  final bool explicitShareRequired;
  final bool archiveContentSharingBlocked;
  final bool firstFiveMinutesSharingBlocked;
  final bool v1SharingExpansionBlocked;
  final SafeSharingFuturePrereqId? earliestPrereqGap;
  final SafeSharingFutureRuleId? earliestRuleFailure;
}

class SafeSharingFutureGateReport {
  const SafeSharingFutureGateReport({
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
  final SafeSharingFutureGateResult result;
}
