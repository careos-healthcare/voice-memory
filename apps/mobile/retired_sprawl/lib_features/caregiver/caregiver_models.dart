import 'package:archiveme_mobile/config/app_mode_config.dart';

/// Dart mirror of `@voice-memory/shared` caregiver contracts.
class CaregiverPermissions {
  const CaregiverPermissions({
    required this.evidenceStreamIds,
    required this.reviewSummaries,
    required this.thresholdAlerts,
  });

  factory CaregiverPermissions.fromJson(Map<String, dynamic> json) {
    final streams = json['evidenceStreamIds'];
    return CaregiverPermissions(
      evidenceStreamIds: streams is List
          ? List<String>.unmodifiable(streams.whereType<String>())
          : const [],
      reviewSummaries: json['reviewSummaries'] == true,
      thresholdAlerts: json['thresholdAlerts'] == true,
    );
  }

  static const journalStream = 'journal';
  static const proofTrailStream = 'proof_trail';
  static const timelineStream = 'timeline';

  /// Consent choices carried as booleans rather than as [evidenceStreamIds]
  /// entries. Nothing ever writes these ids into the list, so a membership
  /// test alone can only ever deny them — [allowsStream] resolves them against
  /// [thresholdAlerts] and [reviewSummaries] instead.
  static const insightAlertsStream = 'insight_alerts';
  static const reviewSummariesStream = 'review_summaries';

  static const defaultScopes = CaregiverPermissions(
    evidenceStreamIds: [
      journalStream,
      proofTrailStream,
      timelineStream,
    ],
    reviewSummaries: true,
    thresholdAlerts: true,
  );

  final List<String> evidenceStreamIds;
  final bool reviewSummaries;
  final bool thresholdAlerts;

  /// Single authoritative read gate for every consent choice on the token.
  ///
  /// The boolean choices take priority over list membership: the boolean is the
  /// answer the owner gave to that prompt, so a token that lists a pseudo-stream
  /// id while carrying `false` is still a decline. Unknown ids deny.
  bool allowsStream(String streamId) => switch (streamId) {
        insightAlertsStream => thresholdAlerts,
        reviewSummariesStream => reviewSummaries,
        _ => evidenceStreamIds.contains(streamId),
      };

  Map<String, dynamic> toJson() => {
        'evidenceStreamIds': List<String>.of(evidenceStreamIds),
        'reviewSummaries': reviewSummaries,
        'thresholdAlerts': thresholdAlerts,
      };
}

class MonitoringConsentToken {
  const MonitoringConsentToken({
    required this.tokenId,
    required this.subjectAccountId,
    required this.caregiverId,
    required this.permissions,
    required this.issuedAt,
    required this.expiresAt,
    required this.policyVersion,
    required this.signature,
  });

  factory MonitoringConsentToken.fromJson(Map<String, dynamic> json) {
    final permissionsRaw = json['permissions'];
    return MonitoringConsentToken(
      tokenId: json['tokenId']?.toString() ?? '',
      subjectAccountId: json['subjectAccountId']?.toString() ?? '',
      caregiverId: json['caregiverId']?.toString() ?? '',
      permissions: permissionsRaw is Map<String, dynamic>
          ? CaregiverPermissions.fromJson(permissionsRaw)
          : CaregiverPermissions.defaultScopes,
      issuedAt: _parseUtc(json['issuedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      expiresAt: _parseUtc(json['expiresAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      policyVersion: json['policyVersion'] is int ? json['policyVersion'] as int : 1,
      signature: json['signature']?.toString() ?? '',
    );
  }

  final String tokenId;
  final String subjectAccountId;
  final String caregiverId;
  final CaregiverPermissions permissions;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int policyVersion;
  final String signature;

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
        'subjectAccountId': subjectAccountId,
        'caregiverId': caregiverId,
        'permissions': permissions.toJson(),
        'issuedAt': issuedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'policyVersion': policyVersion,
        'signature': signature,
      };
}

class CaregiverSession {
  const CaregiverSession({
    required this.sessionId,
    required this.mode,
    required this.caregiverId,
    required this.subjectAccountId,
    required this.permissions,
    required this.tokenId,
    required this.startedAt,
    required this.expiresAt,
    required this.validatedAt,
  });

  factory CaregiverSession.fromJson(Map<String, dynamic> json) {
    return CaregiverSession(
      sessionId: json['sessionId']?.toString() ?? '',
      mode: AppModeJson.fromWire(json['mode']?.toString()) ??
          AppMode.caregiverMonitoring,
      caregiverId: json['caregiverId']?.toString() ?? '',
      subjectAccountId: json['subjectAccountId']?.toString() ?? '',
      permissions: json['permissions'] is Map<String, dynamic>
          ? CaregiverPermissions.fromJson(
              Map<String, dynamic>.from(json['permissions'] as Map),
            )
          : CaregiverPermissions.defaultScopes,
      tokenId: json['tokenId']?.toString() ?? '',
      startedAt: _parseUtc(json['startedAt']) ?? DateTime.now().toUtc(),
      expiresAt: _parseUtc(json['expiresAt']) ?? DateTime.now().toUtc(),
      validatedAt: _parseUtc(json['validatedAt']) ?? DateTime.now().toUtc(),
    );
  }

