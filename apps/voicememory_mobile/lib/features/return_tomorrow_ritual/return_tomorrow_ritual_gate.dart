import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../single_launch_checklist/single_launch_checklist.dart';
import 'return_tomorrow_ritual_copy.dart';

/// Return tomorrow ritual gate — future retention without daily homework.
abstract final class ReturnTomorrowRitualGate {
  ReturnTomorrowRitualGate._();

  static const ruleCount = 4;

  static const canonicalAllowedLanguage = [
    'watch this tomorrow',
    'did this come back?',
    'save another moment only if it really returned',
  ];

  static const canonicalRuleOrder = [
    ReturnTomorrowRitualRuleId.allowedLanguageDocumented,
    ReturnTomorrowRitualRuleId.noBlockedRetentionPressure,
    ReturnTomorrowRitualRuleId.futureRetentionOnly,
    ReturnTomorrowRitualRuleId.noNewLiveV1Ui,
  ];

  static const streakViolationMarkers = [
    "don't break the chain",
    'keep your streak',
    'streak alive',
    'maintain your streak',
  ];

  static const dailyHomeworkViolationMarkers = [
    'daily homework',
    'homework every day',
    'complete your homework',
  ];

  static const requiredCheckInViolationMarkers = [
    'must check in',
    'daily check-in',
    'required check-in',
  ];

  static const pressureToRecordViolationMarkers = [
    'you must record',
    'record every day',
    'pressure to record',
  ];

  static const habitTrackerViolationMarkers = [
    'habit tracker',
    'track your habit',
    'build your streak habit',
  ];

