import 'dart:io';

import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/application/server_consent_revocation_coordinator.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/pending_consent_revocation_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/coach/coach_mode_store.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_audit_service.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Responder =
    ApiResult<ConsentRevocationConfirmation> Function(
      String tokenId,
      int callIndex,
    );

class _RecordedRevoke {
  const _RecordedRevoke({
    required this.domain,
    required this.tokenId,
    required this.reason,
    required this.token,
  });

  final ConsentRevocationDomain domain;
  final String tokenId;
  final String? reason;
  final Map<String, dynamic>? token;
}

class _FakeConsentRevocationApi implements ConsentRevocationApiClient {
  _FakeConsentRevocationApi(this.respond);

  _Responder respond;
  final List<_RecordedRevoke> calls = [];

  @override
  Future<ApiResult<ConsentRevocationConfirmation>> revokeConsent({
    required ConsentRevocationDomain domain,
    required String tokenId,
    String? reason,
    Map<String, dynamic>? token,
    NetworkCancelToken? cancelToken,
  }) async {
    calls.add(
      _RecordedRevoke(
        domain: domain,
        tokenId: tokenId,
        reason: reason,
        token: token,
      ),
    );
    return respond(tokenId, calls.length - 1);
  }
}

_Responder _alwaysConfirm({bool alreadyRevoked = false}) =>
    (tokenId, _) => ApiSuccess(
      ConsentRevocationConfirmation(
        tokenId: tokenId,
        revoked: !alreadyRevoked,
        alreadyRevoked: alreadyRevoked,
      ),
    );

_Responder _alwaysFail(ApiFailure failure) =>
    (_, _) => ApiFailureResult(failure);

const _offline = ApiFailureOffline();
const _unavailable = ApiFailureServer(
  message: 'revocation store unavailable',
  statusCode: 503,
  serverCode: 'CONSENT_REVOKE_FAILED',
);
const _forbidden = ApiFailureServer(
  message: 'not the archive owner',
  statusCode: 403,
  serverCode: 'FORBIDDEN',
);

MonitoringConsentToken _caregiverToken(String tokenId) =>
    MonitoringConsentToken(
      tokenId: tokenId,
      subjectAccountId: 'subject-1',
      caregiverId: 'caregiver-ada',
      permissions: CaregiverPermissions.defaultScopes,
      issuedAt: DateTime.utc(2026, 6),
      expiresAt: DateTime.utc(2027, 6),
      policyVersion: 1,
      signature: 'server-signature',
    );

CoachConsentToken _coachToken(String tokenId) => CoachConsentToken(
  tokenId: tokenId,
  relationshipId: 'rel-1',
  clientAccountId: 'subject-1',
  coachId: 'coach-lee',
  permissions: CoachSharingPermissions.defaults,
  issuedAt: DateTime.utc(2026, 6),
  expiresAt: DateTime.utc(2027, 6),
  policyVersion: 1,
  clientAffirmationHash: 'affirmation-hash',
  signature: 'server-signature',
);

MultiPartyAccessGrant _grant(String id, MultiPartyAccessRole role) =>
    MultiPartyAccessGrant(
      grantId: id,
      partyId: role == MultiPartyAccessRole.caregiver
          ? 'caregiver-ada'
          : 'coach-lee',
      role: role,
      grantedAt: DateTime.utc(2026, 6),
    );

