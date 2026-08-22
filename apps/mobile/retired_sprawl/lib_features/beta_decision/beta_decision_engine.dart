import 'package:archiveme_mobile/features/beta_decision/beta_decision_copy.dart';
import 'package:archiveme_mobile/features/beta_decision/beta_decision_model.dart';

/// Chooses one next build branch from real tester behaviour — read-only.
abstract final class BetaDecisionEngine {
  BetaDecisionEngine._();

  static const expansionCaredAboutProofThreshold = 3;
  static const expansionExplicitAskThreshold = 2;

  static const _priority = <BetaNextBuildRecommendation>[
    BetaNextBuildRecommendation.fixRecordOnboardingCopy,
    BetaNextBuildRecommendation.fixCaptureFriction,
    BetaNextBuildRecommendation.addReturnReason,
    BetaNextBuildRecommendation.improveProofEmotionalClarity,
    BetaNextBuildRecommendation.sharpenProPackaging,
    BetaNextBuildRecommendation.expandProUtility,
  ];

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled;

  static BetaDecisionResult build({required List<BetaTesterOutcome> outcomes}) {
    if (outcomes.isEmpty) {
      return _emptyResult();
    }

    final evidenceCounts = _countSignals(outcomes);
    final failingBranchCounts = <BetaNextBuildRecommendation, int>{};
    for (final outcome in outcomes) {
      final branch = _failingBranchForTester(outcome);
      if (branch == null) continue;
      failingBranchCounts[branch] = (failingBranchCounts[branch] ?? 0) + 1;
    }

    final caredAboutProofCount = outcomes
        .where((o) => o.has(BetaDecisionSignal.proofFeltMeaningful))
        .length;
    final askedUtilityCount = outcomes
        .where((o) => o.askedForUtilityExpansion)
        .length;
    final askedWithoutCareCount = outcomes
        .where(
          (o) =>
              o.askedForUtilityExpansion &&
              !o.has(BetaDecisionSignal.proofFeltMeaningful),
        )
        .length;

    final expansionAllowed =
        caredAboutProofCount >= expansionCaredAboutProofThreshold ||
        askedUtilityCount >= expansionExplicitAskThreshold;

    if (askedWithoutCareCount > 0 && !expansionAllowed) {
      return BetaDecisionResult(
        primaryRecommendation: BetaNextBuildRecommendation.holdDoNotExpand,
        reason:
            '$askedWithoutCareCount tester(s) asked for history/export/report before proof felt meaningful. '
            'Need $expansionCaredAboutProofThreshold caring-about-proof signals or '
            '$expansionExplicitAskThreshold explicit utility asks before expansion.',
        evidenceCounts: evidenceCounts,
        nextActionCopy: BetaDecisionCopy.holdDoNotExpand,
        testerCount: outcomes.length,
        failingBranchCounts: failingBranchCounts,
        expansionAllowed: false,
      );
    }

    for (final recommendation in _priority) {
      final count = failingBranchCounts[recommendation] ?? 0;
      if (count == 0) continue;
      if (recommendation == BetaNextBuildRecommendation.expandProUtility &&
          !expansionAllowed) {
        continue;
      }
      return BetaDecisionResult(
        primaryRecommendation: recommendation,
        reason: _reasonFor(
          recommendation: recommendation,
          count: count,
          testerCount: outcomes.length,
          caredAboutProofCount: caredAboutProofCount,
          askedUtilityCount: askedUtilityCount,
        ),
        evidenceCounts: evidenceCounts,
        nextActionCopy: BetaDecisionCopy.recommendationFor(recommendation),
        testerCount: outcomes.length,
        failingBranchCounts: failingBranchCounts,
        expansionAllowed: expansionAllowed,
      );
    }

    if (askedUtilityCount > 0 && !expansionAllowed) {
      return BetaDecisionResult(
        primaryRecommendation: BetaNextBuildRecommendation.holdDoNotExpand,
        reason:
            'Utility asks logged ($askedUtilityCount) but expansion gate not met. '
            'Wait for more proof-care signals.',
        evidenceCounts: evidenceCounts,
        nextActionCopy: BetaDecisionCopy.holdDoNotExpand,
        testerCount: outcomes.length,
        failingBranchCounts: failingBranchCounts,
        expansionAllowed: false,
      );
    }

    return BetaDecisionResult(
      primaryRecommendation: BetaNextBuildRecommendation.noFailingBranch,
      reason:
          'Logged ${outcomes.length} tester outcome(s) with no failing branch in priority order.',
      evidenceCounts: evidenceCounts,
      nextActionCopy: BetaDecisionCopy.noFailingBranchBody,
      testerCount: outcomes.length,
      failingBranchCounts: failingBranchCounts,
      expansionAllowed: expansionAllowed,
    );
  }

