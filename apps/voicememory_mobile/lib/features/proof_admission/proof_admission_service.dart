import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/reflection.dart';
import 'evidence_verifier.dart';
import 'proof_admission_cache.dart';
import 'proof_admission_models.dart';
import 'proof_candidate.dart';
import 'proof_candidate_scorer.dart';
import 'proof_fingerprints.dart';

/// Everything the correction memory needs to judge one candidate proof.
class ProofCorrectionQuery {
  const ProofCorrectionQuery({
    required this.archiveScope,
    required this.proofFingerprint,
    required this.semanticFramingFingerprint,
    required this.wordingFingerprint,
    required this.evidenceSourceIds,
  });

  final String archiveScope;
  final String proofFingerprint;
  final String semanticFramingFingerprint;
  final String wordingFingerprint;

  /// Distinct verified sources behind the candidate. Used to decide whether
  /// materially new evidence has appeared since a rejection.
  final Set<String> evidenceSourceIds;
}

/// How correction memory changes the admission of one candidate.
class ProofCorrectionDecision {
  const ProofCorrectionDecision({
    this.suppressed = false,
    this.suppressionReason,
    this.disallowedEvidenceSourceIds = const {},
    this.confidenceCap,
    this.preferredWording,
  });

  static const ProofCorrectionDecision none = ProofCorrectionDecision();

  final bool suppressed;
  final String? suppressionReason;

  /// Citations the user marked as wrong evidence. They are removed before the
  /// claim thresholds are re-checked, so a proof that only held together
  /// because of disputed evidence stops being admissible.
  final Set<String> disallowedEvidenceSourceIds;

  /// Set by "Partly right": the relationship may fit, but it cannot present as
  /// settled until materially stronger evidence appears.
  final ProofConfidenceBand? confidenceCap;

  /// A label the user supplied through "Wrong wording". It renames the proof
  /// and is never treated as evidence for it.
  final String? preferredWording;
}

abstract interface class ProofCorrectionAdmissionPolicy {
  ProofCorrectionDecision decide(ProofCorrectionQuery query);

  /// Correction history that may influence soft scoring.
  ///
  /// The archive scope is part of the key, not ambient state: one archive's
  /// feedback must never move the confidence of a proof in another.
  int positiveHistory(
    String semanticFramingFingerprint, {
    String? archiveScope,
  });
  int negativeHistory(
    String semanticFramingFingerprint, {
    String? archiveScope,
  });
  int wordingRejectionHistory(
    String wordingFingerprint, {
    String? archiveScope,
  });
  int evidenceRejectionHistory(String proofFingerprint, {String? archiveScope});
}

class NoProofCorrectionAdmissionPolicy
    implements ProofCorrectionAdmissionPolicy {
  const NoProofCorrectionAdmissionPolicy();

  @override
  ProofCorrectionDecision decide(ProofCorrectionQuery query) =>
      ProofCorrectionDecision.none;

  @override
  int evidenceRejectionHistory(
    String proofFingerprint, {
    String? archiveScope,
  }) => 0;

  @override
  int negativeHistory(
    String semanticFramingFingerprint, {
    String? archiveScope,
  }) => 0;

  @override
  int positiveHistory(
    String semanticFramingFingerprint, {
    String? archiveScope,
  }) => 0;

  @override
  int wordingRejectionHistory(
    String wordingFingerprint, {
    String? archiveScope,
  }) => 0;
}

class CanonicalProofAdmissionService {
  CanonicalProofAdmissionService({
    CanonicalEvidenceVerifier evidenceVerifier =
        const CanonicalEvidenceVerifier(),
    ProofCorrectionAdmissionPolicy correctionPolicy =
        const NoProofCorrectionAdmissionPolicy(),
    DateTime Function()? clock,
    ProofCandidateScorer? scorer,
    ProofQualityCalculator qualityCalculator = const ProofQualityCalculator(),
    ProofAdmissionCache? cache,
    // Private fields cannot be named initializing formals, so the analyzer's
    // suggestion does not apply here.
    // ignore: prefer_initializing_formals
  }) : _evidenceVerifier = evidenceVerifier,
       // ignore: prefer_initializing_formals
       _correctionPolicy = correctionPolicy,
       _clock = clock ?? DateTime.now,
       _scorer = scorer ?? ProofCandidateScorer(),
       // ignore: prefer_initializing_formals
       _qualityCalculator = qualityCalculator,
       _cache = cache ?? ProofAdmissionCache();

