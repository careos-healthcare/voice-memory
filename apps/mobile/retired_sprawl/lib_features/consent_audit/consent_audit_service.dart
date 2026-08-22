import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_audit_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/coach/coach_mode_store.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_revocation_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

enum ConsentGrantKind { caregiverMonitoring, coachClient }

enum ConsentGrantStatus { active, revoked, expired }

/// One consent grant row for the audit screen.
class ConsentGrantRecord {
  const ConsentGrantRecord({
    required this.tokenId,
    required this.kind,
    required this.granteeLabel,
    required this.scopeSummary,
    required this.grantedAt,
    required this.revokedAt,
    required this.expiresAt,
    required this.status,
  });

  final String tokenId;
  final ConsentGrantKind kind;
  final String granteeLabel;
  final String scopeSummary;
  final DateTime? grantedAt;
  final DateTime? revokedAt;
  final DateTime? expiresAt;
  final ConsentGrantStatus status;
}

/// Aggregates caregiver/coach consent grants and local audit log entries.
class ConsentAuditService {
  ConsentAuditService({
    required MobilePrefsStore prefs,
    CaregiverModeStore? caregiverStore,
    CoachModeStore? coachStore,
    CaregiverAuditStore? auditStore,
  })  : _caregiverStore = caregiverStore ?? CaregiverModeStore(prefs),
        _coachStore = coachStore ?? CoachModeStore(prefs),
        _auditStore = auditStore ?? CaregiverAuditStore(prefs);

  final CaregiverModeStore _caregiverStore;
  final CoachModeStore _coachStore;
  final CaregiverAuditStore _auditStore;

  Future<List<ConsentGrantRecord>> loadGrants({DateTime? now}) async {
    await ConsentRevocationStore.ensureLoaded();
    final clock = (now ?? DateTime.now()).toUtc();
    final records = <ConsentGrantRecord>[];

    final caregiverToken = await _caregiverStore.readStoredToken();
    if (caregiverToken != null) {
      records.add(_recordFromCaregiverToken(caregiverToken, clock));
    }

    final coachToken = await _coachStore.readStoredToken();
    if (coachToken != null) {
      records.add(_recordFromCoachToken(coachToken, clock));
    }

    return records;
  }

  Future<List<AuditLogEntry>> loadAccessLog() async {
    await _auditStore.ensureLoaded();
    return _auditStore.entries;
  }

  Future<void> revokeGrant(ConsentGrantRecord record) async {
    await ConsentRevocationStore.revoke(record.tokenId);
    if (record.kind == ConsentGrantKind.caregiverMonitoring) {
      await _caregiverStore.writeStoredToken(null);
      await _caregiverStore.writeSession(null);
      await _auditStore.append(
        sessionId: record.tokenId,
        action: CaregiverAuditAction.consentRevoked,
        resourceType: 'consent_token',
        resourceId: record.tokenId,
      );
      return;
    }
    await _coachStore.writeStoredToken(null);
    await _coachStore.writeSession(null);
  }

  ConsentGrantRecord _recordFromCaregiverToken(
    MonitoringConsentToken token,
    DateTime clock,
  ) {
    final revoked = ConsentRevocationStore.isRevoked(token.tokenId);
    final expired = !clock.isBefore(token.expiresAt);
    final status = revoked
        ? ConsentGrantStatus.revoked
        : expired
        ? ConsentGrantStatus.expired
        : ConsentGrantStatus.active;
    return ConsentGrantRecord(
      tokenId: token.tokenId,
      kind: ConsentGrantKind.caregiverMonitoring,
      granteeLabel: token.caregiverId,
      scopeSummary: token.permissions.evidenceStreamIds.join(', '),
      grantedAt: token.issuedAt,
      revokedAt: revoked ? clock : null,
      expiresAt: token.expiresAt,
      status: status,
    );
  }

  ConsentGrantRecord _recordFromCoachToken(
    CoachConsentToken token,
    DateTime clock,
  ) {
    final revoked = ConsentRevocationStore.isRevoked(token.tokenId);
    final expired = !clock.isBefore(token.expiresAt);
    final status = revoked
        ? ConsentGrantStatus.revoked
        : expired
        ? ConsentGrantStatus.expired
        : ConsentGrantStatus.active;
    return ConsentGrantRecord(
      tokenId: token.tokenId,
      kind: ConsentGrantKind.coachClient,
      granteeLabel: token.coachId,
      scopeSummary: token.permissions.insightKinds
          .map((k) => k.name)
          .join(', '),
      grantedAt: token.issuedAt,
      revokedAt: revoked ? clock : null,
      expiresAt: token.expiresAt,
      status: status,
    );
  }
}

/// Display helpers for consent audit UI.
abstract final class ConsentAuditCopy {
  ConsentAuditCopy._();

  static const title = 'Consent audit trail';
  static const subtitle =
      'Active and historical consent grants for caregiver monitoring and coach access.';
  static const revokeCta = 'Revoke access';
  static const revokedSnack = 'Consent revoked — token will fail verification.';
  static const accessLogTitle = 'Local access log';
  static const coachAccessLogFollowUp =
      'Coach consent per-access server logs are not yet tracked on-device.';
  static const emptyGrants = 'No consent grants stored on this device.';

  static String statusLabel(ConsentGrantStatus status) => switch (status) {
    ConsentGrantStatus.active => 'Active',
    ConsentGrantStatus.revoked => 'Revoked',
    ConsentGrantStatus.expired => 'Expired',
  };

  static String kindLabel(ConsentGrantKind kind) => switch (kind) {
    ConsentGrantKind.caregiverMonitoring => 'Caregiver monitoring',
    ConsentGrantKind.coachClient => 'Coach client access',
  };

  static String grantedLabel(DateTime? at) =>
      at == null ? 'Unknown' : formatUserFacingDate(at);

  static String auditLine(AuditLogEntry entry) =>
      '${formatUserFacingDate(entry.timestamp)} · ${entry.action.wireValue} · '
      '${entry.resourceType}';
}