  static BetaNextBuildRecommendation? _failingBranchForTester(
    BetaTesterOutcome outcome,
  ) {
    final signals = outcome.signals;

    if (outcome.misunderstood) {
      return BetaNextBuildRecommendation.fixRecordOnboardingCopy;
    }

    if (!signals.contains(BetaDecisionSignal.savedFirstMoment) &&
        (!signals.contains(BetaDecisionSignal.tappedRecord) ||
            signals.contains(BetaDecisionSignal.hesitatedAtCapture) ||
            signals.contains(BetaDecisionSignal.confusedWhatToWrite))) {
      return BetaNextBuildRecommendation.fixCaptureFriction;
    }

    if (signals.contains(BetaDecisionSignal.savedFirstMoment) &&
        !signals.contains(BetaDecisionSignal.returnedDay2)) {
      return BetaNextBuildRecommendation.addReturnReason;
    }

    if (outcome.reachedProof &&
        !signals.contains(BetaDecisionSignal.proofFeltMeaningful)) {
      return BetaNextBuildRecommendation.improveProofEmotionalClarity;
    }

    if (signals.contains(BetaDecisionSignal.proofFeltMeaningful) &&
        !signals.contains(BetaDecisionSignal.willingToPayForLongerTrail)) {
      return BetaNextBuildRecommendation.sharpenProPackaging;
    }

    if (signals.contains(BetaDecisionSignal.proofFeltMeaningful) &&
        outcome.askedForUtilityExpansion) {
      return BetaNextBuildRecommendation.expandProUtility;
    }

    return null;
  }

  static Map<BetaDecisionSignal, int> _countSignals(
    List<BetaTesterOutcome> outcomes,
  ) {
    final counts = <BetaDecisionSignal, int>{};
    for (final outcome in outcomes) {
      for (final signal in outcome.signals) {
        counts[signal] = (counts[signal] ?? 0) + 1;
      }
    }
    return counts;
  }

  static String _reasonFor({
    required BetaNextBuildRecommendation recommendation,
    required int count,
    required int testerCount,
    required int caredAboutProofCount,
    required int askedUtilityCount,
  }) => switch (recommendation) {
    BetaNextBuildRecommendation.fixRecordOnboardingCopy =>
      '$count of $testerCount tester(s) misunderstood the promise or positioned ArchiveMe as journal/chat/therapy.',
    BetaNextBuildRecommendation.fixCaptureFriction =>
      '$count of $testerCount tester(s) understood the promise but did not capture a first moment.',
    BetaNextBuildRecommendation.addReturnReason =>
      '$count of $testerCount tester(s) saved once but did not return on day 2.',
    BetaNextBuildRecommendation.improveProofEmotionalClarity =>
      '$count of $testerCount tester(s) reached proof but it did not feel meaningful.',
    BetaNextBuildRecommendation.sharpenProPackaging =>
      '$count of $testerCount tester(s) cared about proof but would not pay for the longer trail.',
    BetaNextBuildRecommendation.expandProUtility =>
      '$count of $testerCount tester(s) asked for history/export/report after proof mattered. '
          'Cared-about-proof: $caredAboutProofCount. Utility asks: $askedUtilityCount.',
    _ => '$count of $testerCount tester(s) matched this branch.',
  };

  static BetaDecisionResult _emptyResult() => const BetaDecisionResult(
    primaryRecommendation: BetaNextBuildRecommendation.insufficientData,
    reason: 'No tester outcomes logged yet.',
    evidenceCounts: {},
    nextActionCopy: BetaDecisionCopy.insufficientDataBody,
    testerCount: 0,
    failingBranchCounts: {},
    expansionAllowed: false,
  );
}