  final CanonicalEvidenceVerifier _evidenceVerifier;
  final ProofCorrectionAdmissionPolicy _correctionPolicy;
  final DateTime Function() _clock;
  final ProofCandidateScorer _scorer;
  final ProofQualityCalculator _qualityCalculator;
  final ProofAdmissionCache _cache;

  ProofAdmissionResult admit({
    required RawModelResponse raw,
    required List<ProofSourceEntry> sourceEntries,
    required String activeArchiveScope,
    required String activeOwnerScope,
    required String primarySourceEntryId,
  }) {
    final parsed = _parse(
      raw,
      primarySourceEntryId: primarySourceEntryId,
      sources: sourceEntries,
    );
    if (!parsed.valid) {
      return ProofNotAdmitted(
        ProofAdmissionOutcome.invalidStructure,
        reason: parsed.reason ?? 'invalid_structure',
      );
    }
    final candidate = parsed.candidate!;
    final sources = {
      for (final source in sourceEntries) source.entryId: source,
    };
    final now = _clock().toUtc();
    final admittedClaims = <VerifiedProofClaim>[];
    final missingEvidence = <ProofClaimKind>[];

    for (final claim in candidate.claims) {
      // Causal language is never admissible under the product contract, so it is
      // dropped as an unsupported claim before any evidence work is attempted.
      if (claim.kind == ProofClaimKind.causalRelationship) {
        missingEvidence.add(claim.kind);
        continue;
      }
      final verification = _evidenceVerifier.verify(
        citations: claim.citations,
        sources: sources,
        activeArchiveScope: activeArchiveScope,
        activeOwnerScope: activeOwnerScope,
        now: now,
      );
      if (!verification.valid) {
        if (claim.kind == ProofClaimKind.mainObservation) {
          return ProofNotAdmitted(
            verification.outcome ?? ProofAdmissionOutcome.invalidEvidence,
            reason: verification.reason ?? 'invalid_evidence',
          );
        }
        missingEvidence.add(claim.kind);
        continue;
      }
      final semanticReason = _claimAdmissionFailure(
        claim.kind,
        verification.evidence,
      );
      if (semanticReason != null) {
        if (claim.kind == ProofClaimKind.mainObservation) {
          return ProofNotAdmitted(
            ProofAdmissionOutcome.insufficientEvidence,
            reason: semanticReason,
          );
        }
        missingEvidence.add(claim.kind);
        continue;
      }
      admittedClaims.add(
        VerifiedProofClaim(
          claimId: claim.claimId,
          kind: claim.kind,
          text: claim.text,
          evidence: verification.evidence,
        ),
      );
    }

    if (admittedClaims.isEmpty ||
        !admittedClaims.any(
          (claim) => claim.kind == ProofClaimKind.mainObservation,
        )) {
      return const ProofNotAdmitted(
        ProofAdmissionOutcome.insufficientEvidence,
        reason: 'main_observation_not_supported',
      );
    }

    final statement = admittedClaims
        .firstWhere((claim) => claim.kind == ProofClaimKind.mainObservation)
        .text;
    final semanticFingerprint = ProofFingerprints.semanticFraming(
      statement: statement,
      proofType: _provisionalProofType(admittedClaims).name,
    );
    final wordingFingerprint = ProofFingerprints.wording(statement);
    final decision = _correctionPolicy.decide(
      ProofCorrectionQuery(
        archiveScope: activeArchiveScope,
        proofFingerprint: _evidenceFingerprint(
          candidate.candidateId,
          admittedClaims,
        ),
        semanticFramingFingerprint: semanticFingerprint,
        wordingFingerprint: wordingFingerprint,
        evidenceSourceIds: admittedClaims
            .expand((claim) => claim.evidence)
            .map((item) => item.sourceEntryId)
            .toSet(),
      ),
    );
    if (decision.suppressed) {
      return ProofNotAdmitted(
        ProofAdmissionOutcome.correctionSuppressed,
        reason: decision.suppressionReason ?? 'correction_policy_suppressed',
      );
    }

    // Evidence the user disputed is removed and the claim thresholds are then
    // re-checked, so a proof that only held together because of that evidence
    // stops being admissible rather than quietly shrinking.
    if (decision.disallowedEvidenceSourceIds.isNotEmpty) {
      final revalidated = _withoutDisallowedEvidence(
        admittedClaims,
        decision.disallowedEvidenceSourceIds,
        missingEvidence,
      );
      if (revalidated == null) {
        return const ProofNotAdmitted(
          ProofAdmissionOutcome.insufficientEvidence,
          reason: 'remaining_evidence_insufficient_after_correction',
        );
      }
      admittedClaims
        ..clear()
        ..addAll(revalidated);
    }

    final allEvidence = admittedClaims
        .expand((claim) => claim.evidence)
        .toList();
    final supports = allEvidence
        .where((item) => item.role == ProofEvidenceRole.support)
        .length;
    final contradictions = allEvidence
        .where((item) => item.role == ProofEvidenceRole.contradiction)
        .length;
    if (contradictions > supports) {
      return const ProofNotAdmitted(
        ProofAdmissionOutcome.contradictionTooStrong,
        reason: 'contradiction_pressure_exceeds_support',
      );
    }

    final proofFingerprint = _evidenceFingerprint(
      candidate.candidateId,
      admittedClaims,
    );
    final distinctSources = allEvidence
        .map((item) => item.sourceEntryId)
        .toSet()
        .length;
    final positiveHistory = _correctionPolicy.positiveHistory(
      semanticFingerprint,
      archiveScope: activeArchiveScope,
    );
    final negativeHistory = _correctionPolicy.negativeHistory(
      semanticFingerprint,
      archiveScope: activeArchiveScope,
    );
    final wordingRejectionHistory = _correctionPolicy.wordingRejectionHistory(
      wordingFingerprint,
      archiveScope: activeArchiveScope,
    );
    final evidenceRejectionHistory = _correctionPolicy.evidenceRejectionHistory(
      proofFingerprint,
      archiveScope: activeArchiveScope,
    );
    final confidence = _confidence(
      candidateId: candidate.candidateId,
      evidence: allEvidence,
      distinctSources: distinctSources,
      supportCount: supports,
      contradictionCount: contradictions,
      positiveHistory: positiveHistory,
      negativeHistory: negativeHistory,
      wordingRejectionHistory: wordingRejectionHistory,
      evidenceRejectionHistory: evidenceRejectionHistory,
      modelConfidence: candidate.modelConfidence,
      deterministicFallback: candidate.deterministicFallback,
    );
    if (confidence == ProofConfidenceBand.low) {
      return const ProofNotAdmitted(
        ProofAdmissionOutcome.suppressed,
        reason: 'confidence_below_surface_threshold',
      );
    }
    final cappedConfidence = _cap(confidence, decision.confidenceCap);

    allEvidence.sort((a, b) => a.sourceDate.compareTo(b.sourceDate));
    final admittedKinds = admittedClaims.map((claim) => claim.kind).toSet();
    final verifiedReflection = Reflection(
      mood: candidate.reflection.mood,
      emotionalIntensity: candidate.reflection.emotionalIntensity,
      recurringThemes: candidate.reflection.recurringThemes,
      exactLanguagePattern: candidate.reflection.exactLanguagePattern,
      concreteObservation: candidate.reflection.concreteObservation,
      repeatedSignal: admittedKinds.contains(ProofClaimKind.repeated)
          ? candidate.reflection.repeatedSignal
          : '',
      tensionOrContradiction: contradictions > 0
          ? candidate.reflection.tensionOrContradiction
          : null,
      avoidedOrVagueArea: null,
      nextSmallAction: admittedKinds.contains(ProofClaimKind.nextAction)
          ? candidate.reflection.nextSmallAction
          : null,
      patternObservations: const [],
    );
    final proof = VerifiedProof(
      proofId: 'proof-${proofFingerprint.substring(0, 24)}',
      archiveScope: activeArchiveScope,
      ownerScope: activeOwnerScope,
      reflection: verifiedReflection,
      claims: List.unmodifiable(admittedClaims),
      confidenceBand: cappedConfidence,
      qualityReceipt: _qualityCalculator
          .build(
            claims: admittedClaims,
            confidenceBand: cappedConfidence,
            unsupportedClaims: missingEvidence.toSet(),
            now: now,
          )
          .withUserConfirmedWording(decision.preferredWording),
      verifiedAt: now,
      sourceRevisionFingerprint: _fingerprint(
        allEvidence
            .map(
              (item) =>
                  '${item.sourceEntryId}:${item.transcriptRevision}:${item.transcriptFingerprint}',
            )
            .join('|'),
      ),
      proofFingerprint: proofFingerprint,
      semanticFramingFingerprint: semanticFingerprint,
      wordingFingerprint: wordingFingerprint,
    );
    return ProofAdmitted(proof);
  }

