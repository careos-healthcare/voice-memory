import 'package:archiveme_mobile/features/evidence_contract/derived_claim.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_copy.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';

/// Maps admitted proof artifacts into auditable derived claims.
abstract final class DerivedClaimMapper {
  DerivedClaimMapper._();

  static DerivedClaim fromVerifiedProofClaim({
    required VerifiedProofClaim claim,
    required VerifiedProof proof,
    required DateTime createdAt,
    DerivedClaimUserStatus userStatus = DerivedClaimUserStatus.unreviewed,
    String? encryptedUserCorrection,
  }) {
    final refs = claim.evidence
        .map(DerivedClaimEvidenceRef.fromVerifiedSnapshot)
        .toList();
    final dates = refs.map((ref) => ref.sourceDate).toList()..sort();
    final derivedKind =
        EvidenceEligibilityPolicy.claimKindForProofClaim(claim.kind) ??
        DerivedClaimKind.savedContent;

    return DerivedClaim(
      claimId: claim.claimId.isNotEmpty ? claim.claimId : proof.proofId,
      kind: derivedKind,
      displayText: claim.text,
      evidenceRefs: refs,
      evidenceRangeStart: dates.isEmpty ? null : dates.first,
      evidenceRangeEnd: dates.isEmpty ? null : dates.last,
      generation: DerivedClaimGenerationMeta(
        method: 'proof_admission_v${proof.schemaVersion}',
        promptPolicyVersion:
            'evidence_eligibility_v${EvidenceEligibilityPolicy.policyVersion}',
        providerResponseId: null,
      ),
      eligibilityReason: _eligibilityReasonForClaim(claim.kind, refs),
      eligibilityPolicyVersion: EvidenceEligibilityPolicy.policyVersion,
      userStatus: userStatus,
      encryptedUserCorrection: encryptedUserCorrection,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  static String _eligibilityReasonForClaim(
    ProofClaimKind kind,
    List<DerivedClaimEvidenceRef> refs,
  ) {
    final derivedKind = EvidenceEligibilityPolicy.claimKindForProofClaim(kind);
    if (derivedKind == null) return 'saved_content_only';
    final outcome = switch (derivedKind) {
      DerivedClaimKind.relatedMoments =>
        EvidenceEligibilityPolicy.evaluateRelatedMoments(
          evidenceRefs: refs,
          bothEvidenceVisible: refs.length >= 2,
        ),
      DerivedClaimKind.possiblePattern =>
        EvidenceEligibilityPolicy.evaluatePossiblePattern(
          evidenceRefs: refs,
        ),
      DerivedClaimKind.change => EvidenceEligibilityPolicy.evaluateChange(
        evidenceRefs: refs,
        hasExplicitComparison: refs.length >= 2,
      ),
      DerivedClaimKind.savedContent => EvidenceEligibilityPolicy
          .evaluateSavedContentOnly(
        EvidenceEligibilityPolicy.admittedMomentCount(refs),
      ),
    };
    return outcome.name;
  }

  static Map<String, Object> exportSectionFor(DerivedClaim claim) => {
    EvidenceEligibilityCopy.exportSuggestionLabel: claim.displayText,
    EvidenceEligibilityCopy.exportReviewStatusLabel: claim.userStatus.name,
    EvidenceEligibilityCopy.exportYourWordsLabel: claim.availableEvidenceRefs
        .map((ref) => ref.quote)
        .toList(),
    'claimId': claim.claimId,
    'kind': claim.kind.name,
    'eligibilityReason': claim.eligibilityReason,
    'policyVersion': claim.eligibilityPolicyVersion,
  };
}
