import 'package:archiveme_mobile/features/caregiver/caregiver_audit_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_revocation_store.dart';

/// Active caregiver consent grant derived from audit + revocation state.
class CaregiverActiveGrant {
  const CaregiverActiveGrant({
    required this.tokenId,
    required this.caregiverId,
    required this.subjectAccountId,
    required this.grantedAt,
    this.expiresAt,
    this.isCurrentSession = false,
  });

  final String tokenId;
  final String caregiverId;
  final String subjectAccountId;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final bool isCurrentSession;
}

/// Access grants plus chronological audit trail for the caregiver dashboard.
class CaregiverAccessOverview {
  const CaregiverAccessOverview({
    required this.activeGrants,
    required this.accessLog,
  });

  final List<CaregiverActiveGrant> activeGrants;
  final List<AuditLogEntry> accessLog;
}

/// Builds active-grant and audit-log snapshots from local stores.
class CaregiverAccessService {
  CaregiverAccessService({
    required CaregiverAuditStore auditStore,
    required CaregiverModeStore modeStore,
  })  : _auditStore = auditStore,
        _modeStore = modeStore;

  final CaregiverAuditStore _auditStore;
  final CaregiverModeStore _modeStore;

  Future<CaregiverAccessOverview> loadOverview() async {
    await _auditStore.ensureLoaded();
    await ConsentRevocationStore.ensureLoaded();

    final session = await _modeStore.readSession();
    final storedToken = await _modeStore.readStoredToken();
    final activeGrants = _buildActiveGrants(
      session: session,
      storedToken: storedToken,
    );
    final accessLog = List<AuditLogEntry>.from(_auditStore.entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return CaregiverAccessOverview(
      activeGrants: activeGrants,
      accessLog: accessLog,
    );
  }

  List<CaregiverActiveGrant> _buildActiveGrants({
    required CaregiverSession? session,
    required MonitoringConsentToken? storedToken,
  }) {
    final grantsByToken = <String, CaregiverActiveGrant>{};

    for (final entry in _auditStore.entries) {
      if (entry.action != CaregiverAuditAction.consentGranted) continue;
      final tokenId = entry.resourceId?.trim();
      if (tokenId == null || tokenId.isEmpty) continue;
      if (ConsentRevocationStore.isRevoked(tokenId)) continue;

      final metadata = entry.metadata;
      grantsByToken[tokenId] = CaregiverActiveGrant(
        tokenId: tokenId,
        caregiverId: metadata['caregiverId']?.toString() ?? 'unknown_caregiver',
        subjectAccountId:
            metadata['subjectAccountId']?.toString() ?? 'unknown_subject',
        grantedAt: entry.timestamp,
        expiresAt: _parseUtc(metadata['expiresAt']),
        isCurrentSession: session?.tokenId == tokenId,
      );
    }

    if (storedToken != null &&
        !ConsentRevocationStore.isRevoked(storedToken.tokenId) &&
        !grantsByToken.containsKey(storedToken.tokenId)) {
      grantsByToken[storedToken.tokenId] = CaregiverActiveGrant(
        tokenId: storedToken.tokenId,
        caregiverId: storedToken.caregiverId,
        subjectAccountId: storedToken.subjectAccountId,
        grantedAt: storedToken.issuedAt,
        expiresAt: storedToken.expiresAt,
        isCurrentSession: session?.tokenId == storedToken.tokenId,
      );
    }

    final grants = grantsByToken.values.toList()
      ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
    return grants;
  }
}

DateTime? _parseUtc(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw)?.toUtc();
}