  ProofAdmissionResult revalidateForDisplay({
    required VerifiedProof proof,
    required List<ProofSourceEntry> currentSources,
    required String activeArchiveScope,
    required String activeOwnerScope,
  }) {
    if (proof.archiveScope != activeArchiveScope ||
        proof.ownerScope != activeOwnerScope) {
      return const ProofNotAdmitted(
        ProofAdmissionOutcome.wrongArchive,
        reason: 'proof_scope_changed',
      );
    }
    final sources = {
      for (final source in currentSources) source.entryId: source,
    };
    for (final evidence in proof.claims.expand((claim) => claim.evidence)) {
      final source = sources[evidence.sourceEntryId];
      if (source == null || source.deleted) {
        return const ProofNotAdmitted(
          ProofAdmissionOutcome.sourceUnavailable,
          reason: 'proof_source_unavailable',
        );
      }
      if (source.archived ||
          !source.allowedByArchivePolicy ||
          source.archiveScope != activeArchiveScope ||
          source.ownerScope != activeOwnerScope) {
        return const ProofNotAdmitted(
          ProofAdmissionOutcome.wrongArchive,
          reason: 'proof_source_scope_changed',
        );
      }
      // Cached because this recomputes a hash of the whole transcript for every
      // citation, on every rebuild of the surface showing the proof. The cache
      // compares the transcript itself before reusing a fingerprint, so an edit
      // still reads as stale.
      if (source.transcriptRevision != evidence.transcriptRevision ||
          _cache.revisionFor(source).transcriptFingerprint !=
              evidence.transcriptFingerprint) {
        return const ProofNotAdmitted(
          ProofAdmissionOutcome.stale,
          reason: 'proof_source_revision_changed',
        );
      }
      if (source.transcript.substring(evidence.startUtf16, evidence.endUtf16) !=
          evidence.quote) {
        return const ProofNotAdmitted(
          ProofAdmissionOutcome.stale,
          reason: 'proof_quote_changed',
        );
      }
    }
    return ProofAdmitted(proof);
  }

