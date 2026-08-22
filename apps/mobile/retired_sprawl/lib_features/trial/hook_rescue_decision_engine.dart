import 'package:archiveme_mobile/features/trial/hook_rescue_decision_model.dart';
import 'package:archiveme_mobile/features/trial/trial_summary_model.dart';

/// Picks the single best next fix for the tomorrow check-in hook.
///
/// Every fix is gated by diagnosis so we never show all of them at once.
class HookRescueDecisionEngine {
  const HookRescueDecisionEngine();

  HookRescueDecision decide(TrialSummaryModel summary) {
    final d = summary.hookDiagnosis;

    final created = d.checkInsCreated;
    final dueShown = d.checkInsDueShown;
    final completed = d.checkInsCompleted;

    // reminder: people care about the question but do not return.
    final reminder = summary.reminderReadiness == ReminderReadiness.ready;

    // guidedCheckIn: people are confused by the check-in.
    final confusingRate = dueShown == 0 ? 0.0 : d.confusingCount / dueShown;
    final clarityRate = d.clarityIssueRate ?? 0.0;
    final guidedCheckIn = confusingRate >= 0.25 || clarityRate >= 0.25;

    // sharperQuestion: people do not care enough about the question.
    final didNotCareRate = created == 0 ? 0.0 : d.didNotCareCount / created;
    final questionRatedTotal = d.questionRatedTotal;
    final positiveQuestion =
        d.checkInQuestionRatedUseful + d.checkInQuestionRatedSortOf;
    final questionNotUsefulRate = questionRatedTotal == 0
        ? 0.0
        : d.checkInQuestionRatedNotUseful / questionRatedTotal;
    final questionNotUsefulHigh =
        d.checkInQuestionRatedNotUseful >= 1 &&
        d.checkInQuestionRatedNotUseful >= positiveQuestion;
    final sharperQuestion = didNotCareRate >= 0.25 || questionNotUsefulHigh;

    // betterResult: people return but do not find the result useful.
    final resultNotUsefulRate = completed == 0
        ? 0.0
        : d.resultNotUsefulCount / completed;
    final topNotUsefulReasonCount = d.notUsefulReasonCounts.isEmpty
        ? 0
        : d.notUsefulReasonCounts.values.reduce((a, b) => a > b ? a : b);
    final betterResult =
        resultNotUsefulRate >= 0.25 || d.notUsefulReasonCounts.isNotEmpty;

    // betterFirstRecord: people struggle to save the first moment.
    final noReflectionYet = summary.firstReflectionSaved == 0 && created == 0;
    final startedButNotSaved =
        summary.recordingStartedCount >= 1 && summary.firstReflectionSaved == 0;
    final betterFirstRecord = noReflectionYet || startedButNotSaved;

    // Priority order for the primary fix.
    final ordered = <HookRescueAction>[
      if (guidedCheckIn) HookRescueAction.guidedCheckIn,
      if (betterResult) HookRescueAction.betterResult,
      if (sharperQuestion) HookRescueAction.sharperQuestion,
      if (reminder) HookRescueAction.reminder,
      if (betterFirstRecord) HookRescueAction.betterFirstRecord,
    ];

    // Escalation levels per fix (only meaningful when the fix is triggered).
    final intensities = <HookRescueAction, HookRescueIntensity>{
      if (sharperQuestion)
        HookRescueAction.sharperQuestion: _sharperIntensity(
          didNotCareRate: didNotCareRate,
          questionNotUsefulRate: questionNotUsefulRate,
        ),
      if (betterResult)
        HookRescueAction.betterResult: _betterResultIntensity(
          resultNotUsefulRate: resultNotUsefulRate,
          topNotUsefulReasonCount: topNotUsefulReasonCount,
          hasNotUsefulReasons: d.notUsefulReasonCounts.isNotEmpty,
        ),
    };

    if (ordered.isEmpty) {
      return HookRescueDecision(
        primaryAction: HookRescueAction.none,
        secondaryActions: const [],
        reason: 'No clear fix needed yet.',
        confidence: _confidence(summary),
        intensities: intensities,
      );
    }

    final primary = ordered.first;
    final secondary = ordered.skip(1).toList();

    return HookRescueDecision(
      primaryAction: primary,
      secondaryActions: secondary,
      reason: _reasonFor(primary),
      confidence: _confidence(summary),
      intensities: intensities,
    );
  }

  HookRescueIntensity _sharperIntensity({
    required double didNotCareRate,
    required double questionNotUsefulRate,
  }) {
    if (didNotCareRate >= 0.40 || questionNotUsefulRate >= 0.40) {
      return HookRescueIntensity.aggressive;
    }
    if (didNotCareRate >= 0.25) return HookRescueIntensity.elevated;
    return HookRescueIntensity.normal;
  }

  HookRescueIntensity _betterResultIntensity({
    required double resultNotUsefulRate,
    required int topNotUsefulReasonCount,
    required bool hasNotUsefulReasons,
  }) {
    if (resultNotUsefulRate >= 0.40 || topNotUsefulReasonCount >= 2) {
      return HookRescueIntensity.aggressive;
    }
    if (resultNotUsefulRate >= 0.25 || hasNotUsefulReasons) {
      return HookRescueIntensity.elevated;
    }
    return HookRescueIntensity.normal;
  }

  String _reasonFor(HookRescueAction action) {
    switch (action) {
      case HookRescueAction.guidedCheckIn:
        return 'People are confused by the check-in.';
      case HookRescueAction.betterResult:
        return 'People return but do not find the result useful.';
      case HookRescueAction.sharperQuestion:
        return 'People do not care enough about the question.';
      case HookRescueAction.reminder:
        return 'People care about the question but do not return.';
      case HookRescueAction.betterFirstRecord:
        return 'People struggle to save the first moment.';
      case HookRescueAction.none:
        return 'No clear fix needed yet.';
    }
  }

  HookRescueConfidence _confidence(TrialSummaryModel summary) {
    final d = summary.hookDiagnosis;
    final volume =
        d.checkInsCreated +
        d.questionRatedTotal +
        d.resultRatedTotal +
        summary.recordingStartedCount;
    if (volume >= 4) return HookRescueConfidence.high;
    if (volume >= 2) return HookRescueConfidence.medium;
    return HookRescueConfidence.low;
  }
}