  final String sessionId;
  final AppMode mode;
  final String caregiverId;
  final String subjectAccountId;
  final CaregiverPermissions permissions;
  final String tokenId;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime validatedAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'mode': mode.wireValue,
        'caregiverId': caregiverId,
        'subjectAccountId': subjectAccountId,
        'permissions': permissions.toJson(),
        'tokenId': tokenId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'validatedAt': validatedAt.toUtc().toIso8601String(),
      };
}

enum CaregiverAuditAction {
  sessionStarted,
  sessionValidated,
  sessionExpired,
  modeSwitched,
  consentGranted,
  consentRevoked,
  evidenceStreamRead,
  reviewSummaryRead,
  thresholdAlertRead,
  dashboardViewed,
  accessDenied,
}

extension CaregiverAuditActionWire on CaregiverAuditAction {
  String get wireValue => switch (this) {
        CaregiverAuditAction.sessionStarted => 'session_started',
        CaregiverAuditAction.sessionValidated => 'session_validated',
        CaregiverAuditAction.sessionExpired => 'session_expired',
        CaregiverAuditAction.modeSwitched => 'mode_switched',
        CaregiverAuditAction.consentGranted => 'consent_granted',
        CaregiverAuditAction.consentRevoked => 'consent_revoked',
        CaregiverAuditAction.evidenceStreamRead => 'evidence_stream_read',
        CaregiverAuditAction.reviewSummaryRead => 'review_summary_read',
        CaregiverAuditAction.thresholdAlertRead => 'threshold_alert_read',
        CaregiverAuditAction.dashboardViewed => 'dashboard_viewed',
        CaregiverAuditAction.accessDenied => 'access_denied',
      };

  static CaregiverAuditAction? fromWire(String? raw) => switch (raw) {
        'session_started' => CaregiverAuditAction.sessionStarted,
        'session_validated' => CaregiverAuditAction.sessionValidated,
        'session_expired' => CaregiverAuditAction.sessionExpired,
        'mode_switched' => CaregiverAuditAction.modeSwitched,
        'consent_granted' => CaregiverAuditAction.consentGranted,
        'consent_revoked' => CaregiverAuditAction.consentRevoked,
        'evidence_stream_read' => CaregiverAuditAction.evidenceStreamRead,
        'review_summary_read' => CaregiverAuditAction.reviewSummaryRead,
        'threshold_alert_read' => CaregiverAuditAction.thresholdAlertRead,
        'dashboard_viewed' => CaregiverAuditAction.dashboardViewed,
        'access_denied' => CaregiverAuditAction.accessDenied,
        _ => null,
      };
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.entryId,
    required this.sessionId,
    required this.action,
    required this.resourceType,
    required this.timestamp,
    this.resourceId,
    this.metadata = const {},
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    return AuditLogEntry(
      entryId: json['entryId']?.toString() ?? '',
      sessionId: json['sessionId']?.toString() ?? '',
      action:
          CaregiverAuditActionWire.fromWire(json['action']?.toString()) ??
          CaregiverAuditAction.accessDenied,
      resourceType: json['resourceType']?.toString() ?? '',
      resourceId: json['resourceId']?.toString(),
      timestamp: _parseUtc(json['timestamp']) ?? DateTime.now().toUtc(),
      metadata: meta is Map
          ? Map<String, Object?>.from(meta.cast<String, Object?>())
          : const {},
    );
  }

  final String entryId;
  final String sessionId;
  final CaregiverAuditAction action;
  final String resourceType;
  final String? resourceId;
  final DateTime timestamp;
  final Map<String, Object?> metadata;

  Map<String, dynamic> toJson() => {
        'entryId': entryId,
        'sessionId': sessionId,
        'action': action.wireValue,
        'resourceType': resourceType,
        if (resourceId != null) 'resourceId': resourceId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

class AppModeState {
  const AppModeState({
    required this.mode,
    required this.policyVersion,
    required this.updatedAt,
    this.activeSessionId,
  });

  factory AppModeState.fromJson(Map<String, dynamic> json) {
    return AppModeState(
      mode: AppModeJson.fromWire(json['mode']?.toString()) ??
          AppModeConfigPolicy.defaultMode,
      policyVersion: json['policyVersion'] is int
          ? json['policyVersion'] as int
          : AppModeConfigPolicy.currentPolicyVersion,
      updatedAt: _parseUtc(json['updatedAt']) ?? DateTime.now().toUtc(),
      activeSessionId: json['activeSessionId']?.toString(),
    );
  }

  static AppModeState initial() => AppModeState(
        mode: AppModeConfigPolicy.defaultMode,
        policyVersion: AppModeConfigPolicy.currentPolicyVersion,
        updatedAt: DateTime.now().toUtc(),
      );

  final AppMode mode;
  final int policyVersion;
  final DateTime updatedAt;
  final String? activeSessionId;

  Map<String, dynamic> toJson() => {
        'mode': mode.wireValue,
        'policyVersion': policyVersion,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (activeSessionId != null) 'activeSessionId': activeSessionId,
      };
}

DateTime? _parseUtc(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

class CaregiverTokenVerificationResult {
  const CaregiverTokenVerificationResult({
    required this.valid,
    this.reason,
    this.session,
  });

  final bool valid;
  final String? reason;
  final CaregiverSession? session;
}