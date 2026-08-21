import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Loads and revokes active multi-party access grants from local consent stores.
class MultiPartyAccessService {
  MultiPartyAccessService({MobilePrefsStore? prefs})
      : _prefs = prefs ?? _prefsOrNull();

  static const caregiverAuditKey = 'caregiver_audit_log_v1';
  static const caregiverTokenKey = 'caregiver_consent_token_v1';
  static const caregiverSessionKey = 'caregiver_session_v1';
  static const coachTokenKey = 'coach_consent_token_v1';

  final MobilePrefsStore? _prefs;

  static MobilePrefsStore? _prefsOrNull() {
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.prefs;
  }

  Future<List<MultiPartyAccessGrant>> loadActiveGrants({DateTime? now}) async {
    final prefs = _prefs;
    if (prefs == null) return const [];

    await ConsentRevocationStore.ensureLoaded();
    final clock = (now ?? DateTime.now()).toUtc();
    final grantsById = <String, MultiPartyAccessGrant>{};

    final auditRaw = await prefs.readJsonMap(caregiverAuditKey);
    final entries = auditRaw?['entries'];
    if (entries is List) {
      for (final row in entries) {
        if (row is! Map) continue;
        final action = row['action']?.toString();
        if (action != 'consent_granted') continue;
        final grantId = row['resourceId']?.toString().trim();
        if (grantId == null || grantId.isEmpty) continue;
        if (ConsentRevocationStore.isRevoked(grantId)) continue;

        final metadata = row['metadata'];
        final meta = metadata is Map
            ? Map<String, Object?>.from(metadata.cast<String, Object?>())
            : const <String, Object?>{};
        final grantedAt = _parseUtc(row['timestamp']) ?? clock;
        final expiresAt = _parseUtc(meta['expiresAt']);
        if (expiresAt != null && !clock.isBefore(expiresAt)) continue;

        grantsById[grantId] = MultiPartyAccessGrant(
          grantId: grantId,
          partyId: meta['caregiverId']?.toString() ?? 'Caregiver',
          role: MultiPartyAccessRole.caregiver,
          grantedAt: grantedAt,
          expiresAt: expiresAt,
        );
      }
    }

    await _mergeTokenGrant(
      prefs: prefs,
      prefsKey: caregiverTokenKey,
      role: MultiPartyAccessRole.caregiver,
      clock: clock,
      grantsById: grantsById,
    );
    await _mergeTokenGrant(
      prefs: prefs,
      prefsKey: coachTokenKey,
      role: MultiPartyAccessRole.coach,
      clock: clock,
      grantsById: grantsById,
    );

    final sessionRaw = await prefs.readJsonMap(caregiverSessionKey);
    final activeTokenId = sessionRaw?['tokenId']?.toString();
    if (activeTokenId != null && grantsById.containsKey(activeTokenId)) {
      final existing = grantsById[activeTokenId]!;
      grantsById[activeTokenId] = MultiPartyAccessGrant(
        grantId: existing.grantId,
        partyId: existing.partyId,
        role: existing.role,
        grantedAt: existing.grantedAt,
        expiresAt: existing.expiresAt,
        isCurrentSession: true,
      );
    }

    final grants = grantsById.values.toList()
      ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
    return grants;
  }

  Future<void> revokeGrant(MultiPartyAccessGrant grant) async {
    final prefs = _prefs;
    if (prefs == null) return;

    await ConsentRevocationStore.ensureLoaded();
    await ConsentRevocationStore.revoke(grant.grantId);

    if (grant.role == MultiPartyAccessRole.caregiver) {
      await _clearTokenIfMatches(
        prefs: prefs,
        tokenKey: caregiverTokenKey,
        sessionKey: caregiverSessionKey,
        grantId: grant.grantId,
      );
    } else if (grant.role == MultiPartyAccessRole.coach) {
      await _clearTokenIfMatches(
        prefs: prefs,
        tokenKey: coachTokenKey,
        grantId: grant.grantId,
      );
    }

    await _appendRevocationAudit(prefs, grant);
  }

  Future<void> _mergeTokenGrant({
    required MobilePrefsStore prefs,
    required String prefsKey,
    required MultiPartyAccessRole role,
    required DateTime clock,
    required Map<String, MultiPartyAccessGrant> grantsById,
  }) async {
    final raw = await prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return;

    final grantId = raw['tokenId']?.toString().trim();
    if (grantId == null || grantId.isEmpty) return;
    if (ConsentRevocationStore.isRevoked(grantId)) return;

    final expiresAt = _parseUtc(raw['expiresAt']);
    if (expiresAt != null && !clock.isBefore(expiresAt)) return;

    final partyId = raw['caregiverId']?.toString() ??
        raw['coachId']?.toString() ??
        role.label;
    final grantedAt = _parseUtc(raw['issuedAt']) ?? clock;

    grantsById.putIfAbsent(
      grantId,
      () => MultiPartyAccessGrant(
        grantId: grantId,
        partyId: partyId,
        role: role,
        grantedAt: grantedAt,
        expiresAt: expiresAt,
      ),
    );
  }

  Future<void> _clearTokenIfMatches({
    required MobilePrefsStore prefs,
    required String tokenKey,
    required String grantId,
    String? sessionKey,
  }) async {
    final tokenRaw = await prefs.readJsonMap(tokenKey);
    if (tokenRaw?['tokenId']?.toString() == grantId) {
      await prefs.writeJsonMap(tokenKey, {});
    }
    if (sessionKey != null) {
      final sessionRaw = await prefs.readJsonMap(sessionKey);
      if (sessionRaw?['tokenId']?.toString() == grantId) {
        await prefs.writeJsonMap(sessionKey, {});
      }
    }
  }

  Future<void> _appendRevocationAudit(
    MobilePrefsStore prefs,
    MultiPartyAccessGrant grant,
  ) async {
    final auditRaw = await prefs.readJsonMap(caregiverAuditKey) ?? {};
    final entries = <Map<String, Object?>>[
      ...?((auditRaw['entries'] as List?)?.whereType<Map>().map(
            (row) => Map<String, Object?>.from(row.cast<String, Object?>()),
          )),
    ];
    entries.add({
      'entryId': 'revoke_${grant.grantId}_${DateTime.now().toUtc().millisecondsSinceEpoch}',
      'sessionId': 'settings_consent_panel',
      'action': 'consent_revoked',
      'resourceType': 'consent_token',
      'resourceId': grant.grantId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'metadata': {
        'partyId': grant.partyId,
        'role': grant.role.wireValue,
      },
    });
    await prefs.writeJsonMap(caregiverAuditKey, {'entries': entries});
  }
}

DateTime? _parseUtc(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw)?.toUtc();
}
