import 'autonomous_muse_models.dart';

enum BridgeConfidenceBand { definitive, actionable, fringe, discarded }

final class BridgeConfidenceDecision {
  const BridgeConfidenceDecision({
    required this.band,
    required this.combinedConfidence,
  });

  final BridgeConfidenceBand band;
  final double combinedConfidence;

  bool get autoLink => band == BridgeConfidenceBand.definitive;
  bool get reviewable => band == BridgeConfidenceBand.actionable;
  bool get deepConnection => band == BridgeConfidenceBand.fringe;
}

final class BridgeConfidenceEngine {
  const BridgeConfidenceEngine({
    this.similarityWeight = .85,
    this.rationaleWeight = .15,
  }) : assert(similarityWeight >= 0),
       assert(rationaleWeight >= 0),
       assert(similarityWeight + rationaleWeight > 0);

  static const definitiveThreshold = .95;
  static const actionableThreshold = .85;
  static const fringeThreshold = .75;
  static const epsilon = 1e-7;

  final double similarityWeight;
  final double rationaleWeight;

  BridgeConfidenceDecision categorize(LegacyBridgeSuggestion suggestion) =>
      categorizeScores(
        cosineSimilarity: suggestion.confidenceScore,
        rationaleConfidence: suggestion.rationaleConfidence,
      );

  BridgeConfidenceDecision categorizeScores({
    required double cosineSimilarity,
    required double rationaleConfidence,
  }) {
    final totalWeight = similarityWeight + rationaleWeight;
    final combined =
        ((cosineSimilarity.clamp(0, 1) * similarityWeight) +
            (rationaleConfidence.clamp(0, 1) * rationaleWeight)) /
        totalWeight;
    final definitive =
        cosineSimilarity - definitiveThreshold > epsilon &&
        rationaleConfidence + epsilon >= actionableThreshold &&
        combined - definitiveThreshold > epsilon;
    final band = definitive
        ? BridgeConfidenceBand.definitive
        : combined + epsilon >= actionableThreshold
        ? BridgeConfidenceBand.actionable
        : combined + epsilon >= fringeThreshold
        ? BridgeConfidenceBand.fringe
        : BridgeConfidenceBand.discarded;
    return BridgeConfidenceDecision(band: band, combinedConfidence: combined);
  }
}