  StructuralValidationResult _parse(
    RawModelResponse raw, {
    required String primarySourceEntryId,
    required List<ProofSourceEntry> sources,
  }) {
    final reflectionJson = raw.payload['reflection'];
    if (reflectionJson is! Map) {
      return StructuralValidationResult.invalid('reflection_missing');
    }
    final reflectionMap = Map<String, dynamic>.from(reflectionJson);
    final reflection = Reflection.fromJson(reflectionMap);
    final source = sources
        .where((item) => item.entryId == primarySourceEntryId)
        .firstOrNull;
    if (source == null) {
      return StructuralValidationResult.invalid('primary_source_missing');
    }
    final claims = <ParsedProofClaim>[];
    final rawClaims = reflectionMap['claims'] ?? raw.payload['claims'];
    if (rawClaims is List) {
      for (var index = 0; index < rawClaims.length; index++) {
        final rawClaim = rawClaims[index];
        if (rawClaim is! Map) {
          return StructuralValidationResult.invalid('claim_not_object');
        }
        final claim = _parseClaim(Map<String, dynamic>.from(rawClaim), index);
        if (claim == null) {
          return StructuralValidationResult.invalid('claim_invalid');
        }
        claims.add(claim);
      }
    } else {
      final quote = reflection.exactLanguagePattern.trim();
      final observation = reflection.concreteObservation.trim();
      if (quote.isEmpty || observation.isEmpty) {
        return StructuralValidationResult.invalid(
          'legacy_response_missing_exact_evidence',
        );
      }
      claims.add(
        ParsedProofClaim(
          claimId: 'main',
          kind: ProofClaimKind.mainObservation,
          text: observation,
          citations: [
            EvidenceCitationDraft(
              sourceEntryId: source.entryId,
              quote: quote,
              role: ProofEvidenceRole.support,
              sourceRevision: source.transcriptRevision,
            ),
          ],
        ),
      );
    }
    final ids = claims.map((claim) => claim.claimId).toSet();
    if (claims.isEmpty ||
        ids.length != claims.length ||
        claims.any(
          (claim) =>
              claim.text.trim().isEmpty ||
              claim.text.length > 2000 ||
              claim.citations.isEmpty,
        )) {
      return StructuralValidationResult.invalid('claim_structure_invalid');
    }
    final candidateId = raw.providerResponseId?.trim().isNotEmpty == true
        ? raw.providerResponseId!.trim()
        : _fingerprint(jsonEncode(reflectionMap)).substring(0, 24);
    return StructuralValidationResult.valid(
      ParsedConclusionCandidate(
        candidateId: candidateId,
        reflection: reflection,
        claims: List.unmodifiable(claims),
        generatedAt: raw.receivedAt.toUtc(),
        modelConfidence: (reflectionMap['confidence'] as num?)?.toDouble(),
        deterministicFallback: reflectionMap['deterministicFallback'] == true,
      ),
    );
  }

