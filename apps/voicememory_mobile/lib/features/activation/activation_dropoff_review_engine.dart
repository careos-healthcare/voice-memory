import '../beta/beta_activation_loop_counts.dart';
import 'activation_dropoff_review_copy.dart';
import 'activation_dropoff_review_model.dart';

/// Builds the internal activation drop-off review from local counters.
abstract final class ActivationDropoffReviewEngine {
  ActivationDropoffReviewEngine._();

  static ActivationDropoffReview build({
    ActivationDropoffCounters? counters,
    BetaActivationLoopCounts? betaCounts,
  }) {
    final resolved = counters ?? fromBetaCounts(betaCounts);
    final rows = _rowsFor(resolved);
    final bottleneck = _resolveBottleneck(resolved);

    return ActivationDropoffReview(
      title: ActivationDropoffReviewCopy.title,
      rows: rows,
      bottleneckLabel: ActivationDropoffReviewCopy.bottleneckLabel,
      bottleneckSummary: bottleneck.summary,
      activationLoopComplete: bottleneck.complete,
    );
  }

  static ActivationDropoffCounters fromBetaCounts(
    BetaActivationLoopCounts? betaCounts,
  ) {
    final counts = betaCounts ?? const BetaActivationLoopCounts();
    final firstProof = counts.thirdMomentSaved > 0
        ? counts.thirdMomentSaved
        : counts.confirmedRepeatSeen;

    return ActivationDropoffCounters(
      appOpened: counts.appOpened,
      firstUsePromptSeen: counts.firstUsePromptSeen,
      firstMomentSaved: counts.firstMomentSaved,
      returnedAfterFirstMoment: counts.oneEntryReturnScreenSeen,
      secondMomentSaved: counts.secondMomentSaved,
      firstProofReached: firstProof,
      returnedAfterFirstProof: counts.returnedAfterFirstProof,
      fourthMomentSaved: counts.fourthMomentSaved,
      returnCheckAnswered: counts.returnCheckAnswered,
      proBoundarySeen: counts.proBoundarySeen,
      proTapped: counts.purchaseTapped,
    );
  }

  static List<ActivationDropoffRow> _rowsFor(ActivationDropoffCounters counts) {
    final specs = <(ActivationDropoffRowId, String, int)>[
      (
        ActivationDropoffRowId.appOpened,
        ActivationDropoffReviewCopy.rowAppOpened,
        counts.appOpened,
      ),
      (
        ActivationDropoffRowId.firstUsePromptSeen,
        ActivationDropoffReviewCopy.rowFirstUsePromptSeen,
        counts.firstUsePromptSeen,
      ),
      (
        ActivationDropoffRowId.firstMomentSaved,
        ActivationDropoffReviewCopy.rowFirstMomentSaved,
        counts.firstMomentSaved,
      ),
      (
        ActivationDropoffRowId.returnedAfterFirstMoment,
        ActivationDropoffReviewCopy.rowReturnedAfterFirstMoment,
        counts.returnedAfterFirstMoment,
      ),
      (
        ActivationDropoffRowId.secondMomentSaved,
        ActivationDropoffReviewCopy.rowSecondMomentSaved,
        counts.secondMomentSaved,
      ),
      (
        ActivationDropoffRowId.firstProofReached,
        ActivationDropoffReviewCopy.rowFirstProofReached,
        counts.firstProofReached,
      ),
      (
        ActivationDropoffRowId.returnedAfterFirstProof,
        ActivationDropoffReviewCopy.rowReturnedAfterFirstProof,
        counts.returnedAfterFirstProof,
      ),
      (
        ActivationDropoffRowId.fourthMomentSaved,
        ActivationDropoffReviewCopy.rowFourthMomentSaved,
        counts.fourthMomentSaved,
      ),
      (
        ActivationDropoffRowId.returnCheckAnswered,
        ActivationDropoffReviewCopy.rowReturnCheckAnswered,
        counts.returnCheckAnswered,
      ),
      (
        ActivationDropoffRowId.proBoundarySeen,
        ActivationDropoffReviewCopy.rowProBoundarySeen,
        counts.proBoundarySeen,
      ),
      (
        ActivationDropoffRowId.proTapped,
        ActivationDropoffReviewCopy.rowProTapped,
        counts.proTapped,
      ),
    ];

    final rows = <ActivationDropoffRow>[];
    for (var index = 0; index < specs.length; index++) {
      final (id, label, count) = specs[index];
      final priorReached = index > 0 &&
          specs.sublist(0, index).every((spec) => spec.$3 > 0);
      rows.add(
        ActivationDropoffRow(
          id: id,
          label: label,
          count: count,
          status: _statusFor(count: count, priorStepsReached: priorReached),
        ),
      );
    }
    return rows;
  }

  static ActivationDropoffRowStatus _statusFor({
    required int count,
    required bool priorStepsReached,
  }) {
    if (count > 0) return ActivationDropoffRowStatus.reached;
    if (priorStepsReached) return ActivationDropoffRowStatus.started;
    return ActivationDropoffRowStatus.notReached;
  }

  static ({String summary, bool complete}) _resolveBottleneck(
    ActivationDropoffCounters counts,
  ) {
    if (counts.firstMomentSaved <= 0) {
      return (
        summary: ActivationDropoffReviewCopy.bottleneckFirstMomentSaved,
        complete: false,
      );
    }
    if (counts.secondMomentSaved <= 0) {
      return (
        summary: ActivationDropoffReviewCopy.bottleneckSecondMomentSaved,
        complete: false,
      );
    }
    if (counts.firstProofReached <= 0) {
      return (
        summary: ActivationDropoffReviewCopy.bottleneckFirstProofReached,
        complete: false,
      );
    }
    if (counts.returnedAfterFirstProof <= 0) {
      return (
        summary: ActivationDropoffReviewCopy.bottleneckReturnedAfterFirstProof,
        complete: false,
      );
    }
    if (counts.returnCheckAnswered <= 0) {
      return (
        summary: ActivationDropoffReviewCopy.bottleneckReturnCheckAnswered,
        complete: false,
      );
    }
    if (counts.proTapped <= 0) {
      return (
        summary: ActivationDropoffReviewCopy.bottleneckProTapped,
        complete: false,
      );
    }
    return (
      summary: ActivationDropoffReviewCopy.bottleneckNone,
      complete: true,
    );
  }
}
