import '../../models/reflection.dart';

enum ProofClaimKind {
  mainObservation,
  repeated,
  directionOfChange,
  frequency,
  trend,
  strength,
  causalRelationship,
  nextAction,
}

enum ProofEvidenceRole { support, counterexample, contradiction, context }

enum ProofSourceType {
  userTyped,
  userVoiceTranscript,
  permittedImport,
  generatedPlaceholder,
}

enum ProofConfidenceBand { low, medium, high }

enum ProofAdmissionOutcome {
  admitted,
  suppressed,
  rejected,
  stale,
  invalidStructure,
  invalidEvidence,
  insufficientEvidence,
  contradictionTooStrong,
  correctionSuppressed,
  duplicate,
  wrongArchive,
  sourceUnavailable,
}

class RawModelResponse {
  const RawModelResponse({
    required this.payload,
    required this.receivedAt,
    this.providerResponseId,
  });

  final Map<String, dynamic> payload;
  final DateTime receivedAt;
  final String? providerResponseId;
}

class ProofSourceEntry {
  const ProofSourceEntry({
    required this.entryId,
    required this.archiveScope,
    required this.ownerScope,
    required this.transcript,
    required this.transcriptRevision,
    required this.createdAt,
    required this.sourceType,
    this.deleted = false,
    this.archived = false,
    this.allowedByArchivePolicy = true,
    this.remoteProcessingConsented = true,
  });

  final String entryId;
  final String archiveScope;
  final String ownerScope;
  final String transcript;
  final String transcriptRevision;
  final DateTime createdAt;
  final ProofSourceType sourceType;
  final bool deleted;
  final bool archived;
  final bool allowedByArchivePolicy;
  final bool remoteProcessingConsented;
}

class EvidenceCitationDraft {
  const EvidenceCitationDraft({
    required this.sourceEntryId,
    required this.quote,
    required this.role,
    this.startUtf16,
    this.endUtf16,
    this.sourceRevision,
  });

  final String sourceEntryId;
  final String quote;
  final ProofEvidenceRole role;
  final int? startUtf16;
  final int? endUtf16;
  final String? sourceRevision;
}

class ParsedProofClaim {
  const ParsedProofClaim({
    required this.claimId,
    required this.kind,
    required this.text,
    required this.citations,
  });

  final String claimId;
  final ProofClaimKind kind;
  final String text;
  final List<EvidenceCitationDraft> citations;
}

class ParsedConclusionCandidate {
  const ParsedConclusionCandidate({
    required this.candidateId,
    required this.reflection,
    required this.claims,
    required this.generatedAt,
    this.modelConfidence,
    this.deterministicFallback = false,
  });

  final String candidateId;
  final Reflection reflection;
  final List<ParsedProofClaim> claims;
  final DateTime generatedAt;
  final double? modelConfidence;
  final bool deterministicFallback;
}

class StructuralValidationResult {
  const StructuralValidationResult._({
    required this.valid,
    this.candidate,
    this.reason,
  });

  factory StructuralValidationResult.valid(
    ParsedConclusionCandidate candidate,
  ) => StructuralValidationResult._(valid: true, candidate: candidate);

  factory StructuralValidationResult.invalid(String reason) =>
      StructuralValidationResult._(valid: false, reason: reason);

  final bool valid;
  final ParsedConclusionCandidate? candidate;
  final String? reason;
}

class VerifiedEvidenceSnapshot {
  const VerifiedEvidenceSnapshot({
    required this.sourceEntryId,
    required this.archiveScope,
    required this.ownerScope,
    required this.transcriptRevision,
    required this.transcriptFingerprint,
    required this.sourceDate,
    required this.sourceType,
    required this.quote,
    required this.startUtf16,
    required this.endUtf16,
    required this.role,
    required this.verifiedAt,
    this.verifierSchemaVersion = 1,
  });

  final String sourceEntryId;
  final String archiveScope;
  final String ownerScope;
  final String transcriptRevision;
  final String transcriptFingerprint;
  final DateTime sourceDate;
  final ProofSourceType sourceType;
  final String quote;
  final int startUtf16;
  final int endUtf16;
  final ProofEvidenceRole role;
  final DateTime verifiedAt;
  final int verifierSchemaVersion;

