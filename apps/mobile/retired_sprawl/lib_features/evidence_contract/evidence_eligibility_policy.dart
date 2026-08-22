import 'package:archiveme_mobile/features/evidence_contract/derived_claim.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy_config.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';

/// Outcome of evaluating one surface or claim kind against the contract.
enum EvidenceEligibilityOutcome {
  allowed,
  savedContentOnly,
  insufficientMoments,
  insufficientTimeSeparation,
  missingEvidence,
  hiddenEvidence,
  userSuppressed,
  unsupportedClaimKind,
  noExplicitComparison,
}

/// Typed, versioned evidence contract used by generation, UI, export, and tests.
abstract final class EvidenceEligibilityPolicy {
  EvidenceEligibilityPolicy._();

  static int get policyVersion => EvidenceEligibilityPolicyConfig.policyVersion;

  static int get relatedMomentsMinimum =>
      EvidenceEligibilityPolicyConfig.relatedMomentsMinimum;

  static int get possiblePatternMinimum =>
      EvidenceEligibilityPolicyConfig.possiblePatternMinimum;

  static int get changesSurfaceMinimum =>
      EvidenceEligibilityPolicyConfig.changesSurfaceMinimum;

  static Duration get minimumPatternTimeSeparation =>
      EvidenceEligibilityPolicyConfig.minimumPatternTimeSeparation;

  static Duration get minimumChangeTimeSeparation =>
      EvidenceEligibilityPolicyConfig.minimumChangeTimeSeparation;

  /// Admitted, available moments only — deleted/hidden entries are excluded.
  static List<DerivedClaimEvidenceRef> admittedEvidenceRefs(
    Iterable<DerivedClaimEvidenceRef> refs,
  ) => refs.where((ref) => ref.isAvailable).toList(growable: false);

  static int admittedMomentCount(Iterable<DerivedClaimEvidenceRef> refs) =>
      admittedEvidenceRefs(refs).map((ref) => ref.entryId).toSet().length;

