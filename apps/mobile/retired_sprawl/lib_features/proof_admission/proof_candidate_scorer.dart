import 'package:archiveme_mobile/features/proof_admission/generated/proof_admission_weights.g.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_config.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_candidate.dart';

final class ProofCandidateScore {
  const ProofCandidateScore({
    required this.candidate,
    required this.weightedScore,
  });

  final ProofCandidate candidate;
  final double weightedScore;
}

/// Pure, deterministic scoring and canonical ranking.
final class ProofCandidateScorer {
  ProofCandidateScorer({ProofAdmissionConfig? config})
    : config = config ?? generatedProofAdmissionConfig;

  final ProofAdmissionConfig config;

  double score(ProofCandidate candidate) {
    final features = candidate.features;
    final confidence = features.modelConfidence.clamp(
      0,
      config.modelConfidenceCap,
    );
    final values = <String, double>{
      'coverage': features.coverage,
      'specificity': features.specificity,
      'citationCount': features.citationCount.toDouble(),
      'sourceCount': features.sourceCount.toDouble(),
      'chronology': features.chronology,
      'sourceDiversity': features.sourceDiversity,
      'citationSourceRatio': features.citationSourceRatio,
      'corroborationRatio': features.corroborationRatio,
      'contradiction': features.contradiction,
      'recency': features.recency,
      'freshness': features.freshness,
      'transcriptSpecificity': features.transcriptSpecificity,
      'userConfirmed': features.userConfirmed ? 1 : 0,
      'correctionHistoryCount': features.correctionHistoryCount.toDouble(),
      'acceptedCorrectionRatio': features.acceptedCorrectionRatio,
      'positiveCorrectionHistory': features.positiveCorrectionHistory
          .toDouble(),
      'negativeCorrectionHistory': features.negativeCorrectionHistory
          .toDouble(),
      'wordingRejectionHistory': features.wordingRejectionHistory.toDouble(),
      'evidenceRejectionHistory': features.evidenceRejectionHistory.toDouble(),
      'oneEntryPenalty': features.oneEntryPenalty ? 1 : 0,
      'stalePenalty': features.stalePenalty ? 1 : 0,
      'modelConfidence': confidence.toDouble(),
      'deterministicFallback': features.deterministicFallback,
    };

    var total = 0.0;
    for (final key in ProofAdmissionConfig.requiredWeightKeys) {
      total += values[key]! * config.weights[key]!;
    }
    return total;
  }

  /// Safety-failed candidates are excluded by a hard gate, never down-weighted.
  List<ProofCandidateScore> rank(Iterable<ProofCandidate> candidates) {
    final seenIds = <String>{};
    final ranked = <ProofCandidateScore>[];
    for (final candidate in candidates) {
      if (!seenIds.add(candidate.stableId)) {
        throw ArgumentError.value(
          candidate.stableId,
          'candidates',
          'stable IDs must be unique',
        );
      }
      if (candidate.hardSafetyPassed) {
        ranked.add(
          ProofCandidateScore(
            candidate: candidate,
            weightedScore: score(candidate),
          ),
        );
      }
    }
    ranked.sort(_compare);
    return List.unmodifiable(ranked);
  }

  static int _compare(ProofCandidateScore left, ProofCandidateScore right) {
    var order = right.weightedScore.compareTo(left.weightedScore);
    if (order != 0) return order;

    order = _compareBool(right.candidate.isValid, left.candidate.isValid);
    if (order != 0) return order;

    final leftFeatures = left.candidate.features;
    final rightFeatures = right.candidate.features;
    order = rightFeatures.sourceCount.compareTo(leftFeatures.sourceCount);
    if (order != 0) return order;

    order = leftFeatures.contradiction.compareTo(rightFeatures.contradiction);
    if (order != 0) return order;

    order = rightFeatures.specificity.compareTo(leftFeatures.specificity);
    if (order != 0) return order;

    final leftNewness = leftFeatures.recency + leftFeatures.freshness;
    final rightNewness = rightFeatures.recency + rightFeatures.freshness;
    order = rightNewness.compareTo(leftNewness);
    if (order != 0) return order;

    return left.candidate.stableId.compareTo(right.candidate.stableId);
  }

  static int _compareBool(bool left, bool right) {
    return (left ? 1 : 0).compareTo(right ? 1 : 0);
  }
}