  Map<String, dynamic> toJson() => {
    'sourceEntryId': sourceEntryId,
    'archiveScope': archiveScope,
    'ownerScope': ownerScope,
    'transcriptRevision': transcriptRevision,
    'transcriptFingerprint': transcriptFingerprint,
    'sourceDate': sourceDate.toUtc().toIso8601String(),
    'sourceType': sourceType.name,
    'quote': quote,
    'startUtf16': startUtf16,
    'endUtf16': endUtf16,
    'role': role.name,
    'verifiedAt': verifiedAt.toUtc().toIso8601String(),
    'verifierSchemaVersion': verifierSchemaVersion,
  };

  factory VerifiedEvidenceSnapshot.fromJson(Map<String, dynamic> json) =>
      VerifiedEvidenceSnapshot(
        sourceEntryId: json['sourceEntryId'] as String? ?? '',
        archiveScope: json['archiveScope'] as String? ?? '',
        ownerScope: json['ownerScope'] as String? ?? '',
        transcriptRevision: json['transcriptRevision'] as String? ?? '',
        transcriptFingerprint: json['transcriptFingerprint'] as String? ?? '',
        sourceDate: DateTime.parse(json['sourceDate'] as String),
        sourceType: ProofSourceType.values.byName(json['sourceType'] as String),
        quote: json['quote'] as String? ?? '',
        startUtf16: json['startUtf16'] as int? ?? 0,
        endUtf16: json['endUtf16'] as int? ?? 0,
        role: ProofEvidenceRole.values.byName(json['role'] as String),
        verifiedAt: DateTime.parse(json['verifiedAt'] as String),
        verifierSchemaVersion: json['verifierSchemaVersion'] as int? ?? 1,
      );
}

class VerifiedProofClaim {
  const VerifiedProofClaim({
    required this.claimId,
    required this.kind,
    required this.text,
    required this.evidence,
  });

  final String claimId;
  final ProofClaimKind kind;
  final String text;
  final List<VerifiedEvidenceSnapshot> evidence;

  Map<String, dynamic> toJson() => {
    'claimId': claimId,
    'kind': kind.name,
    'text': text,
    'evidence': evidence.map((item) => item.toJson()).toList(),
  };

  factory VerifiedProofClaim.fromJson(Map<String, dynamic> json) =>
      VerifiedProofClaim(
        claimId: json['claimId'] as String? ?? '',
        kind: ProofClaimKind.values.byName(json['kind'] as String),
        text: json['text'] as String? ?? '',
        evidence: (json['evidence'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) => VerifiedEvidenceSnapshot.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
      );
}

class ProofQualityReceipt {
  const ProofQualityReceipt({
    required this.repeatFrequency,
    required this.trend,
    required this.confidenceBand,
    required this.counterexamples,
    required this.missingEvidence,
    required this.strengthOverTime,
    required this.firstOccurrence,
    required this.lastOccurrence,
    required this.contradictions,
    this.schemaVersion = 1,
  });

  final int repeatFrequency;
  final String trend;
  final ProofConfidenceBand confidenceBand;
  final int counterexamples;
  final List<ProofClaimKind> missingEvidence;
  final String strengthOverTime;
  final DateTime firstOccurrence;
  final DateTime lastOccurrence;
  final int contradictions;
  final int schemaVersion;

  Map<String, dynamic> toJson() => {
    'repeatFrequency': repeatFrequency,
    'trend': trend,
    'confidenceBand': confidenceBand.name,
    'counterexamples': counterexamples,
    'missingEvidence': missingEvidence.map((item) => item.name).toList(),
    'strengthOverTime': strengthOverTime,
    'firstOccurrence': firstOccurrence.toUtc().toIso8601String(),
    'lastOccurrence': lastOccurrence.toUtc().toIso8601String(),
    'contradictions': contradictions,
    'schemaVersion': schemaVersion,
  };