void main() {
  late Directory sandbox;
  late MobilePrefsStore prefs;
  late _FakeConsentRevocationApi api;
  late ServerConsentRevocationCoordinator coordinator;

  setUp(() async {
    sandbox = Directory.systemTemp.createTempSync('server_consent_revocation_');
    prefs = await MobilePrefsStore.open('${sandbox.path}/prefs.json');
    await ConsentRevocationStore.resetForTest();
    await PendingConsentRevocationStore.resetForTest();
    ConsentRevocationStore.debugPrefsOverride = prefs;
    PendingConsentRevocationStore.debugPrefsOverride = prefs;
    api = _FakeConsentRevocationApi(_alwaysConfirm());
    coordinator = ServerConsentRevocationCoordinator(api: api);
  });

  tearDown(() async {
    await ConsentRevocationStore.resetForTest();
    await PendingConsentRevocationStore.resetForTest();
    ServerConsentRevocationCoordinator.resetForTest();
    sandbox.deleteSync(recursive: true);
  });

  MultiPartyAccessService service() =>
      MultiPartyAccessService(prefs: prefs, serverRevocations: coordinator);

  Future<List<Map<String, Object?>>> auditEntries() async {
    final raw = await prefs.readJsonMap(MultiPartyAccessService.caregiverAuditKey);
    final rows = raw?['entries'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, Object?>.from)
        .toList();
  }

  Map<String, Object?>? revocationMetadata(
    List<Map<String, Object?>> rows,
    String grantId,
  ) {
    for (final row in rows) {
      if (row['action'] != 'consent_revoked') continue;
      if (row['resourceId'] != grantId) continue;
      final metadata = row['metadata'];
      if (metadata is Map<Object?, Object?>) {
        return Map<String, Object?>.from(metadata);
      }
    }
    return null;
  }

  group('MultiPartyAccessService.revokeGrant reaches the server', () {
    test('caregiver grant sends caregiverMonitoring and the held token', () async {
      await prefs.writeJsonMap(
        MultiPartyAccessService.caregiverTokenKey,
        _caregiverToken('token-care-1').toJson(),
      );

      final outcome = await service().revokeGrant(
        _grant('token-care-1', MultiPartyAccessRole.caregiver),
      );

      expect(api.calls, hasLength(1));
      expect(api.calls.single.domain, ConsentRevocationDomain.caregiverMonitoring);
      expect(api.calls.single.tokenId, 'token-care-1');
      expect(api.calls.single.token?['signature'], 'server-signature');

      expect(outcome.localRevoked, isTrue);
      expect(outcome.serverConfirmed, isTrue);
      expect(outcome.queuedForRetry, isFalse);
      expect(PendingConsentRevocationStore.entries, isEmpty);
      expect(
        revocationMetadata(await auditEntries(), 'token-care-1')?['serverRevocationConfirmed'],
        isTrue,
      );
      expect(await service().loadActiveGrants(now: DateTime.utc(2026, 7)), isEmpty);
    });

    test('coach grant sends coachClient', () async {
      await prefs.writeJsonMap(
        MultiPartyAccessService.coachTokenKey,
        _coachToken('token-coach-1').toJson(),
      );

      await service().revokeGrant(
        _grant('token-coach-1', MultiPartyAccessRole.coach),
      );

      expect(api.calls.single.domain, ConsentRevocationDomain.coachClient);
      expect(api.calls.single.tokenId, 'token-coach-1');
      expect(api.calls.single.token?['coachId'], 'coach-lee');
    });
  });

  group('offline revocation still takes effect locally', () {
    test('network failure keeps the local revoke and queues the server call', () async {
      api.respond = _alwaysFail(_offline);
      await prefs.writeJsonMap(
        MultiPartyAccessService.caregiverTokenKey,
        _caregiverToken('token-offline').toJson(),
      );
      await prefs.writeJsonMap(MultiPartyAccessService.caregiverSessionKey, {
        'tokenId': 'token-offline',
      });

      final outcome = await service().revokeGrant(
        _grant('token-offline', MultiPartyAccessRole.caregiver),
      );

      expect(ConsentRevocationStore.isRevoked('token-offline'), isTrue);
      expect(
        await prefs.readJsonMap(MultiPartyAccessService.caregiverTokenKey),
        isEmpty,
      );
      expect(
        await prefs.readJsonMap(MultiPartyAccessService.caregiverSessionKey),
        isEmpty,
      );
      expect(
        revocationMetadata(await auditEntries(), 'token-offline'),
        isNotNull,
        reason: 'the local audit row must not depend on the network',
      );

      expect(outcome.localRevoked, isTrue);
      expect(outcome.serverConfirmed, isFalse);
      expect(outcome.queuedForRetry, isTrue);
      expect(outcome.isLocalOnly, isTrue);

      final queued = PendingConsentRevocationStore.entries.single;
      expect(queued.tokenId, 'token-offline');
      expect(queued.domain, ConsentRevocationDomain.caregiverMonitoring);
      expect(queued.lastError, ConsentRevocationFailureCode.network);
      expect(queued.attempts, 1);
    });

    test('a 503 is queued and cleared once flushPending succeeds', () async {
      api.respond = _alwaysFail(_unavailable);

      await service().revokeGrant(
        _grant('token-503', MultiPartyAccessRole.caregiver),
      );
      expect(
        PendingConsentRevocationStore.entries.single.lastError,
        ConsentRevocationFailureCode.serverUnavailable,
      );

      api.respond = _alwaysConfirm();
      await coordinator.flushPending();

      expect(api.calls, hasLength(2));
      expect(PendingConsentRevocationStore.entries, isEmpty);
    });

    test('alreadyRevoked clears the queue entry', () async {
      api.respond = _alwaysFail(_offline);
      await service().revokeGrant(
        _grant('token-already', MultiPartyAccessRole.caregiver),
      );
      expect(PendingConsentRevocationStore.entries, hasLength(1));

      api.respond = _alwaysConfirm(alreadyRevoked: true);
      await coordinator.flushPending();

      expect(PendingConsentRevocationStore.entries, isEmpty);
    });

    test('a queued revocation survives a restart and is retried', () async {
      api.respond = _alwaysFail(_offline);
      await service().revokeGrant(
        _grant('token-restart', MultiPartyAccessRole.coach),
      );

      // Same prefs file, fresh process: in-memory state is gone, disk is not.
      PendingConsentRevocationStore.debugForgetLoadedState();
      await PendingConsentRevocationStore.ensureLoaded();

      final reloaded = PendingConsentRevocationStore.entries.single;
      expect(reloaded.tokenId, 'token-restart');
      expect(reloaded.domain, ConsentRevocationDomain.coachClient);

      api.respond = _alwaysConfirm();
      await ServerConsentRevocationCoordinator(api: api).flushPending();

      expect(PendingConsentRevocationStore.entries, isEmpty);
      expect(
        api.calls.last.token,
        isNull,
        reason: 'the signed token is deliberately not persisted across a restart',
      );
    });
  });

  group('permanent rejections are kept, not retried away', () {
    test('a 403 stops being retried but stays in the queue', () async {
      api.respond = _alwaysFail(_forbidden);

      final outcome = await service().revokeGrant(
        _grant('token-403', MultiPartyAccessRole.caregiver),
      );

      expect(outcome.localRevoked, isTrue);
      expect(outcome.failureCode, ConsentRevocationFailureCode.forbidden);
      final queued = PendingConsentRevocationStore.entries.single;
      expect(queued.isPermanentlyRejected, isTrue);

      await coordinator.flushPending();
      await coordinator.flushPending();

      expect(
        api.calls,
        hasLength(1),
        reason: 'a permanently rejected revoke must not be retried forever',
      );
      expect(
        PendingConsentRevocationStore.entries.single.tokenId,
        'token-403',
        reason: 'the unfinished revocation must remain visible',
      );
      expect(
        ConsentRevocationStore.isRevoked('token-403'),
        isTrue,
        reason: 'a server refusal never undoes the local revocation',
      );
    });
  });

  group('PendingConsentRevocationStore', () {
    test('enqueuing the same grant twice yields one entry', () async {
      api.respond = _alwaysFail(_offline);
      final grant = _grant('token-twice', MultiPartyAccessRole.caregiver);

      await service().revokeGrant(grant);
      await service().revokeGrant(grant);

      expect(PendingConsentRevocationStore.entries, hasLength(1));
      expect(PendingConsentRevocationStore.entries.single.attempts, 2);
    });

    test('persisting merges with a concurrent writer instead of clobbering', () async {
      await PendingConsentRevocationStore.ensureLoaded();
      await PendingConsentRevocationStore.enqueue(
        tokenId: 'token-mine',
        domain: ConsentRevocationDomain.caregiverMonitoring,
      );

      // Stands in for another holder of the key persisting a view this one has
      // never seen — a second isolate, or a store loaded before this enqueue.
      final onDisk = await prefs.readJsonMap(
        PendingConsentRevocationStore.prefsKey,
      );
      await prefs.writeJsonMap(PendingConsentRevocationStore.prefsKey, {
        'entries': <Object?>[
          ...?(onDisk?['entries'] as List?),
          {
            'tokenId': 'token-out-of-band',
            'domain': 'coachClient',
            'queuedAt': '2026-08-01T00:00:00.000Z',
            'attempts': 3,
          },
        ],
      });

      await PendingConsentRevocationStore.enqueue(
        tokenId: 'token-later',
        domain: ConsentRevocationDomain.caregiverMonitoring,
      );

      expect(
        PendingConsentRevocationStore.entries.map((e) => e.tokenId),
        containsAll(<String>['token-mine', 'token-out-of-band', 'token-later']),
      );
    });

    test('a confirmed entry is not resurrected by a stale on-disk copy', () async {
      await PendingConsentRevocationStore.enqueue(
        tokenId: 'token-settled',
        domain: ConsentRevocationDomain.caregiverMonitoring,
      );
      await PendingConsentRevocationStore.confirmRevoked('token-settled');

      // Another writer still holding the pre-confirmation view writes it back.
      await prefs.writeJsonMap(PendingConsentRevocationStore.prefsKey, {
        'entries': <Object?>[
          {
            'tokenId': 'token-settled',
            'domain': 'caregiverMonitoring',
            'queuedAt': '2026-08-01T00:00:00.000Z',
            'attempts': 1,
          },
        ],
      });

      await PendingConsentRevocationStore.enqueue(
        tokenId: 'token-other',
        domain: ConsentRevocationDomain.caregiverMonitoring,
      );

      expect(
        PendingConsentRevocationStore.entries.map((e) => e.tokenId),
        ['token-other'],
      );
    });
  });

  group('ConsentAuditService.revokeGrant reaches the server', () {
    test('caregiver grants revoke with the caregiverMonitoring domain', () async {
      final store = CaregiverModeStore(prefs);
      await store.writeStoredToken(_caregiverToken('token-audit-care'));
      final audit = ConsentAuditService(prefs: prefs, serverRevocations: coordinator);

      final record = (await audit.loadGrants(now: DateTime.utc(2026, 7))).single;
      await audit.revokeGrant(record);

      expect(api.calls.single.domain, ConsentRevocationDomain.caregiverMonitoring);
      expect(api.calls.single.tokenId, 'token-audit-care');
      expect(api.calls.single.token?['signature'], 'server-signature');
      expect(ConsentRevocationStore.isRevoked('token-audit-care'), isTrue);
    });

    test('coach grants revoke with the coachClient domain', () async {
      await CoachModeStore(prefs).writeStoredToken(_coachToken('token-audit-coach'));
      final audit = ConsentAuditService(prefs: prefs, serverRevocations: coordinator);

      final record = (await audit.loadGrants(now: DateTime.utc(2026, 7))).single;
      await audit.revokeGrant(record);

      expect(api.calls.single.domain, ConsentRevocationDomain.coachClient);
      expect(api.calls.single.tokenId, 'token-audit-coach');
      expect(ConsentRevocationStore.isRevoked('token-audit-coach'), isTrue);
    });

    test('an offline coach revoke is still queued for the server', () async {
      api.respond = _alwaysFail(_offline);
      await CoachModeStore(prefs).writeStoredToken(_coachToken('token-audit-offline'));
      final audit = ConsentAuditService(prefs: prefs, serverRevocations: coordinator);

      final record = (await audit.loadGrants(now: DateTime.utc(2026, 7))).single;
      await audit.revokeGrant(record);

      expect(ConsentRevocationStore.isRevoked('token-audit-offline'), isTrue);
      expect(
        PendingConsentRevocationStore.entries.single.domain,
        ConsentRevocationDomain.coachClient,
      );
    });
  });

  group('the coordinator degrades rather than throwing', () {
    test('with no api client the revocation is queued, not lost', () async {
      final queueOnly = ServerConsentRevocationCoordinator();

      final confirmed = await queueOnly.revokeOnServer(
        tokenId: 'token-no-backend',
        domain: ConsentRevocationDomain.caregiverMonitoring,
      );

      expect(confirmed, isFalse);
      expect(
        PendingConsentRevocationStore.entries.single.lastError,
        ConsentRevocationFailureCode.backendNotConfigured,
      );
    });
  });
}
