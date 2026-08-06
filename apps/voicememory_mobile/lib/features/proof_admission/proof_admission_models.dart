import '../../models/reflection.dart';
import 'proof_quality.dart';

// The receipt's own field types travel with it, so a caller never needs to know
// which file inside this feature declared them.
export 'proof_quality.dart';

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
    this.remoteProcessingConsented = false,
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

/// The one immutable proof-quality object. Dimensions the evidence could not
/// establish stay explicitly absent rather than defaulting to a flattering
/// value: absent occurrences are null and unestablished states carry an
/// explicit `insufficientEvidence` member.
class ProofQualityReceipt {
  const ProofQualityReceipt({
    required this.proofType,
    required this.confidenceBand,
    required this.frequency,
    required this.trend,
    required this.strengthOverTime,
    required this.supportingEvidence,
    required this.counterexamples,
    required this.contradictions,
    required this.missingEvidence,
    required this.firstOccurrence,
    required this.lastOccurrence,
    required this.generatedAt,
    this.thenEvidence,
    this.nowEvidence,
    this.unsupportedClaims = const [],
    this.userConfirmedWording,
    this.verifierVersion = 1,
    this.scorerVersion = 1,
    this.configVersion = 1,
    this.schemaVersion = 2,
  });

  final ProofType proofType;
  final ProofConfidenceBand confidenceBand;
  final ProofFrequency frequency;
  final ProofTrend trend;
  final ProofStrengthOverTime strengthOverTime;
  final List<VerifiedEvidenceSnapshot> supportingEvidence;
  final List<VerifiedEvidenceSnapshot> counterexamples;

  /// Never trimmed to make a proof look cleaner than its evidence.
  final List<VerifiedEvidenceSnapshot> contradictions;

  final List<MissingEvidenceReason> missingEvidence;
  final DateTime? firstOccurrence;
  final DateTime? lastOccurrence;
  final DateTime generatedAt;
  final VerifiedEvidenceSnapshot? thenEvidence;
  final VerifiedEvidenceSnapshot? nowEvidence;

  /// Claims the model asserted that verification could not support. Retained so
  /// the detail surface can say what is still missing.
  final List<ProofClaimKind> unsupportedClaims;

  /// Set when a correction gave this framing a user-preferred label.
  final String? userConfirmedWording;

  final int verifierVersion;
  final int scorerVersion;
  final int configVersion;
  final int schemaVersion;

  Map<String, dynamic> toJson() => {
    'proofType': proofType.name,
    'confidenceBand': confidenceBand.name,
    'frequency': frequency.toJson(),
    'trend': trend.name,
    'strengthOverTime': strengthOverTime.name,
    'supportingEvidence': supportingEvidence
        .map((item) => item.toJson())
        .toList(),
    'counterexamples': counterexamples.map((item) => item.toJson()).toList(),
    'contradictions': contradictions.map((item) => item.toJson()).toList(),
    'missingEvidence': missingEvidence.map((item) => item.name).toList(),
    'firstOccurrence': firstOccurrence?.toUtc().toIso8601String(),
    'lastOccurrence': lastOccurrence?.toUtc().toIso8601String(),
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'thenEvidence': thenEvidence?.toJson(),
    'nowEvidence': nowEvidence?.toJson(),
    'unsupportedClaims': unsupportedClaims.map((item) => item.name).toList(),
    'userConfirmedWording': userConfirmedWording,
    'verifierVersion': verifierVersion,
    'scorerVersion': scorerVersion,
    'configVersion': configVersion,
    'schemaVersion': schemaVersion,
  };

  /// Schema 1 stored bare counts and free-text trend labels. Those dimensions
  /// are restored as explicitly unestablished rather than guessed, so an old
  /// receipt can never claim a trend that was never computed from dated
  /// evidence.
  factory ProofQualityReceipt.fromJson(Map<String, dynamic> json) =>
      ProofQualityReceipt(
        proofType: _enumOrDefault(
          ProofType.values,
          json['proofType'],
          ProofType.currentObservation,
        ),
        confidenceBand: ProofConfidenceBand.values.byName(
          json['confidenceBand'] as String,
        ),
        frequency: json['frequency'] is Map
            ? ProofFrequency.fromJson(
                Map<String, dynamic>.from(json['frequency'] as Map),
              )
            : const ProofFrequency.none(),
        trend: _enumOrDefault(
          ProofTrend.values,
          json['trend'],
          ProofTrend.insufficientEvidence,
        ),
        strengthOverTime: _enumOrDefault(
          ProofStrengthOverTime.values,
          json['strengthOverTime'],
          ProofStrengthOverTime.insufficientEvidence,
        ),
        supportingEvidence: _snapshots(json['supportingEvidence']),
        counterexamples: _snapshots(json['counterexamples']),
        contradictions: _snapshots(json['contradictions']),
        missingEvidence: (json['missingEvidence'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map(
              (name) => MissingEvidenceReason.values
                  .where((item) => item.name == name)
                  .firstOrNull,
            )
            .nonNulls
            .toList(),
        firstOccurrence: _dateOrNull(json['firstOccurrence']),
        lastOccurrence: _dateOrNull(json['lastOccurrence']),
        generatedAt:
            _dateOrNull(json['generatedAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        thenEvidence: _snapshotOrNull(json['thenEvidence']),
        nowEvidence: _snapshotOrNull(json['nowEvidence']),
        unsupportedClaims:
            (json['unsupportedClaims'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .map(
                  (name) => ProofClaimKind.values
                      .where((item) => item.name == name)
                      .firstOrNull,
                )
                .nonNulls
                .toList(),
        userConfirmedWording: json['userConfirmedWording'] as String?,
        verifierVersion: json['verifierVersion'] as int? ?? 1,
        scorerVersion: json['scorerVersion'] as int? ?? 1,
        configVersion: json['configVersion'] as int? ?? 1,
        schemaVersion: json['schemaVersion'] as int? ?? 2,
      );

  ProofQualityReceipt withUserConfirmedWording(String? wording) =>
      wording == null || wording.trim().isEmpty
      ? this
      : ProofQualityReceipt(
          proofType: proofType,
          confidenceBand: confidenceBand,
          frequency: frequency,
          trend: trend,
          strengthOverTime: strengthOverTime,
          supportingEvidence: supportingEvidence,
          counterexamples: counterexamples,
          contradictions: contradictions,
          missingEvidence: missingEvidence,
          firstOccurrence: firstOccurrence,
          lastOccurrence: lastOccurrence,
          generatedAt: generatedAt,
          thenEvidence: thenEvidence,
          nowEvidence: nowEvidence,
          unsupportedClaims: unsupportedClaims,
          userConfirmedWording: wording.trim(),
          verifierVersion: verifierVersion,
          scorerVersion: scorerVersion,
          configVersion: configVersion,
          schemaVersion: schemaVersion,
        );

  /// Schema 1 stored counterexamples and contradictions as bare counts, so a
  /// non-list here is an old receipt rather than corruption. It restores with no
  /// evidence instead of throwing.
  static List<VerifiedEvidenceSnapshot> _snapshots(Object? value) =>
      (value is List ? value : const [])
          .whereType<Map>()
          .map(
            (item) => VerifiedEvidenceSnapshot.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

  static T _enumOrDefault<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) => values.where((item) => item.name == raw).firstOrNull ?? fallback;

  static DateTime? _dateOrNull(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.parse(value) : null;

  static VerifiedEvidenceSnapshot? _snapshotOrNull(Object? value) =>
      value is Map
      ? VerifiedEvidenceSnapshot.fromJson(Map<String, dynamic>.from(value))
      : null;
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
