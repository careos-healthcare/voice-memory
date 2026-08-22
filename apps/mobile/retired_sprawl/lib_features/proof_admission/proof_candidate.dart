/// Structural inputs only. No transcript, citation, or source text is accepted.
final class ProofFeatureVector {
  ProofFeatureVector({
    required this.coverage,
    required this.specificity,
    required this.citationCount,
    required this.sourceCount,
    required this.chronology,
    required this.sourceDiversity,
    required this.citationSourceRatio,
    required this.corroborationRatio,
    required this.contradiction,
    required this.recency,
    required this.freshness,
    required this.transcriptSpecificity,
    required this.userConfirmed,
    required this.correctionHistoryCount,
    required this.acceptedCorrectionRatio,
    required this.positiveCorrectionHistory,
    required this.negativeCorrectionHistory,
    required this.wordingRejectionHistory,
    required this.evidenceRejectionHistory,
    required this.oneEntryPenalty,
    required this.stalePenalty,
    required double modelConfidence,
    required this.deterministicFallback,
  }) : modelConfidence = _cappedConfidence(modelConfidence) {
    for (final entry in _boundedRatios.entries) {
      if (!entry.value.isFinite || entry.value < 0 || entry.value > 1) {
        throw ArgumentError.value(entry.value, entry.key, 'must be in [0, 1]');
      }
    }
    if (citationCount < 0 ||
        sourceCount < 0 ||
        correctionHistoryCount < 0 ||
        positiveCorrectionHistory < 0 ||
        negativeCorrectionHistory < 0 ||
        wordingRejectionHistory < 0 ||
        evidenceRejectionHistory < 0) {
      throw ArgumentError('Counts must be non-negative.');
    }
  }

  final double coverage;
  final double specificity;
  final int citationCount;
  final int sourceCount;
  final double chronology;
  final double sourceDiversity;
  final double citationSourceRatio;
  final double corroborationRatio;
  final double contradiction;
  final double recency;
  final double freshness;
  final double transcriptSpecificity;
  final bool userConfirmed;
  final int correctionHistoryCount;
  final double acceptedCorrectionRatio;
  final int positiveCorrectionHistory;
  final int negativeCorrectionHistory;
  final int wordingRejectionHistory;
  final int evidenceRejectionHistory;
  final bool oneEntryPenalty;
  final bool stalePenalty;
  final double modelConfidence;
  final double deterministicFallback;

  static double _cappedConfidence(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'modelConfidence', 'must be finite');
    }
    return value.clamp(0, 1).toDouble();
  }

  Map<String, double> get _boundedRatios => {
    'coverage': coverage,
    'specificity': specificity,
    'chronology': chronology,
    'sourceDiversity': sourceDiversity,
    'citationSourceRatio': citationSourceRatio,
    'corroborationRatio': corroborationRatio,
    'contradiction': contradiction,
    'recency': recency,
    'freshness': freshness,
    'transcriptSpecificity': transcriptSpecificity,
    'deterministicFallback': deterministicFallback,
  };

  /// Contains numeric/bool structural data only, making text leakage impossible.
  Map<String, Object> toJson() => {
    'coverage': coverage,
    'specificity': specificity,
    'citationCount': citationCount,
    'sourceCount': sourceCount,
    'chronology': chronology,
    'sourceDiversity': sourceDiversity,
    'citationSourceRatio': citationSourceRatio,
    'corroborationRatio': corroborationRatio,
    'contradiction': contradiction,
    'recency': recency,
    'freshness': freshness,
    'transcriptSpecificity': transcriptSpecificity,
    'userConfirmed': userConfirmed,
    'correctionHistoryCount': correctionHistoryCount,
    'acceptedCorrectionRatio': acceptedCorrectionRatio,
    'positiveCorrectionHistory': positiveCorrectionHistory,
    'negativeCorrectionHistory': negativeCorrectionHistory,
    'wordingRejectionHistory': wordingRejectionHistory,
    'evidenceRejectionHistory': evidenceRejectionHistory,
    'oneEntryPenalty': oneEntryPenalty,
    'stalePenalty': stalePenalty,
    'modelConfidence': modelConfidence,
    'deterministicFallback': deterministicFallback,
  };
}

final class ProofCandidate {
  ProofCandidate({
    required this.stableId,
    required this.isValid,
    required this.hardSafetyPassed,
    required this.features,
  }) {
    if (stableId.isEmpty) {
      throw ArgumentError.value(stableId, 'stableId', 'must not be empty');
    }
  }

  final String stableId;
  final bool isValid;

  /// A non-negotiable gate. It is never converted to a weighted feature.
  final bool hardSafetyPassed;
  final ProofFeatureVector features;

  bool get isAdmissible => isValid && hardSafetyPassed;
}