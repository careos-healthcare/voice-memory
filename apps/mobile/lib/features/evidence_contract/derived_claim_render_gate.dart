import 'package:archiveme_mobile/features/evidence_contract/derived_claim.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';

/// Ensures generated text never renders as a claim without valid evidence refs.
abstract final class DerivedClaimRenderGate {
  DerivedClaimRenderGate._();

  static DerivedClaim? renderableClaim(DerivedClaim? claim) {
    if (claim == null) return null;
    if (claim.isHiddenFromUser) return null;
    if (!claim.hasRenderableEvidence) return null;
    if (claim.displayText.trim().isEmpty) return null;
    return claim;
  }

  static VerifiedProofClaim? renderableProofClaim(VerifiedProofClaim? claim) {
    if (claim == null) return null;
    if (claim.text.trim().isEmpty) return null;
    if (claim.evidence.isEmpty) return null;
    return claim;
  }

  static VerifiedProof? renderableProof(VerifiedProof? proof) {
    if (proof == null) return null;
    final claims = proof.claims
        .map(renderableProofClaim)
        .whereType<VerifiedProofClaim>()
        .toList();
    if (claims.isEmpty) return null;
    if (!claims.any((claim) => claim.kind == ProofClaimKind.mainObservation)) {
      return null;
    }
    return VerifiedProof(
      proofId: proof.proofId,
      archiveScope: proof.archiveScope,
      ownerScope: proof.ownerScope,
      reflection: proof.reflection,
      claims: claims,
      confidenceBand: proof.confidenceBand,
      qualityReceipt: proof.qualityReceipt,
      verifiedAt: proof.verifiedAt,
      sourceRevisionFingerprint: proof.sourceRevisionFingerprint,
      proofFingerprint: proof.proofFingerprint,
      semanticFramingFingerprint: proof.semanticFramingFingerprint,
      wordingFingerprint: proof.wordingFingerprint,
      schemaVersion: proof.schemaVersion,
    );
  }

  static DerivedClaim recomputeAfterEvidenceChange(DerivedClaim claim) {
    final available = claim.availableEvidenceRefs;
    if (available.isEmpty) {
      return DerivedClaim(
        claimId: claim.claimId,
        kind: claim.kind,
        displayText: claim.displayText,
        evidenceRefs: claim.evidenceRefs,
        evidenceRangeStart: claim.evidenceRangeStart,
        evidenceRangeEnd: claim.evidenceRangeEnd,
        generation: claim.generation,
        eligibilityReason: 'missing_evidence',
        eligibilityPolicyVersion: claim.eligibilityPolicyVersion,
        userStatus: claim.userStatus,
        encryptedUserCorrection: claim.encryptedUserCorrection,
        createdAt: claim.createdAt,
        updatedAt: claim.updatedAt,
      );
    }
    final dates = available.map((ref) => ref.sourceDate).toList()..sort();
    return DerivedClaim(
      claimId: claim.claimId,
      kind: claim.kind,
      displayText: claim.displayText,
      evidenceRefs: available,
      evidenceRangeStart: dates.first,
      evidenceRangeEnd: dates.last,
      generation: claim.generation,
      eligibilityReason: claim.eligibilityReason,
      eligibilityPolicyVersion: claim.eligibilityPolicyVersion,
      userStatus: claim.userStatus,
      encryptedUserCorrection: claim.encryptedUserCorrection,
      createdAt: claim.createdAt,
      updatedAt: claim.updatedAt,
    );
  }

  static EvidenceEligibilityOutcome eligibilityForClaim(DerivedClaim claim) =>
      switch (claim.kind) {
        DerivedClaimKind.savedContent => EvidenceEligibilityPolicy
            .evaluateSavedContentOnly(
          EvidenceEligibilityPolicy.admittedMomentCount(claim.evidenceRefs),
        ),
        DerivedClaimKind.relatedMoments =>
          EvidenceEligibilityPolicy.evaluateRelatedMoments(
            evidenceRefs: claim.evidenceRefs,
            bothEvidenceVisible:
                claim.availableEvidenceRefs.length >=
                EvidenceEligibilityPolicy.relatedMomentsMinimum,
          ),
        DerivedClaimKind.possiblePattern =>
          EvidenceEligibilityPolicy.evaluatePossiblePattern(
            evidenceRefs: claim.evidenceRefs,
          ),
        DerivedClaimKind.change => EvidenceEligibilityPolicy.evaluateChange(
          evidenceRefs: claim.evidenceRefs,
          hasExplicitComparison: claim.availableEvidenceRefs.length >= 2,
        ),
      };
}
