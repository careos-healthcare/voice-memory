import 'dart:async';

import 'package:archiveme_mobile/data/network/consent_renewal_api_client.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/auth/application/server_consent_renewal_coordinator.dart';
import 'package:archiveme_mobile/features/auth/application/server_consent_revocation_coordinator.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_renewal_outcome.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_revocation_outcome.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/pending_consent_revocation_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Loads and revokes active multi-party access grants from local consent stores.
class MultiPartyAccessService {
  MultiPartyAccessService({
    MobilePrefsStore? prefs,
    this._serverRevocations,
    this._serverRenewals,
  }) : _prefs = prefs ?? _prefsOrNull();

  static const caregiverAuditKey = 'caregiver_audit_log_v1';
  static const caregiverTokenKey = 'caregiver_consent_token_v1';
  static const caregiverSessionKey = 'caregiver_session_v1';
  static const coachTokenKey = 'coach_consent_token_v1';

  final MobilePrefsStore? _prefs;
  final ServerConsentRevocationCoordinator? _serverRevocations;
  final ServerConsentRenewalCoordinator? _serverRenewals;

  ServerConsentRevocationCoordinator get _coordinator =>
      _serverRevocations ?? ServerConsentRevocationCoordinator.instance;

  ServerConsentRenewalCoordinator get _renewalCoordinator =>
      _serverRenewals ?? ServerConsentRenewalCoordinator.instance;

  static MobilePrefsStore? _prefsOrNull() {
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.prefs;
  }