  static bool hasMinimumTimeSeparation(
    Iterable<DateTime> dates, {
    required Duration minimum,
  }) {
    final sorted = dates.toList()..sort();
    if (sorted.length < 2) return false;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]) >= minimum) return true;
    }
    return false;
  }

  static EvidenceEligibilityOutcome evaluateSavedContentOnly(int momentCount) =>
      momentCount <= 1
      ? EvidenceEligibilityOutcome.savedContentOnly
      : EvidenceEligibilityOutcome.allowed;

  static EvidenceEligibilityOutcome evaluateRelatedMoments({
    required Iterable<DerivedClaimEvidenceRef> evidenceRefs,
    required bool bothEvidenceVisible,
  }) {
    final admitted = admittedEvidenceRefs(evidenceRefs);
    if (admittedMomentCount(admitted) < relatedMomentsMinimum) {
      return EvidenceEligibilityOutcome.insufficientMoments;
    }
    if (!bothEvidenceVisible || admitted.length < relatedMomentsMinimum) {
      return EvidenceEligibilityOutcome.missingEvidence;
    }
    return EvidenceEligibilityOutcome.allowed;
  }

  static EvidenceEligibilityOutcome evaluatePossiblePattern({
    required Iterable<DerivedClaimEvidenceRef> evidenceRefs,
  }) {
    final admitted = admittedEvidenceRefs(evidenceRefs);
    if (admittedMomentCount(admitted) < possiblePatternMinimum) {
      return EvidenceEligibilityOutcome.insufficientMoments;
    }
    final dates = admitted.map((ref) => ref.sourceDate);
    if (!hasMinimumTimeSeparation(
      dates,
      minimum: minimumPatternTimeSeparation,
    )) {
      return EvidenceEligibilityOutcome.insufficientTimeSeparation;
    }
    return EvidenceEligibilityOutcome.allowed;
  }

  static EvidenceEligibilityOutcome evaluateChange({
    required Iterable<DerivedClaimEvidenceRef> evidenceRefs,
    required bool hasExplicitComparison,
    VerifiedEvidenceSnapshot? thenEvidence,
    VerifiedEvidenceSnapshot? nowEvidence,
  }) {
    final admitted = admittedEvidenceRefs(evidenceRefs);
    if (admittedMomentCount(admitted) < 2) {
      return EvidenceEligibilityOutcome.insufficientMoments;
    }
    if (!hasExplicitComparison || thenEvidence == null || nowEvidence == null) {
      return EvidenceEligibilityOutcome.noExplicitComparison;
    }
    if (!thenEvidence.sourceDate.isBefore(nowEvidence.sourceDate)) {
      return EvidenceEligibilityOutcome.noExplicitComparison;
    }
    final separation = nowEvidence.sourceDate.difference(
      thenEvidence.sourceDate,
    );
    if (separation < minimumChangeTimeSeparation) {
      return EvidenceEligibilityOutcome.insufficientTimeSeparation;
    }
    return EvidenceEligibilityOutcome.allowed;
  }

  static EvidenceEligibilityOutcome evaluateChangesSurface({
    required int admittedMomentCount,
    required bool hasEligibleTimelineItems,
  }) {
    if (admittedMomentCount < changesSurfaceMinimum) {
      return EvidenceEligibilityOutcome.insufficientMoments;
    }
    if (!hasEligibleTimelineItems) {
      return EvidenceEligibilityOutcome.missingEvidence;
    }
    return EvidenceEligibilityOutcome.allowed;
  }

  /// Admission-time source minimums shared with proof admission.
  static int admissionSourceMinimumFor(ProofClaimKind kind) =>
      EvidenceEligibilityPolicyConfig.admissionSourceMinimums[kind.name] ??
      EvidenceEligibilityPolicyConfig.admissionSourceMinimums['mainObservation']!;

  static String? admissionFailureFor({
    required ProofClaimKind kind,
    required List<VerifiedEvidenceSnapshot> evidence,
  }) {
    final supports = evidence
        .where((item) => item.role == ProofEvidenceRole.support)
        .toList();
    final distinctSources = supports.map((item) => item.sourceEntryId).toSet();
    final minimum = admissionSourceMinimumFor(kind);
    if (distinctSources.length < minimum) {
      return '${kind.name}_source_minimum';
    }
    if (kind == ProofClaimKind.directionOfChange) {
      final distinctQuotes = supports.map((item) => item.quote).toSet();
      if (distinctQuotes.length < 2) return 'change_quotes_not_distinct';
      final dates = supports.map((item) => item.sourceDate).toList()..sort();
      if (!dates.first.isBefore(dates.last)) return 'then_must_precede_now';
      if (dates.last.difference(dates.first) < minimumChangeTimeSeparation) {
        return 'change_insufficient_time_separation';
      }
    }
    if (kind == ProofClaimKind.repeated || kind == ProofClaimKind.frequency) {
      final dates = supports.map((item) => item.sourceDate);
      if (distinctSources.length >= possiblePatternMinimum &&
          !hasMinimumTimeSeparation(
            dates,
            minimum: minimumPatternTimeSeparation,
          )) {
        return 'pattern_insufficient_time_separation';
      }
    }
    return null;
  }

  static DerivedClaimKind? claimKindForProofClaim(ProofClaimKind kind) =>
      switch (kind) {
        ProofClaimKind.mainObservation || ProofClaimKind.nextAction => null,
        ProofClaimKind.repeated => DerivedClaimKind.relatedMoments,
        ProofClaimKind.directionOfChange => DerivedClaimKind.change,
        ProofClaimKind.frequency ||
        ProofClaimKind.trend ||
        ProofClaimKind.strength => DerivedClaimKind.possiblePattern,
        ProofClaimKind.causalRelationship => null,
      };
}