  ParsedProofClaim? _parseClaim(Map<String, dynamic> json, int index) {
    final kind = _claimKind(json['kind'] as String?);
    final text = json['text'] as String?;
    final citationsRaw = json['citations'];
    if (kind == null || text == null || citationsRaw is! List) return null;
    final citations = <EvidenceCitationDraft>[];
    for (final rawCitation in citationsRaw) {
      if (rawCitation is! Map) return null;
      final citation = Map<String, dynamic>.from(rawCitation);
      final sourceEntryId = citation['sourceEntryId'];
      final quote = citation['quote'];
      final role = _evidenceRole(citation['role'] as String?);
      if (sourceEntryId is! String || quote is! String || role == null) {
        return null;
      }
      citations.add(
        EvidenceCitationDraft(
          sourceEntryId: sourceEntryId,
          quote: quote,
          role: role,
          startUtf16: (citation['startUtf16'] as num?)?.toInt(),
          endUtf16: (citation['endUtf16'] as num?)?.toInt(),
          sourceRevision: citation['sourceRevision'] as String?,
        ),
      );
    }
    return ParsedProofClaim(
      claimId: json['id'] as String? ?? 'claim-$index',
      kind: kind,
      text: text,
      citations: citations,
    );
  }

  /// The proof type as it looks before correction memory runs. It only feeds the
  /// framing fingerprint, so a rejected observation and a rejected repeat about
  /// the same subject stay distinguishable.
  ProofType _provisionalProofType(List<VerifiedProofClaim> claims) {
    final kinds = claims.map((claim) => claim.kind).toSet();
    if (kinds.contains(ProofClaimKind.directionOfChange)) {
      return ProofType.change;
    }
    if (kinds.contains(ProofClaimKind.repeated)) {
      return ProofType.repeatedSignal;
    }
    return ProofType.currentObservation;
  }

  String _evidenceFingerprint(
    String candidateId,
    List<VerifiedProofClaim> claims,
  ) {
    final citations =
        claims
            .expand((claim) => claim.evidence)
            .map(
              (item) =>
                  '${item.sourceEntryId}:${item.transcriptRevision}:${item.startUtf16}:${item.endUtf16}',
            )
            .toList()
          ..sort();
    return _fingerprint('$candidateId|${citations.join('|')}');
  }

  /// Returns null when the remaining evidence no longer supports the proof.
  List<VerifiedProofClaim>? _withoutDisallowedEvidence(
    List<VerifiedProofClaim> claims,
    Set<String> disallowed,
    List<ProofClaimKind> unsupported,
  ) {
    final kept = <VerifiedProofClaim>[];
    for (final claim in claims) {
      final evidence = claim.evidence
          .where((item) => !disallowed.contains(item.sourceEntryId))
          .toList();
      final failure = evidence.isEmpty
          ? 'no_remaining_evidence'
          : _claimAdmissionFailure(claim.kind, evidence);
      if (failure != null) {
        if (claim.kind == ProofClaimKind.mainObservation) return null;
        unsupported.add(claim.kind);
        continue;
      }
      kept.add(
        VerifiedProofClaim(
          claimId: claim.claimId,
          kind: claim.kind,
          text: claim.text,
          evidence: evidence,
        ),
      );
    }
    return kept.any((claim) => claim.kind == ProofClaimKind.mainObservation)
        ? kept
        : null;
  }

  static ProofConfidenceBand _cap(
    ProofConfidenceBand band,
    ProofConfidenceBand? cap,
  ) => cap == null || band.index <= cap.index ? band : cap;

