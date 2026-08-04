import '../../security/user_content_safety.dart';
import 'proof_admission_models.dart';

/// Customer-facing presentation data. It can only be constructed from the
/// immutable, admitted proof boundary—not parser or provider DTOs.
class VerifiedProofViewModel {
  const VerifiedProofViewModel({
    required this.proofId,
    required this.observation,
    required this.evidence,
    required this.confidenceLabel,
    required this.repeatFrequency,
    required this.trendLabel,
    required this.counterexampleCount,
    required this.contradictionCount,
    required this.firstOccurrence,
    required this.lastOccurrence,
  });

  final String proofId;
  final String observation;
  final List<VerifiedProofEvidenceViewModel> evidence;
  final String confidenceLabel;
  final int repeatFrequency;
  final String trendLabel;
  final int counterexampleCount;
  final int contradictionCount;
  final DateTime firstOccurrence;
  final DateTime lastOccurrence;

  factory VerifiedProofViewModel.fromVerifiedProof(VerifiedProof proof) {
    final evidence = proof.claims
        .expand((claim) => claim.evidence)
        .map(
          (item) => VerifiedProofEvidenceViewModel(
            sourceEntryId: item.sourceEntryId,
            quote: UserContentSafety.safeSnippet(item.quote, maxChars: 180),
            sourceDate: item.sourceDate,
            role: item.role,
          ),
        )
        .toList();
    return VerifiedProofViewModel(
      proofId: proof.proofId,
      observation: proof.reflection.concreteObservation,
      evidence: List.unmodifiable(evidence),
      confidenceLabel: switch (proof.confidenceBand) {
        ProofConfidenceBand.low => 'Low',
        ProofConfidenceBand.medium => 'Medium',
        ProofConfidenceBand.high => 'High',
      },
      repeatFrequency: proof.qualityReceipt.repeatFrequency,
      trendLabel: proof.qualityReceipt.trend,
      counterexampleCount: proof.qualityReceipt.counterexamples,
      contradictionCount: proof.qualityReceipt.contradictions,
      firstOccurrence: proof.qualityReceipt.firstOccurrence,
      lastOccurrence: proof.qualityReceipt.lastOccurrence,
    );
  }
}

class VerifiedProofEvidenceViewModel {
  const VerifiedProofEvidenceViewModel({
    required this.sourceEntryId,
    required this.quote,
    required this.sourceDate,
    required this.role,
  });

  final String sourceEntryId;
  final String quote;
  final DateTime sourceDate;
  final ProofEvidenceRole role;
}
