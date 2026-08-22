import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';

/// Dart mirror of `@voice-memory/shared` coach-client-relationship contracts.
abstract final class CoachSessionPlanningInsightKinds {
  CoachSessionPlanningInsightKinds._();

  static const ArchiveInsightKind beliefs = ArchiveInsightKind.belief;
  static const ArchiveInsightKind beliefChange = ArchiveInsightKind.beliefChange;
  static const ArchiveInsightKind blindSpot = ArchiveInsightKind.blindSpot;
  static const ArchiveInsightKind contradiction = ArchiveInsightKind.contradiction;
  static const ArchiveInsightKind theme = ArchiveInsightKind.theme;

  static const List<ArchiveInsightKind> defaultPlanningKinds = [
    ArchiveInsightKind.belief,
    ArchiveInsightKind.blindSpot,
    ArchiveInsightKind.contradiction,
  ];
}

enum CoachClientRelationshipStatus {
  invited,
  consentPending,
  active,
  revoked,
  expired,
}

extension CoachClientRelationshipStatusWire on CoachClientRelationshipStatus {
  String get wireValue => switch (this) {
        CoachClientRelationshipStatus.invited => 'invited',
        CoachClientRelationshipStatus.consentPending => 'consent_pending',
        CoachClientRelationshipStatus.active => 'active',
        CoachClientRelationshipStatus.revoked => 'revoked',
        CoachClientRelationshipStatus.expired => 'expired',
      };

  static CoachClientRelationshipStatus? fromWire(String? raw) => switch (raw) {
        'invited' => CoachClientRelationshipStatus.invited,
        'consent_pending' => CoachClientRelationshipStatus.consentPending,
        'active' => CoachClientRelationshipStatus.active,
        'revoked' => CoachClientRelationshipStatus.revoked,
        'expired' => CoachClientRelationshipStatus.expired,
        _ => null,
      };
}

class CoachSharingPermissions {
  const CoachSharingPermissions({
    required this.factLedger,
    required this.confidenceBandedInsights,
    required this.insightKinds,
  });

  factory CoachSharingPermissions.fromJson(Map<String, dynamic> json) {
    final kindsRaw = json['insightKinds'];
    final kinds = kindsRaw is List
        ? kindsRaw
            .map((value) => _insightKindFromWire(value?.toString()))
            .whereType<ArchiveInsightKind>()
            .toList()
        : CoachSessionPlanningInsightKinds.defaultPlanningKinds;
    return CoachSharingPermissions(
      factLedger: json['factLedger'] == true,
      confidenceBandedInsights: json['confidenceBandedInsights'] != false,
      insightKinds: kinds.isEmpty
          ? CoachSessionPlanningInsightKinds.defaultPlanningKinds
          : kinds,
    );
  }

  static const defaults = CoachSharingPermissions(
    factLedger: false,
    confidenceBandedInsights: true,
    insightKinds: CoachSessionPlanningInsightKinds.defaultPlanningKinds,
  );

  final bool factLedger;
  final bool confidenceBandedInsights;
  final List<ArchiveInsightKind> insightKinds;

  bool allowsInsightKind(ArchiveInsightKind kind) =>
      insightKinds.contains(kind);

  Map<String, dynamic> toJson() => {
        'factLedger': factLedger,
        'confidenceBandedInsights': confidenceBandedInsights,
        'insightKinds': insightKinds.map(_insightKindWire).toList(),
      };
}

class CoachClientRelationship {
  const CoachClientRelationship({
    required this.relationshipId,
    required this.coachId,
    required this.clientAccountId,
    required this.status,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.clientDisplayName,
    this.activeConsentTokenId,
  });