  factory ProofQualityReceipt.fromJson(Map<String, dynamic> json) =>
      ProofQualityReceipt(
        repeatFrequency: json['repeatFrequency'] as int? ?? 0,
        trend: json['trend'] as String? ?? 'not_established',
        confidenceBand: ProofConfidenceBand.values.byName(
          json['confidenceBand'] as String,
        ),
        counterexamples: json['counterexamples'] as int? ?? 0,
        missingEvidence: (json['missingEvidence'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map(ProofClaimKind.values.byName)
            .toList(),
        strengthOverTime:
            json['strengthOverTime'] as String? ?? 'not_established',
        firstOccurrence: DateTime.parse(json['firstOccurrence'] as String),
        lastOccurrence: DateTime.parse(json['lastOccurrence'] as String),
        contradictions: json['contradictions'] as int? ?? 0,
        schemaVersion: json['schemaVersion'] as int? ?? 1,
      );
}

class VerifiedProof {
  const VerifiedProof({
    required this.proofId,
    required this.archiveScope,
    required this.ownerScope,
    required this.reflection,
    required this.claims,
    required this.confidenceBand,
    required this.qualityReceipt,
    required this.verifiedAt,
    required this.sourceRevisionFingerprint,
    required this.proofFingerprint,
    required this.semanticFramingFingerprint,
    required this.wordingFingerprint,
    this.schemaVersion = 1,
  });

  final String proofId;
  final String archiveScope;
  final String ownerScope;
  final Reflection reflection;
  final List<VerifiedProofClaim> claims;
  final ProofConfidenceBand confidenceBand;
  final ProofQualityReceipt qualityReceipt;
  final DateTime verifiedAt;
  final String sourceRevisionFingerprint;
  final String proofFingerprint;
  final String semanticFramingFingerprint;
  final String wordingFingerprint;
  final int schemaVersion;

  Map<String, dynamic> toJson() => {
    'proofId': proofId,
    'archiveScope': archiveScope,
    'ownerScope': ownerScope,
    'reflection': reflection.toJson(),
    'claims': claims.map((claim) => claim.toJson()).toList(),
    'confidenceBand': confidenceBand.name,
    'qualityReceipt': qualityReceipt.toJson(),
    'verifiedAt': verifiedAt.toUtc().toIso8601String(),
    'sourceRevisionFingerprint': sourceRevisionFingerprint,
    'proofFingerprint': proofFingerprint,
    'semanticFramingFingerprint': semanticFramingFingerprint,
    'wordingFingerprint': wordingFingerprint,
    'schemaVersion': schemaVersion,
  };

  factory VerifiedProof.fromJson(Map<String, dynamic> json) => VerifiedProof(
    proofId: json['proofId'] as String? ?? '',
    archiveScope: json['archiveScope'] as String? ?? '',
    ownerScope: json['ownerScope'] as String? ?? '',
    reflection: Reflection.fromJson(
      Map<String, dynamic>.from(json['reflection'] as Map? ?? const {}),
    ),
    claims: (json['claims'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              VerifiedProofClaim.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    confidenceBand: ProofConfidenceBand.values.byName(
      json['confidenceBand'] as String,
    ),
    qualityReceipt: ProofQualityReceipt.fromJson(
      Map<String, dynamic>.from(json['qualityReceipt'] as Map),
    ),
    verifiedAt: DateTime.parse(json['verifiedAt'] as String),
    sourceRevisionFingerprint:
        json['sourceRevisionFingerprint'] as String? ?? '',
    proofFingerprint: json['proofFingerprint'] as String? ?? '',
    semanticFramingFingerprint:
        json['semanticFramingFingerprint'] as String? ?? '',
    wordingFingerprint: json['wordingFingerprint'] as String? ?? '',
    schemaVersion: json['schemaVersion'] as int? ?? 1,
  );
}

sealed class ProofAdmissionResult {
  const ProofAdmissionResult(this.outcome);

  final ProofAdmissionOutcome outcome;
}

final class ProofAdmitted extends ProofAdmissionResult {
  const ProofAdmitted(this.proof) : super(ProofAdmissionOutcome.admitted);

  final VerifiedProof proof;
}

final class ProofNotAdmitted extends ProofAdmissionResult {
  const ProofNotAdmitted(super.outcome, {required this.reason});

  final String reason;
}