  static ReturnTomorrowRitualGateResult build(
    ReturnTomorrowRitualGateInput input,
  ) {
    final rules = _buildRules(input);
    final rulesPass = rules.every(
      (rule) => rule.status == ReturnTomorrowRitualRuleStatus.pass,
    );
    final betaProofComplete = input.paidIntentBetaComplete ?? false;
    final decision = rulesPass && betaProofComplete
        ? ReturnTomorrowRitualGateDecision.futureRetentionDocumented
        : ReturnTomorrowRitualGateDecision.ritualFrozen;
    return ReturnTomorrowRitualGateResult(
      decision: decision,
      message: ReturnTomorrowRitualCopy.messageFor(decision),
      recommendation: ReturnTomorrowRitualCopy.recommendationFor(decision),
      positioning: ReturnTomorrowRitualCopy.positioning,
      allowedLanguage: canonicalAllowedLanguage,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      betaProofComplete: betaProofComplete,
      v1LiveUiBlocked: true,
      dailyHomeworkBlocked: true,
      retentionPressureBlocked: true,
      earliestRuleFailure: rules
          .where((rule) => rule.status == ReturnTomorrowRitualRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static ReturnTomorrowRitualGateReport report(
    ReturnTomorrowRitualGateResult result,
  ) =>
      ReturnTomorrowRitualGateReport(
        headline: ReturnTomorrowRitualCopy.headline,
        body: ReturnTomorrowRitualCopy.body,
        positioning: ReturnTomorrowRitualCopy.positioning,
        allowedLanguageLine: ReturnTomorrowRitualCopy.allowedLanguageLine,
        orderLine: ReturnTomorrowRitualCopy.orderLine,
        guardrail: ReturnTomorrowRitualCopy.guardrail,
        result: result,
      );

  static ReturnTomorrowRitualGateInput composeInput({
    bool? paidIntentBetaComplete,
    bool? v1RitualUiRequested,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) =>
      ReturnTomorrowRitualGateInput(
        paidIntentBetaComplete: paidIntentBetaComplete ??
            launchChecklist?.paidIntentBetaComplete ??
            _paidIntentBetaCompleteFrom(paidIntentBeta),
        v1RitualUiRequested: v1RitualUiRequested,
      );

  static ReturnTomorrowRitualGateInput fromRepoSignals({
    required String returnTomorrowRitualDocSource,
    required String gateCopySource,
    bool? paidIntentBetaComplete,
    bool? v1RitualUiRequested,
  }) =>
      ReturnTomorrowRitualGateInput(
        paidIntentBetaComplete: paidIntentBetaComplete,
        v1RitualUiRequested: v1RitualUiRequested,
        docListsRules: detectDocListsRules(returnTomorrowRitualDocSource),
        guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
        allowedLanguagePresentInCopy:
            detectAllowedLanguagePresentInCopy(gateCopySource),
      );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'watch this tomorrow',
      'did this come back?',
      'save another moment only if it really returned',
      'future retention only',
      'no new live v1 ui',
      'daily homework',
      'streaks',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('future retention only') &&
        lower.contains('do not add streaks') &&
        lower.contains('daily homework') &&
        lower.contains('no new live v1 ui');
  }

  static bool detectAllowedLanguagePresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return canonicalAllowedLanguage.every(lower.contains);
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesNoStreaks(copy) &&
      !_violatesDailyHomework(copy) &&
      !_violatesRequiredCheckIn(copy) &&
      !_violatesPressureToRecord(copy) &&
      !_violatesHabitTrackerLanguage(copy);

  static bool? _paidIntentBetaCompleteFrom(PaidIntentBetaProofResult? result) {
    if (result == null) return null;
    return result.paidIntentSignalPromising;
  }

  static List<ReturnTomorrowRitualRule> _buildRules(
    ReturnTomorrowRitualGateInput input,
  ) {
    final copyBundle = [
      ReturnTomorrowRitualCopy.positioning,
      ReturnTomorrowRitualCopy.allowedLanguageLine,
      ReturnTomorrowRitualCopy.guardrail,
      ReturnTomorrowRitualCopy.body,
    ].join(' ');
    final guardrailLower = ReturnTomorrowRitualCopy.guardrail.toLowerCase();
    final betaProofComplete = input.paidIntentBetaComplete ?? false;
    return [
      _rule(
        id: ReturnTomorrowRitualRuleId.allowedLanguageDocumented,
        passes: canonicalAllowedLanguage.every(copyBundle.toLowerCase().contains),
      ),
      _rule(
        id: ReturnTomorrowRitualRuleId.noBlockedRetentionPressure,
        passes: evaluateCopyPassesRules(copyBundle),
      ),
      _rule(
        id: ReturnTomorrowRitualRuleId.futureRetentionOnly,
        passes: guardrailLower.contains('future retention only'),
      ),
      _rule(
        id: ReturnTomorrowRitualRuleId.noNewLiveV1Ui,
        passes: guardrailLower.contains('no new live v1 ui') &&
            (!(input.v1RitualUiRequested ?? false) || betaProofComplete),
      ),
    ];
  }

  static bool _violatesNoStreaks(String copy) =>
      streakViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesDailyHomework(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in dailyHomeworkViolationMarkers) {
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

  static bool _violatesRequiredCheckIn(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in requiredCheckInViolationMarkers) {
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

  static bool _violatesPressureToRecord(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in pressureToRecordViolationMarkers) {
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

  static bool _violatesHabitTrackerLanguage(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in habitTrackerViolationMarkers) {
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

  static ReturnTomorrowRitualRule _rule({
    required ReturnTomorrowRitualRuleId id,
    required bool passes,
  }) =>
      ReturnTomorrowRitualRule(
        id: id,
        label: ReturnTomorrowRitualCopy.ruleLabelFor(id),
        status: passes
            ? ReturnTomorrowRitualRuleStatus.pass
            : ReturnTomorrowRitualRuleStatus.fail,
        detailLabel: passes
            ? ReturnTomorrowRitualCopy.detailPass
            : ReturnTomorrowRitualCopy.detailFail,
      );
}

class ReturnTomorrowRitualGateInput {
  const ReturnTomorrowRitualGateInput({
    this.paidIntentBetaComplete,
    this.v1RitualUiRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
    this.allowedLanguagePresentInCopy = true,
  });

  final bool? paidIntentBetaComplete;
  final bool? v1RitualUiRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
  final bool allowedLanguagePresentInCopy;
}

class ReturnTomorrowRitualRule {
  const ReturnTomorrowRitualRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final ReturnTomorrowRitualRuleId id;
  final String label;
  final ReturnTomorrowRitualRuleStatus status;
  final String detailLabel;
}

class ReturnTomorrowRitualGateResult {
  const ReturnTomorrowRitualGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.allowedLanguage,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.betaProofComplete,
    required this.v1LiveUiBlocked,
    required this.dailyHomeworkBlocked,
    required this.retentionPressureBlocked,
    required this.earliestRuleFailure,
  });

  final ReturnTomorrowRitualGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<String> allowedLanguage;
  final List<ReturnTomorrowRitualRule> rules;
  final List<ReturnTomorrowRitualRuleId> ruleOrder;
  final bool rulesPass;
  final bool betaProofComplete;
  final bool v1LiveUiBlocked;
  final bool dailyHomeworkBlocked;
  final bool retentionPressureBlocked;
  final ReturnTomorrowRitualRuleId? earliestRuleFailure;
}

class ReturnTomorrowRitualGateReport {
  const ReturnTomorrowRitualGateReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.allowedLanguageLine,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String allowedLanguageLine;
  final String orderLine;
  final String guardrail;
  final ReturnTomorrowRitualGateResult result;
}