  Future<List<MultiPartyAccessGrant>> loadActiveGrants({DateTime? now}) async {
    final prefs = _prefs;
    if (prefs == null) return const [];

    // Opportunistic: a revoke made offline is retried the next time the user
    // opens the surface that lists their grants. Deliberately not awaited —
    // the list must render at local speed, not at network speed.
    unawaited(_coordinator.flushPending());

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

        final role = MultiPartyAccessRole.fromWire(meta['role']?.toString()) ??
            MultiPartyAccessRole.caregiver;
        if (role == MultiPartyAccessRole.observer) continue;

        grantsById[grantId] = MultiPartyAccessGrant(
          grantId: grantId,
          partyId: meta['partyId']?.toString() ??
              meta['caregiverId']?.toString() ??
              role.label,
          role: role,
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

  /// Revokes [grant] on this device, then asks the server to stop honouring it.
  ///
  /// The local effect — revocation store, stored token/session, audit row — is
  /// completed in that order before the network is touched at all, so a revoke
  /// made with no connection still takes effect immediately. The server call
  /// is attempted afterwards and queued for retry when it does not land. Never
  /// throws.
  Future<ConsentRevocationOutcome> revokeGrant(
    MultiPartyAccessGrant grant,
  ) async {
    final prefs = _prefs;
    if (prefs == null) return ConsentRevocationOutcome.notAttempted;

    // Read before clearing: the server accepts the signed token as an
    // ownership-proof fallback for grants issued before it kept a registry.
    final tokenJson = await _storedTokenFor(prefs, grant);

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

    final auditEntryId = await _appendRevocationAudit(prefs, grant);

    final domain = _revocationDomainFor(grant.role);
    if (domain == null) {
      return const ConsentRevocationOutcome(
        localRevoked: true,
        serverConfirmed: false,
        queuedForRetry: false,
      );
    }

    final serverConfirmed = await _coordinator.revokeOnServer(
      tokenId: grant.grantId,
      domain: domain,
      token: tokenJson,
    );
    await _recordServerOutcomeInAudit(
      prefs: prefs,
      entryId: auditEntryId,
      serverConfirmed: serverConfirmed,
    );

    return ConsentRevocationOutcome(
      localRevoked: true,
      serverConfirmed: serverConfirmed,
      queuedForRetry: !serverConfirmed,
      failureCode: serverConfirmed
          ? null
          : PendingConsentRevocationStore.entryFor(grant.grantId)?.lastError,
    );
  }

  /// Asks the server to replace [grant] with a fresh caregiver window, on the
  /// strength of a confirmation the archive owner just gave.
  ///
  /// This is the surface an owner-confirmation prompt calls, and the shape is
  /// the opposite of [revokeGrant] on purpose. Revoking takes effect on the
  /// device first and syncs afterwards, because the user's decision to end
  /// access should not wait for a network. Renewing does nothing locally until
  /// the server has confirmed, because a device cannot mint a credential the
  /// server will honour, and pretending otherwise would show someone a live
  /// arrangement that is not.
  ///
  /// [ownerConfirmedAt] must be the moment the owner confirmed, not the moment
  /// this was called. The server rejects a confirmation more than a few
  /// minutes old.
  ///
  /// Never throws. On any refusal the previous grant is left exactly as it
  /// was, and nothing is scheduled to try again.
  Future<ConsentRenewalOutcome> renewGrant(
    MultiPartyAccessGrant grant, {
    required DateTime ownerConfirmedAt,
  }) async {
    final prefs = _prefs;
    if (prefs == null) return ConsentRenewalOutcome.notAttempted;

    if (grant.role != MultiPartyAccessRole.caregiver) {
      return ConsentRenewalOutcome.refused(
        ConsentRenewalFailureCode.notRenewable,
      );
    }

    // The agreed scope lives in the stored token rather than in any list the
    // server keeps, so a grant this device no longer holds a token for cannot
    // be renewed from here. Granting again is the path that shows the owner
    // the scope and the person before access continues.
    final tokenJson = await _storedTokenFor(prefs, grant);
    if (tokenJson == null) {
      return ConsentRenewalOutcome.refused(
        ConsentRenewalFailureCode.notRenewable,
      );
    }

    final attempt = await _renewalCoordinator.renewOnServer(
      tokenId: grant.grantId,
      token: tokenJson,
      ownerConfirmedAt: ownerConfirmedAt,
    );

    final successor = attempt.successorToken;
    if (!attempt.outcome.renewed || successor == null) {
      return attempt.outcome;
    }

    await _adoptSuccessorGrant(
      prefs: prefs,
      previous: grant,
      successorToken: successor,
      outcome: attempt.outcome,
      ownerConfirmedAt: ownerConfirmedAt,
    );
    return attempt.outcome;
  }

  /// Moves local state onto the successor, after the server has confirmed it.
  ///
  /// The predecessor is added to the local revocation list rather than merely
  /// forgotten: the server has withdrawn it, and a device that kept listing it
  /// would be showing an arrangement that no longer exists alongside the one
  /// that does.
  Future<void> _adoptSuccessorGrant({
    required MobilePrefsStore prefs,
    required MultiPartyAccessGrant previous,
    required Map<String, dynamic> successorToken,
    required ConsentRenewalOutcome outcome,
    required DateTime ownerConfirmedAt,
  }) async {
    await prefs.writeJsonMap(caregiverTokenKey, successorToken);

    // A session validated against the withdrawn token is stale. Clearing the
    // pointer leaves the next caregiver sign-in to establish one against the
    // successor.
    final sessionRaw = await prefs.readJsonMap(caregiverSessionKey);
    if (sessionRaw?['tokenId']?.toString() == previous.grantId) {
      await prefs.writeJsonMap(caregiverSessionKey, {});
    }

    await ConsentRevocationStore.ensureLoaded();
    await ConsentRevocationStore.revoke(previous.grantId);

    await _appendRenewalAudit(
      prefs: prefs,
      previous: previous,
      outcome: outcome,
      ownerConfirmedAt: ownerConfirmedAt,
    );
  }

  /// `observer` has no consent domain on the server and no production writer,
  /// so there is nothing to revoke remotely for it.
  static ConsentRevocationDomain? _revocationDomainFor(
    MultiPartyAccessRole role,
  ) => switch (role) {
    MultiPartyAccessRole.caregiver =>
      ConsentRevocationDomain.caregiverMonitoring,
    MultiPartyAccessRole.coach => ConsentRevocationDomain.coachClient,
    MultiPartyAccessRole.observer => null,
  };

  static String? _tokenKeyFor(MultiPartyAccessRole role) => switch (role) {
        MultiPartyAccessRole.caregiver => caregiverTokenKey,
        MultiPartyAccessRole.coach => coachTokenKey,
        MultiPartyAccessRole.observer => null,
      };

  Future<Map<String, dynamic>?> _storedTokenFor(
    MobilePrefsStore prefs,
    MultiPartyAccessGrant grant,
  ) async {
    final tokenKey = _tokenKeyFor(grant.role);
    if (tokenKey == null) return null;
    final raw = await prefs.readJsonMap(tokenKey);
    if (raw == null || raw.isEmpty) return null;
    if (raw['tokenId']?.toString() != grant.grantId) return null;
    return raw;
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

  Future<List<Map<String, Object?>>> _readAuditEntries(
    MobilePrefsStore prefs,
  ) async {
    final auditRaw = await prefs.readJsonMap(caregiverAuditKey) ?? {};
    return <Map<String, Object?>>[
      ...?((auditRaw['entries'] as List?)
          ?.whereType<Map<Object?, Object?>>()
          .map(Map<String, Object?>.from)),
    ];
  }

  /// Appends the `consent_revoked` row and returns its `entryId`.
  Future<String> _appendRevocationAudit(
    MobilePrefsStore prefs,
    MultiPartyAccessGrant grant,
  ) async {
    final entries = await _readAuditEntries(prefs);
    final entryId =
        'revoke_${grant.grantId}_${DateTime.now().toUtc().millisecondsSinceEpoch}';
    entries.add({
      'entryId': entryId,
      'sessionId': 'settings_consent_panel',
      'action': 'consent_revoked',
      'resourceType': 'consent_token',
      'resourceId': grant.grantId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'metadata': {
        'partyId': grant.partyId,
        'role': grant.role.wireValue,
        // Written pessimistically so the row is already accurate if the
        // process dies before the server answers; patched below when it does.
        'serverRevocationConfirmed': false,
      },
    });
    await prefs.writeJsonMap(caregiverAuditKey, {'entries': entries});
    return entryId;
  }

  /// Records a freshly-issued grant so it appears in [loadActiveGrants] and
  /// can be found again by [revokeGrant] / [renewGrant].
  ///
  /// Two writes: the audit row is the durable history at /consent-audit;
  /// the role-specific token prefs row is what [_storedTokenFor] keys off.
  /// Observer has no token store and no server domain — calling this for
  /// that role is a programming error, not a silent no-op.
  Future<void> recordIssuedGrant({
    required MultiPartyAccessRole role,
    required String partyId,
    required String tokenId,
    required DateTime issuedAt,
    required DateTime expiresAt,
  }) async {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError(
        'MultiPartyAccessService requires prefs to record an issued grant',
      );
    }
    final tokenKey = _tokenKeyFor(role);
    if (tokenKey == null) {
      throw UnsupportedError(
        'recordIssuedGrant has no token store for ${role.wireValue}',
      );
    }

    final entries = await _readAuditEntries(prefs);
    entries.add({
      'entryId': 'grant_${tokenId}_${issuedAt.toUtc().millisecondsSinceEpoch}',
      'sessionId': 'settings_consent_panel',
      'action': 'consent_granted',
      'resourceType': 'consent_token',
      'resourceId': tokenId,
      'timestamp': issuedAt.toUtc().toIso8601String(),
      'metadata': {
        'partyId': partyId,
        'role': role.wireValue,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      },
    });
    await prefs.writeJsonMap(caregiverAuditKey, {'entries': entries});
    await prefs.writeJsonMap(tokenKey, {
      'tokenId': tokenId,
      if (role == MultiPartyAccessRole.caregiver) 'caregiverId': partyId,
      if (role == MultiPartyAccessRole.coach) 'coachId': partyId,
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    });
  }

  /// Records that the owner confirmed a renewal and the server acted on it.
  ///
  /// Both grant ids are written because the row has to explain a replacement,
  /// not just an event: a later reader needs to see which window ended and
  /// which one took its place. Timestamps and ids only — no server message and
  /// no free text.
  Future<void> _appendRenewalAudit({
    required MobilePrefsStore prefs,
    required MultiPartyAccessGrant previous,
    required ConsentRenewalOutcome outcome,
    required DateTime ownerConfirmedAt,
  }) async {
    final entries = await _readAuditEntries(prefs);
    final now = DateTime.now().toUtc();
    entries.add({
      'entryId': 'renew_${previous.grantId}_${now.millisecondsSinceEpoch}',
      'sessionId': 'settings_consent_panel',
      'action': 'consent_renewed',
      'resourceType': 'consent_token',
      'resourceId': outcome.newGrantId ?? previous.grantId,
      'timestamp': now.toIso8601String(),
      'metadata': {
        'partyId': previous.partyId,
        'role': previous.role.wireValue,
        'supersededGrantId': previous.grantId,
        'ownerConfirmedAt': ownerConfirmedAt.toUtc().toIso8601String(),
        'serverRevocationConfirmed': outcome.previousGrantEnded,
        'expiresAt': outcome.newExpiresAt?.toUtc().toIso8601String(),
      },
    });
    await prefs.writeJsonMap(caregiverAuditKey, {'entries': entries});
  }

  Future<void> _recordServerOutcomeInAudit({
    required MobilePrefsStore prefs,
    required String entryId,
    required bool serverConfirmed,
  }) async {
    if (!serverConfirmed) return;
    final entries = await _readAuditEntries(prefs);
    for (final row in entries) {
      if (row['entryId'] != entryId) continue;
      final metadata = row['metadata'];
      row['metadata'] = {
        ...?(metadata is Map<Object?, Object?>
            ? Map<String, Object?>.from(metadata)
            : null),
        'serverRevocationConfirmed': true,
      };
    }
    await prefs.writeJsonMap(caregiverAuditKey, {'entries': entries});
  }
}

DateTime? _parseUtc(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw)?.toUtc();
}
