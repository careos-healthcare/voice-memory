import '../capacity_loop/capacity_activation_fit_models.dart';
import '../capacity_loop/capacity_beta_signal_models.dart';
import 'beta_feedback_response_copy.dart';
import 'beta_feedback_response_models.dart';

/// Maps local capacity beta signals to cautious product-readiness responses.
class BetaFeedbackResponseEngine {
  const BetaFeedbackResponseEngine();

  BetaFeedbackResponseResult build(BetaFeedbackResponseInput input) {
    if (!input.capacityWedgeActive) {
      return BetaFeedbackResponseResult.hidden;
    }

    final issueId = _selectIssueId(input);
    if (issueId == null) {
      return BetaFeedbackResponseResult.hidden;
    }

    return _resultForIssue(issueId);
  }

  BetaFeedbackResponseResult buildFromBetaSnapshot({
    required CapacityBetaSignalSnapshot snapshot,
    required bool capacityWedgeActive,
    required bool fitIsPositive,
    required bool fitIsUnclear,
    required bool fitNotAnswered,
    required bool dailyChangeDismissed,
    required bool dailyChangeAvailable,
    required bool paidIntentStrongWtp,
    required bool paidIntentSoftWtp,
  }) {
    return build(
      BetaFeedbackResponseInput(
        capacityWedgeActive: capacityWedgeActive,
        capacityMomentCount: snapshot.capacityMomentCount,
        activationTarget: snapshot.activationTarget,
        fitIsPositive: fitIsPositive,
        fitIsUnclear: fitIsUnclear,
        fitNotAnswered: fitNotAnswered,
        pullReasonRecordCount: snapshot.pullReasonRecordCount,
        outcomeRecordCount: snapshot.outcomeRecordCount,
        laterCostRecordCount: snapshot.laterCostRecordCount,
        weeklyReviewAvailable: snapshot.weeklyReviewAvailable,
        boundaryResponseSelected: snapshot.boundaryResponseSelected,
        boundaryResponseCopied: snapshot.boundaryResponseCopied,
        proInterestCaptured: snapshot.proInterestCaptured,
        paidIntentStrongWtp: paidIntentStrongWtp,
        paidIntentSoftWtp: paidIntentSoftWtp,
        dailyChangeAvailable: dailyChangeAvailable,
        dailyChangeDismissed: dailyChangeDismissed,
      ),
    );
  }

  String? _selectIssueId(BetaFeedbackResponseInput input) {
    final count = input.capacityMomentCount;
    final target = input.activationTarget;
    final activationReached = count >= target;

    if (activationReached &&
        input.fitIsPositive &&
        input.dailyChangeAvailable &&
        (input.paidIntentStrongWtp || input.paidIntentSoftWtp) &&
        (input.weeklyReviewAvailable || input.outcomeRecordCount >= 1)) {
      return BetaFeedbackIssueIds.paidSignalReady;
    }

    if (count <= 0) {
      return BetaFeedbackIssueIds.firstMomentBlocked;
    }

    if (count > 0 && count < target) {
      return BetaFeedbackIssueIds.activationDropoff;
    }

    if (activationReached &&
        input.dailyChangeDismissed &&
        (input.fitIsUnclear || input.fitNotAnswered || !input.fitIsPositive)) {
      return BetaFeedbackIssueIds.repetitiveLoop;
    }

    if (activationReached &&
        !input.boundaryResponseSelected &&
        !input.boundaryResponseCopied &&
        input.pullReasonRecordCount >= 1) {
      return BetaFeedbackIssueIds.weakAlternative;
    }

    if (activationReached &&
        (input.fitIsUnclear || input.fitNotAnswered)) {
      return BetaFeedbackIssueIds.unclearPromise;
    }

    return null;
  }

  BetaFeedbackResponseResult _resultForIssue(String issueId) {
    final (
      problem,
      change,
      success,
      notToChange,
    ) = switch (issueId) {
      BetaFeedbackIssueIds.unclearPromise => (
          BetaFeedbackResponseCopy.unclearPromiseProblem,
          BetaFeedbackResponseCopy.unclearPromiseChange,
          BetaFeedbackResponseCopy.unclearPromiseSuccess,
          BetaFeedbackResponseCopy.doNotAddBackend,
        ),
      BetaFeedbackIssueIds.firstMomentBlocked => (
          BetaFeedbackResponseCopy.firstMomentBlockedProblem,
          BetaFeedbackResponseCopy.firstMomentBlockedChange,
          BetaFeedbackResponseCopy.firstMomentBlockedSuccess,
          BetaFeedbackResponseCopy.doNotEnablePayments,
        ),
      BetaFeedbackIssueIds.activationDropoff => (
          BetaFeedbackResponseCopy.activationDropoffProblem,
          BetaFeedbackResponseCopy.activationDropoffChange,
          BetaFeedbackResponseCopy.activationDropoffSuccess,
          BetaFeedbackResponseCopy.doNotEnablePayments,
        ),
      BetaFeedbackIssueIds.repetitiveLoop => (
          BetaFeedbackResponseCopy.repetitiveLoopProblem,
          BetaFeedbackResponseCopy.repetitiveLoopChange,
          BetaFeedbackResponseCopy.repetitiveLoopSuccess,
          BetaFeedbackResponseCopy.doNotAddBackend,
        ),
      BetaFeedbackIssueIds.weakAlternative => (
          BetaFeedbackResponseCopy.weakAlternativeProblem,
          BetaFeedbackResponseCopy.weakAlternativeChange,
          BetaFeedbackResponseCopy.weakAlternativeSuccess,
          BetaFeedbackResponseCopy.doNotEnablePayments,
        ),
      BetaFeedbackIssueIds.paidSignalReady => (
          BetaFeedbackResponseCopy.paidSignalReadyProblem,
          BetaFeedbackResponseCopy.paidSignalReadyChange,
          BetaFeedbackResponseCopy.paidSignalReadySuccess,
          BetaFeedbackResponseCopy.doNotEnablePayments,
        ),
      _ => ('', '', '', ''),
    };

    if (problem.isEmpty) return BetaFeedbackResponseResult.hidden;

    return BetaFeedbackResponseResult(
      hasRecommendation: true,
      issueId: issueId,
      localBetaSignalLabel:
          '${BetaFeedbackResponseCopy.localBetaSignalPrefix}: $issueId',
      suggestedNextFixLabel: BetaFeedbackResponseCopy.suggestedFixForIssue(issueId),
      recommendedResponseSummary: change,
      productProblemSummary: problem,
      whatToChangeSummary: change,
      whatNotToChangeSummary: notToChange,
      successSignalSummary: success,
    );
  }

  static bool fitNotAnsweredFromRecord(CapacityActivationFitRecord? record) {
    if (record == null) return true;
    if (record.isSkipped) return true;
    if (!record.isAnswered) return true;
    return record.responseId == CapacityActivationFitResponseIds.notYet ||
        record.responseId == CapacityActivationFitResponseIds.tooEarly ||
        record.responseId.isEmpty;
  }
}