  String? _claimAdmissionFailure(
    ProofClaimKind kind,
    List<VerifiedEvidenceSnapshot> evidence,
  ) {
    final supports = evidence
        .where((item) => item.role == ProofEvidenceRole.support)
        .toList();
    final distinctSources = supports.map((item) => item.sourceEntryId).toSet();
    final distinctQuotes = supports.map((item) => item.quote).toSet();
    final minimum = switch (kind) {
      ProofClaimKind.mainObservation || ProofClaimKind.nextAction => 1,
      ProofClaimKind.repeated || ProofClaimKind.directionOfChange => 2,
      ProofClaimKind.frequency || ProofClaimKind.trend => 3,
      ProofClaimKind.strength => 4,
      ProofClaimKind.causalRelationship => 999,
    };
    if (distinctSources.length < minimum) return '${kind.name}_source_minimum';
    if (kind == ProofClaimKind.directionOfChange) {
      if (distinctQuotes.length < 2) return 'change_quotes_not_distinct';
      final dates = supports.map((item) => item.sourceDate).toList()..sort();
      if (!dates.first.isBefore(dates.last)) return 'then_must_precede_now';
    }
    return null;
  }

  ProofConfidenceBand _confidence({
    required String candidateId,
    required List<VerifiedEvidenceSnapshot> evidence,
    required int distinctSources,
    required int supportCount,
    required int contradictionCount,
    required int positiveHistory,
    required int negativeHistory,
    required int wordingRejectionHistory,
    required int evidenceRejectionHistory,
    required double? modelConfidence,
    required bool deterministicFallback,
  }) {
    final latest = evidence
        .map((item) => item.sourceDate)
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final daysOld = _clock().toUtc().difference(latest).inDays.clamp(0, 365);
    final sourceTypeCount = evidence
        .map((item) => item.sourceType)
        .toSet()
        .length;
    final correctionCount = positiveHistory + negativeHistory;
    final score = _scorer.score(
      ProofCandidate(
        stableId: candidateId,
        isValid: true,
        hardSafetyPassed: true,
        features: ProofFeatureVector(
          coverage: 1,
          specificity: evidence
              .map((item) => item.quote.length.clamp(0, 160) / 160)
              .fold<double>(0, (sum, value) => sum + value)
              .clamp(0, 1),
          citationCount: evidence.length,
          sourceCount: distinctSources,
          chronology: distinctSources > 1 ? 1 : 0,
          sourceDiversity: (sourceTypeCount / distinctSources.clamp(1, 999))
              .clamp(0, 1),
          citationSourceRatio: (distinctSources / evidence.length.clamp(1, 999))
              .clamp(0, 1),
          corroborationRatio: (supportCount / evidence.length.clamp(1, 999))
              .clamp(0, 1),
          contradiction: (contradictionCount / evidence.length.clamp(1, 999))
              .clamp(0, 1),
          recency: (1 - (daysOld / 365)).clamp(0, 1),
          freshness: daysOld <= 30 ? 1 : 0.5,
          transcriptSpecificity: evidence
              .map((item) => item.quote.split(RegExp(r'\s+')).length / 24)
              .fold<double>(0, (sum, value) => sum + value)
              .clamp(0, 1),
          userConfirmed: positiveHistory > 0,
          correctionHistoryCount: correctionCount,
          acceptedCorrectionRatio: correctionCount == 0
              ? 0
              : positiveHistory / correctionCount,
          positiveCorrectionHistory: positiveHistory,
          negativeCorrectionHistory: negativeHistory,
          wordingRejectionHistory: wordingRejectionHistory,
          evidenceRejectionHistory: evidenceRejectionHistory,
          oneEntryPenalty: distinctSources == 1,
          stalePenalty: false,
          modelConfidence: modelConfidence ?? 0,
          deterministicFallback: deterministicFallback ? 1 : 0,
        ),
      ),
    );
    if (score >= 10) return ProofConfidenceBand.high;
    if (score >= 2) return ProofConfidenceBand.medium;
    return ProofConfidenceBand.low;
  }

  ProofClaimKind? _claimKind(String? raw) => switch (raw) {
    'main_observation' => ProofClaimKind.mainObservation,
    'repeated' => ProofClaimKind.repeated,
    'direction_of_change' => ProofClaimKind.directionOfChange,
    'frequency' => ProofClaimKind.frequency,
    'trend' => ProofClaimKind.trend,
    'strength' => ProofClaimKind.strength,
    'causal_relationship' => ProofClaimKind.causalRelationship,
    'next_action' => ProofClaimKind.nextAction,
    _ => null,
  };

  ProofEvidenceRole? _evidenceRole(String? raw) => switch (raw) {
    'support' => ProofEvidenceRole.support,
    'counterexample' => ProofEvidenceRole.counterexample,
    'contradiction' => ProofEvidenceRole.contradiction,
    'context' => ProofEvidenceRole.context,
    _ => null,
  };

  String _fingerprint(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
