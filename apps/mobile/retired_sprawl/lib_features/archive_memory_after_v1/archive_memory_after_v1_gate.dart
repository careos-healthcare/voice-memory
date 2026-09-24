import 'package:archiveme_mobile/features/archive_memory_after_v1/archive_memory_after_v1_copy.dart';
import 'package:archiveme_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:archiveme_mobile/features/product_language_consistency/product_language_consistency_guard.dart';
import 'package:archiveme_mobile/features/single_launch_checklist/single_launch_checklist.dart';

/// Archive memory after V1 gate — future enhancement after V1 proof.
abstract final class ThoughtprintmoryAfterV1Gate {
  ThoughtprintmoryAfterV1Gate._();

  static const ruleCount = 5;

  static const List<ThoughtprintmoryAfterV1RuleId> canonicalRuleOrder = [
    ThoughtprintmoryAfterV1RuleId.futureEnhancementOnly,
    ThoughtprintmoryAfterV1RuleId.notPartOfFirstFiveMinutes,
    ThoughtprintmoryAfterV1RuleId.notPrimaryProPromise,
    ThoughtprintmoryAfterV1RuleId.supportsProofTrailNotStorage,
    ThoughtprintmoryAfterV1RuleId.noNewLiveV1Ui,
  ];

  static const primaryProPromiseViolationMarkers = [
    'unlock archive memory',
    'archive memory is what pro',
    'main benefit: archive memory',
    'primary pro promise: archive memory',
    'pro gives you archive memory',
    'longer archive memory is what pro',
  ];

  static const storageFramingViolationMarkers = [
    'unlimited storage',
    'store everything forever',
    'cloud storage for your archive',
    'backup all your recordings',
    'archive memory storage',
  ];

