import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';

/// Kind of derived claim the archive may surface under the evidence contract.
enum DerivedClaimKind {
  savedContent,
  relatedMoments,
  possiblePattern,
  change,
}

/// User review status for a derived claim — persisted across restarts and sync.
enum DerivedClaimUserStatus {
  unreviewed,
  fits,
  partlyFits,
  notForMe,
  corrected,
  hidden,
}

/// Reference to one supporting journal moment — never inferred without an id.
class DerivedClaimEvidenceRef {
  const DerivedClaimEvidenceRef({
    required this.entryId,
    required this.quote,
    required this.sourceDate,
    this.transcriptRevision = '',
    this.hidden = false,
    this.deleted = false,
  });

  factory DerivedClaimEvidenceRef.fromVerifiedSnapshot(
    VerifiedEvidenceSnapshot snapshot, {
    bool hidden = false,
    bool deleted = false,
  }) => DerivedClaimEvidenceRef(
    entryId: snapshot.sourceEntryId,
    quote: snapshot.quote,
    sourceDate: snapshot.sourceDate,
    transcriptRevision: snapshot.transcriptRevision,
    hidden: hidden,
    deleted: deleted,
  );

  final String entryId;
  final String quote;
  final DateTime sourceDate;
  final String transcriptRevision;
  final bool hidden;
  final bool deleted;

  bool get isAvailable => !hidden && !deleted && entryId.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'quote': quote,
    'sourceDate': sourceDate.toUtc().toIso8601String(),
    'transcriptRevision': transcriptRevision,
    'hidden': hidden,
    'deleted': deleted,
  };

  factory DerivedClaimEvidenceRef.fromJson(Map<String, dynamic> json) =>
      DerivedClaimEvidenceRef(
        entryId: json['entryId'] as String? ?? '',
        quote: json['quote'] as String? ?? '',
        sourceDate: DateTime.parse(json['sourceDate'] as String),
        transcriptRevision: json['transcriptRevision'] as String? ?? '',
        hidden: json['hidden'] == true,
        deleted: json['deleted'] == true,
      );
}

/// Metadata about how a derived claim was produced — auditable, never user text.
class DerivedClaimGenerationMeta {
  const DerivedClaimGenerationMeta({
    required this.method,
    this.modelId,
    this.promptPolicyVersion,
    this.providerResponseId,
  });

  final String method;
  final String? modelId;
  final String? promptPolicyVersion;
  final String? providerResponseId;

  Map<String, dynamic> toJson() => {
    'method': method,
    if (modelId != null) 'modelId': modelId,
    if (promptPolicyVersion != null) 'promptPolicyVersion': promptPolicyVersion,
    if (providerResponseId != null) 'providerResponseId': providerResponseId,
  };

  factory DerivedClaimGenerationMeta.fromJson(Map<String, dynamic> json) =>
      DerivedClaimGenerationMeta(
        method: json['method'] as String? ?? 'unknown',
        modelId: json['modelId'] as String?,
        promptPolicyVersion: json['promptPolicyVersion'] as String?,
        providerResponseId: json['providerResponseId'] as String?,
      );
}

/// Immutable derived claim with complete evidence references and review state.
class DerivedClaim {
  const DerivedClaim({
    required this.claimId,
    required this.kind,
    required this.displayText,
    required this.evidenceRefs,
    required this.evidenceRangeStart,
    required this.evidenceRangeEnd,
    required this.generation,
    required this.eligibilityReason,
    required this.eligibilityPolicyVersion,
    required this.userStatus,
    required this.createdAt,
    required this.updatedAt,
    this.encryptedUserCorrection,
  });

  final String claimId;
  final DerivedClaimKind kind;
  final String displayText;
  final List<DerivedClaimEvidenceRef> evidenceRefs;
  final DateTime? evidenceRangeStart;
  final DateTime? evidenceRangeEnd;
  final DerivedClaimGenerationMeta generation;
  final String eligibilityReason;
  final int eligibilityPolicyVersion;
  final DerivedClaimUserStatus userStatus;
  final String? encryptedUserCorrection;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<DerivedClaimEvidenceRef> get availableEvidenceRefs =>
      evidenceRefs.where((ref) => ref.isAvailable).toList();

  bool get hasRenderableEvidence => availableEvidenceRefs.isNotEmpty;

  bool get isHiddenFromUser =>
      userStatus == DerivedClaimUserStatus.hidden ||
      userStatus == DerivedClaimUserStatus.notForMe;

  Map<String, dynamic> toJson() => {
    'claimId': claimId,
    'kind': kind.name,
    'displayText': displayText,
    'evidenceRefs': evidenceRefs.map((ref) => ref.toJson()).toList(),
    'evidenceRangeStart': evidenceRangeStart?.toUtc().toIso8601String(),
    'evidenceRangeEnd': evidenceRangeEnd?.toUtc().toIso8601String(),
    'generation': generation.toJson(),
    'eligibilityReason': eligibilityReason,
    'eligibilityPolicyVersion': eligibilityPolicyVersion,
    'userStatus': userStatus.name,
    if (encryptedUserCorrection != null)
      'encryptedUserCorrection': encryptedUserCorrection,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory DerivedClaim.fromJson(Map<String, dynamic> json) => DerivedClaim(
    claimId: json['claimId'] as String? ?? '',
    kind: DerivedClaimKind.values.byName(json['kind'] as String),
    displayText: json['displayText'] as String? ?? '',
    evidenceRefs: (json['evidenceRefs'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => DerivedClaimEvidenceRef.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(),
    evidenceRangeStart: _dateOrNull(json['evidenceRangeStart']),
    evidenceRangeEnd: _dateOrNull(json['evidenceRangeEnd']),
    generation: DerivedClaimGenerationMeta.fromJson(
      Map<String, dynamic>.from(json['generation'] as Map? ?? const {}),
    ),
    eligibilityReason: json['eligibilityReason'] as String? ?? '',
    eligibilityPolicyVersion: json['eligibilityPolicyVersion'] as int? ?? 1,
    userStatus: DerivedClaimUserStatus.values.byName(
      json['userStatus'] as String? ?? DerivedClaimUserStatus.unreviewed.name,
    ),
    encryptedUserCorrection: json['encryptedUserCorrection'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  static DateTime? _dateOrNull(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.parse(value) : null;
}

/// Maps archive correction choices to derived-claim user status.
DerivedClaimUserStatus userStatusFromCorrection(String choiceName) =>
    switch (choiceName) {
      'exactlyRight' => DerivedClaimUserStatus.fits,
      'partlyRight' => DerivedClaimUserStatus.partlyFits,
      'wrong' ||
      'wrongWording' ||
      'wrongEvidence' ||
      'ignoreForever' => DerivedClaimUserStatus.notForMe,
      _ => DerivedClaimUserStatus.unreviewed,
    };