  factory CoachClientRelationship.fromJson(Map<String, dynamic> json) {
    return CoachClientRelationship(
      relationshipId: json['relationshipId']?.toString() ?? '',
      coachId: json['coachId']?.toString() ?? '',
      clientAccountId: json['clientAccountId']?.toString() ?? '',
      clientDisplayName: json['clientDisplayName']?.toString(),
      status: CoachClientRelationshipStatusWire.fromWire(
            json['status']?.toString(),
          ) ??
          CoachClientRelationshipStatus.consentPending,
      permissions: json['permissions'] is Map<String, dynamic>
          ? CoachSharingPermissions.fromJson(
              Map<String, dynamic>.from(json['permissions'] as Map),
            )
          : CoachSharingPermissions.defaults,
      createdAt: _parseUtc(json['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _parseUtc(json['updatedAt']) ?? DateTime.now().toUtc(),
      activeConsentTokenId: json['activeConsentTokenId']?.toString(),
    );
  }

  final String relationshipId;
  final String coachId;
  final String clientAccountId;
  final String? clientDisplayName;
  final CoachClientRelationshipStatus status;
  final CoachSharingPermissions permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? activeConsentTokenId;

  Map<String, dynamic> toJson() => {
        'relationshipId': relationshipId,
        'coachId': coachId,
        'clientAccountId': clientAccountId,
        if (clientDisplayName != null) 'clientDisplayName': clientDisplayName,
        'status': status.wireValue,
        'permissions': permissions.toJson(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (activeConsentTokenId != null)
          'activeConsentTokenId': activeConsentTokenId,
      };
}

class CoachConsentToken {
  const CoachConsentToken({
    required this.tokenId,
    required this.relationshipId,
    required this.clientAccountId,
    required this.coachId,
    required this.permissions,
    required this.issuedAt,
    required this.expiresAt,
    required this.policyVersion,
    required this.clientAffirmationHash,
    required this.signature,
  });

  factory CoachConsentToken.fromJson(Map<String, dynamic> json) {
    return CoachConsentToken(
      tokenId: json['tokenId']?.toString() ?? '',
      relationshipId: json['relationshipId']?.toString() ?? '',
      clientAccountId: json['clientAccountId']?.toString() ?? '',
      coachId: json['coachId']?.toString() ?? '',
      permissions: json['permissions'] is Map<String, dynamic>
          ? CoachSharingPermissions.fromJson(
              Map<String, dynamic>.from(json['permissions'] as Map),
            )
          : CoachSharingPermissions.defaults,
      issuedAt: _parseUtc(json['issuedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      expiresAt: _parseUtc(json['expiresAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      policyVersion:
          json['policyVersion'] is int ? json['policyVersion'] as int : 1,
      clientAffirmationHash:
          json['clientAffirmationHash']?.toString() ?? '',
      signature: json['signature']?.toString() ?? '',
    );
  }

  final String tokenId;
  final String relationshipId;
  final String clientAccountId;
  final String coachId;
  final CoachSharingPermissions permissions;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int policyVersion;
  final String clientAffirmationHash;
  final String signature;

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
        'relationshipId': relationshipId,
        'clientAccountId': clientAccountId,
        'coachId': coachId,
        'permissions': permissions.toJson(),
        'issuedAt': issuedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'policyVersion': policyVersion,
        'clientAffirmationHash': clientAffirmationHash,
        'signature': signature,
      };
}

class CoachSession {
  const CoachSession({
    required this.sessionId,
    required this.mode,
    required this.coachId,
    required this.clientAccountId,
    required this.relationshipId,
    required this.permissions,
    required this.tokenId,
    required this.startedAt,
    required this.expiresAt,
    required this.validatedAt,
  });

  factory CoachSession.fromJson(Map<String, dynamic> json) {
    return CoachSession(
      sessionId: json['sessionId']?.toString() ?? '',
      mode: AppModeJson.fromWire(json['mode']?.toString()) ??
          AppMode.professionalCoach,
      coachId: json['coachId']?.toString() ?? '',
      clientAccountId: json['clientAccountId']?.toString() ?? '',
      relationshipId: json['relationshipId']?.toString() ?? '',
      permissions: json['permissions'] is Map<String, dynamic>
          ? CoachSharingPermissions.fromJson(
              Map<String, dynamic>.from(json['permissions'] as Map),
            )
          : CoachSharingPermissions.defaults,
      tokenId: json['tokenId']?.toString() ?? '',
      startedAt: _parseUtc(json['startedAt']) ?? DateTime.now().toUtc(),
      expiresAt: _parseUtc(json['expiresAt']) ?? DateTime.now().toUtc(),
      validatedAt: _parseUtc(json['validatedAt']) ?? DateTime.now().toUtc(),
    );
  }

  final String sessionId;
  final AppMode mode;
  final String coachId;
  final String clientAccountId;
  final String relationshipId;
  final CoachSharingPermissions permissions;
  final String tokenId;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime validatedAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'mode': mode.wireValue,
        'coachId': coachId,
        'clientAccountId': clientAccountId,
        'relationshipId': relationshipId,
        'permissions': permissions.toJson(),
        'tokenId': tokenId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'validatedAt': validatedAt.toUtc().toIso8601String(),
      };
}

class CoachTokenVerificationResult {
  const CoachTokenVerificationResult({
    required this.valid,
    this.reason,
    this.session,
  });

  final bool valid;
  final String? reason;
  final CoachSession? session;
}

String _insightKindWire(ArchiveInsightKind kind) => switch (kind) {
      ArchiveInsightKind.belief => 'belief',
      ArchiveInsightKind.beliefChange => 'beliefChange',
      ArchiveInsightKind.theme => 'theme',
      ArchiveInsightKind.contradiction => 'contradiction',
      ArchiveInsightKind.blindSpot => 'blindSpot',
      ArchiveInsightKind.chapter => 'chapter',
      ArchiveInsightKind.weeklyStory => 'weeklyStory',
      ArchiveInsightKind.askArchive => 'askArchive',
      ArchiveInsightKind.surprise => 'surprise',
      ArchiveInsightKind.challenge => 'challenge',
      ArchiveInsightKind.breakthrough => 'breakthrough',
    };

ArchiveInsightKind? _insightKindFromWire(String? raw) => switch (raw) {
      'belief' => ArchiveInsightKind.belief,
      'beliefChange' => ArchiveInsightKind.beliefChange,
      'theme' => ArchiveInsightKind.theme,
      'contradiction' => ArchiveInsightKind.contradiction,
      'blindSpot' => ArchiveInsightKind.blindSpot,
      'chapter' => ArchiveInsightKind.chapter,
      'weeklyStory' => ArchiveInsightKind.weeklyStory,
      'askArchive' => ArchiveInsightKind.askArchive,
      'surprise' => ArchiveInsightKind.surprise,
      'challenge' => ArchiveInsightKind.challenge,
      _ => null,
    };

DateTime? _parseUtc(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

/// Normalized client affirmation for consent hashing.
String coachClientAffirmationSentence({
  required String coachLabel,
  required CoachSharingPermissions permissions,
}) {
  final kinds = permissions.insightKinds.map(_insightKindWire).join(',');
  return 'I authorize $coachLabel to view my ArchiveMe coach dashboard scopes: '
      'factLedger=${permissions.factLedger}, '
      'confidenceInsights=${permissions.confidenceBandedInsights}, '
      'kinds=[$kinds]. I can revoke this access anytime.';
}