  static ThoughtprintmoryAfterV1GateResult build(
    ThoughtprintmoryAfterV1GateInput input,
  ) {
    final rules = _buildRules(input);
    final rulesPass = rules.every(
      (rule) => rule.status == ThoughtprintmoryAfterV1RuleStatus.pass,
    );
    final betaProofComplete = input.paidIntentBetaComplete ?? false;
    final decision = rulesPass && betaProofComplete
        ? ThoughtprintmoryAfterV1GateDecision.futureThoughtprintmoryDocumented
        : ThoughtprintmoryAfterV1GateDecision.archiveMemoryFrozen;
    return ThoughtprintmoryAfterV1GateResult(
      decision: decision,
      message: ThoughtprintmoryAfterV1Copy.messageFor(decision),
      recommendation: ThoughtprintmoryAfterV1Copy.recommendationFor(decision),
      positioning: ThoughtprintmoryAfterV1Copy.positioning,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      betaProofComplete: betaProofComplete,
      v1LiveUiBlocked: true,
      primaryProPromiseBlocked: true,
      storageFramingBlocked: true,
      firstFiveMinutesSurfacingBlocked: true,
      earliestRuleFailure: rules
          .where((rule) => rule.status == ThoughtprintmoryAfterV1RuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static ThoughtprintmoryAfterV1GateReport report(
    ThoughtprintmoryAfterV1GateResult result,
  ) => ThoughtprintmoryAfterV1GateReport(
    headline: ThoughtprintmoryAfterV1Copy.headline,
    body: ThoughtprintmoryAfterV1Copy.body,
    positioning: ThoughtprintmoryAfterV1Copy.positioning,
    orderLine: ThoughtprintmoryAfterV1Copy.orderLine,
    guardrail: ThoughtprintmoryAfterV1Copy.guardrail,
    result: result,
  );

  static ThoughtprintmoryAfterV1GateInput composeInput({
    bool? paidIntentBetaComplete,
    bool? withinFirstFiveMinutes,
    bool? memorySurfacingRequested,
    bool? v1ThoughtprintmoryUiRequested,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) => ThoughtprintmoryAfterV1GateInput(
    paidIntentBetaComplete:
        paidIntentBetaComplete ??
        launchChecklist?.paidIntentBetaComplete ??
        _paidIntentBetaCompleteFrom(paidIntentBeta),
    withinFirstFiveMinutes: withinFirstFiveMinutes,
    memorySurfacingRequested: memorySurfacingRequested,
    v1ThoughtprintmoryUiRequested: v1ThoughtprintmoryUiRequested,
  );

  static ThoughtprintmoryAfterV1GateInput fromRepoSignals({
    required String archiveMemoryAfterV1DocSource,
    required String gateCopySource,
    bool? paidIntentBetaComplete,
    bool? withinFirstFiveMinutes,
    bool? memorySurfacingRequested,
    bool? v1ThoughtprintmoryUiRequested,
  }) => ThoughtprintmoryAfterV1GateInput(
    paidIntentBetaComplete: paidIntentBetaComplete,
    withinFirstFiveMinutes: withinFirstFiveMinutes,
    memorySurfacingRequested: memorySurfacingRequested,
    v1ThoughtprintmoryUiRequested: v1ThoughtprintmoryUiRequested,
    docListsRules: detectDocListsRules(archiveMemoryAfterV1DocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
  );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'future enhancement',
      'not part of first five minutes',
      'not primary pro promise',
      'proof trail',
      'not storage',
      'no new live v1 ui',
      'archive memory after v1',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('archive memory after v1') &&
        lower.contains('future enhancement') &&
        lower.contains('not part of first five minutes') &&
        lower.contains('not the primary pro promise') &&
        lower.contains('proof trail') &&
        lower.contains('not storage') &&
        lower.contains('no new live v1 ui');
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesPrimaryProPromise(copy) &&
      !_violatesStorageFraming(copy) &&
      ProductLanguageConsistencyGuard.passesProPromise(copy);

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static List<ThoughtprintmoryAfterV1Rule> _buildRules(
    ThoughtprintmoryAfterV1GateInput input,
  ) {
    final copyBundle = [
      ThoughtprintmoryAfterV1Copy.positioning,
      ThoughtprintmoryAfterV1Copy.guardrail,
      ThoughtprintmoryAfterV1Copy.body,
    ].join(' ');
    final guardrailLower = ThoughtprintmoryAfterV1Copy.guardrail.toLowerCase();
    final memorySurfacingRequested = input.memorySurfacingRequested ?? false;
    final withinFirstFiveMinutes = input.withinFirstFiveMinutes ?? false;
    final betaProofComplete = input.paidIntentBetaComplete ?? false;
    return [
      _rule(
        id: ThoughtprintmoryAfterV1RuleId.futureEnhancementOnly,
        passes:
            guardrailLower.contains('future enhancement') &&
            guardrailLower.contains('archive memory after v1'),
      ),
      _rule(
        id: ThoughtprintmoryAfterV1RuleId.notPartOfFirstFiveMinutes,
        passes:
            guardrailLower.contains('not part of first five minutes') &&
            (!withinFirstFiveMinutes || !memorySurfacingRequested),
      ),
      _rule(
        id: ThoughtprintmoryAfterV1RuleId.notPrimaryProPromise,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('not the primary pro promise'),
      ),
      _rule(
        id: ThoughtprintmoryAfterV1RuleId.supportsProofTrailNotStorage,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('proof trail') &&
            guardrailLower.contains('not storage'),
      ),
      _rule(
        id: ThoughtprintmoryAfterV1RuleId.noNewLiveV1Ui,
        passes:
            guardrailLower.contains('no new live v1 ui') &&
            (!(input.v1ThoughtprintmoryUiRequested ?? false) || betaProofComplete),
      ),
    ];
  }

  static bool _violatesPrimaryProPromise(String copy) =>
      primaryProPromiseViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesStorageFraming(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in storageFramingViolationMarkers) {
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

  static ThoughtprintmoryAfterV1Rule _rule({
    required ThoughtprintmoryAfterV1RuleId id,
    required bool passes,
  }) => ThoughtprintmoryAfterV1Rule(
    id: id,
    label: ThoughtprintmoryAfterV1Copy.ruleLabelFor(id),
    status: passes
        ? ThoughtprintmoryAfterV1RuleStatus.pass
        : ThoughtprintmoryAfterV1RuleStatus.fail,
    detailLabel: passes
        ? ThoughtprintmoryAfterV1Copy.detailPass
        : ThoughtprintmoryAfterV1Copy.detailFail,
  );
}

class ThoughtprintmoryAfterV1GateInput {
  const ThoughtprintmoryAfterV1GateInput({
    this.paidIntentBetaComplete,
    this.withinFirstFiveMinutes,
    this.memorySurfacingRequested,
    this.v1ThoughtprintmoryUiRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
  });

  final bool? paidIntentBetaComplete;
  final bool? withinFirstFiveMinutes;
  final bool? memorySurfacingRequested;
  final bool? v1ThoughtprintmoryUiRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
}

class ThoughtprintmoryAfterV1Rule {
  const ThoughtprintmoryAfterV1Rule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final ThoughtprintmoryAfterV1RuleId id;
  final String label;
  final ThoughtprintmoryAfterV1RuleStatus status;
  final String detailLabel;
}

class ThoughtprintmoryAfterV1GateResult {
  const ThoughtprintmoryAfterV1GateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.betaProofComplete,
    required this.v1LiveUiBlocked,
    required this.primaryProPromiseBlocked,
    required this.storageFramingBlocked,
    required this.firstFiveMinutesSurfacingBlocked,
    required this.earliestRuleFailure,
  });

  final ThoughtprintmoryAfterV1GateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<ThoughtprintmoryAfterV1Rule> rules;
  final List<ThoughtprintmoryAfterV1RuleId> ruleOrder;
  final bool rulesPass;
  final bool betaProofComplete;
  final bool v1LiveUiBlocked;
  final bool primaryProPromiseBlocked;
  final bool storageFramingBlocked;
  final bool firstFiveMinutesSurfacingBlocked;
  final ThoughtprintmoryAfterV1RuleId? earliestRuleFailure;
}

class ThoughtprintmoryAfterV1GateReport {
  const ThoughtprintmoryAfterV1GateReport({
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
  final ThoughtprintmoryAfterV1GateResult result;
}