/// Combined beta results summary — metadata only, no journal text.
class BetaResultsSummary {
  const BetaResultsSummary({
    required this.totalTesters,
    required this.firstSessionSaveCount,
    required this.usefulProofCount,
    required this.tooVagueOrNotRelevantCount,
    required this.sawProCount,
    required this.understandsProCount,
    required this.paywallCtaTapCount,
    required this.wouldPayYesMaybeCount,
    required this.evidenceTrailClearCount,
    required this.wouldNotPayMonthlyCount,
    required this.moreProofOverTimeCount,
    required this.clearerTimelineCount,
    required this.lowerPriceCount,
    required this.price299Count,
    required this.price499Count,
    required this.price799Count,
  });

  final int totalTesters;
  final int firstSessionSaveCount;
  final int usefulProofCount;
  final int tooVagueOrNotRelevantCount;
  final int sawProCount;
  final int understandsProCount;
  final int paywallCtaTapCount;
  final int wouldPayYesMaybeCount;
  final int evidenceTrailClearCount;
  final int wouldNotPayMonthlyCount;
  final int moreProofOverTimeCount;
  final int clearerTimelineCount;
  final int lowerPriceCount;
  final int price299Count;
  final int price499Count;
  final int price799Count;
}

enum BetaResultsDecision {
  insufficientData,
  protectProof,
  improveFirstSession,
  improveTimelineExplanation,
  proTooHidden,
  improveProExplanation,
  pricingValidation,
  evidenceTrailFocus,
  productionCandidate,
}