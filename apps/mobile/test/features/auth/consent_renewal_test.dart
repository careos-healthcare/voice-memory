import 'dart:io';

import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/consent_renewal_api_client.dart';
import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/application/server_consent_renewal_coordinator.dart';
import 'package:archiveme_mobile/features/auth/application/server_consent_revocation_coordinator.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_renewal_outcome.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/pending_consent_revocation_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner-confirmed renewal, from the service surface a confirmation prompt
/// would call down to the outcome it reports back.
///
/// The two properties these tests exist to hold, both of which are ways a
/// 7-day window could quietly stop meaning 7 days:
///
/// - nothing local moves onto a successor until the server has said the
///   predecessor is withdrawn, so the device cannot show one live arrangement
///   while two credentials exist;
/// - a renewal that does not land is dropped rather than queued, so no later
///   flush can extend access at a moment nobody was asked about.

class _RecordedRenewal {
  const _RecordedRenewal({
    required this.tokenId,
    required this.token,
    required this.ownerConfirmedAt,
  });

  final String tokenId;
  final Map<String, dynamic> token;
  final DateTime ownerConfirmedAt;
}

typedef _Responder =
    ApiResult<ConsentRenewalConfirmation> Function(String tokenId);

class _FakeConsentRenewalApi implements ConsentRenewalApiClient {
  _FakeConsentRenewalApi(this.respond);

  _Responder respond;
  final List<_RecordedRenewal> calls = [];

  @override
  Future<ApiResult<ConsentRenewalConfirmation>> renewCaregiverConsent({
    required String tokenId,
    required Map<String, dynamic> token,
    required DateTime ownerConfirmedAt,
    NetworkCancelToken? cancelToken,
  }) async {
    calls.add(
      _RecordedRenewal(
        tokenId: tokenId,
        token: token,
        ownerConfirmedAt: ownerConfirmedAt,
      ),
    );
    return respond(tokenId);
  }
}

class _ThrowingRenewalApi implements ConsentRenewalApiClient {
  @override
  Future<ApiResult<ConsentRenewalConfirmation>> renewCaregiverConsent({
    required String tokenId,
    required Map<String, dynamic> token,
    required DateTime ownerConfirmedAt,
    NetworkCancelToken? cancelToken,
  }) async => throw StateError('transport exploded');
}

MonitoringConsentToken _caregiverToken(
  String tokenId, {
  DateTime? issuedAt,
  DateTime? expiresAt,
}) => MonitoringConsentToken(
  tokenId: tokenId,
  subjectAccountId: 'subject-1',
  caregiverId: 'caregiver-ada',
  permissions: CaregiverPermissions.defaultScopes,
  issuedAt: issuedAt ?? DateTime.utc(2026, 6),
  expiresAt: expiresAt ?? DateTime.utc(2026, 6, 8),
  policyVersion: 1,
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

_Responder _confirms(
  MonitoringConsentToken successor, {
  bool withdrewPredecessor = true,
}) =>
    (tokenId) => ApiSuccess(
      ConsentRenewalConfirmation(
        token: successor,
        previousTokenId: tokenId,
        previousRevokedAt: withdrewPredecessor
            ? DateTime.utc(2026, 6, 7, 9)
            : null,
        ownerConfirmedAt: DateTime.utc(2026, 6, 7, 9),
      ),
    );

_Responder _fails(ApiFailure failure) => (_) => ApiFailureResult(failure);

const _offline = ApiFailureOffline();
const _forbidden = ApiFailureServer(
  message: 'You do not have permission to perform this action.',
  statusCode: 403,
  serverCode: 'FORBIDDEN',
);
const _lapsed = ApiFailureServer(
  message: 'This access window has ended. Granting access again starts a new one.',
  statusCode: 409,
  serverCode: 'GRANT_EXPIRED',
);
const _notRenewable = ApiFailureServer(
  message: 'This access grant cannot be renewed as it stands.',
  statusCode: 409,
  serverCode: 'GRANT_NOT_RENEWABLE',
);
const _confirmationRequired = ApiFailureServer(
  message: 'Renewing this access needs a fresh confirmation from its owner.',
  statusCode: 400,
  serverCode: 'OWNER_CONFIRMATION_REQUIRED',
);
const _renewalFailed = ApiFailureServer(
  message: 'Renewal did not finish on the server.',
  statusCode: 503,
  serverCode: 'CONSENT_RENEWAL_FAILED',
);
const _authRequired = ApiFailureAuthRequired();

/// Every value the outcome type is allowed to carry off the network.
const _closedFailureCodes = <String>{
  ConsentRenewalFailureCode.backendNotConfigured,
  ConsentRenewalFailureCode.network,
  ConsentRenewalFailureCode.authRequired,
  ConsentRenewalFailureCode.notGrantOwner,
  ConsentRenewalFailureCode.confirmationRequired,
  ConsentRenewalFailureCode.grantExpired,
  ConsentRenewalFailureCode.notRenewable,
  ConsentRenewalFailureCode.serverUnavailable,
  ConsentRenewalFailureCode.notConfirmed,
};

void main() {
  late Directory sandbox;
  late MobilePrefsStore prefs;
  late _FakeConsentRenewalApi api;
  late ServerConsentRenewalCoordinator coordinator;
  late MonitoringConsentToken successor;

  final confirmedAt = DateTime.utc(2026, 6, 7, 8, 59);

  setUp(() async {
    sandbox = Directory.systemTemp.createTempSync('consent_renewal_');
    prefs = await MobilePrefsStore.open('${sandbox.path}/prefs.json');
    await ConsentRevocationStore.resetForTest();
    await PendingConsentRevocationStore.resetForTest();
    ConsentRevocationStore.debugPrefsOverride = prefs;
    PendingConsentRevocationStore.debugPrefsOverride = prefs;
    successor = _caregiverToken(
      'token-care-2',
      issuedAt: DateTime.utc(2026, 6, 7, 9),
      expiresAt: DateTime.utc(2026, 6, 14, 9),
    );
    api = _FakeConsentRenewalApi(_confirms(successor));
    coordinator = ServerConsentRenewalCoordinator(api: api);
  });

  tearDown(() async {
    await ConsentRevocationStore.resetForTest();
    await PendingConsentRevocationStore.resetForTest();
    ServerConsentRenewalCoordinator.resetForTest();
    ServerConsentRevocationCoordinator.resetForTest();
    sandbox.deleteSync(recursive: true);
  });

  MultiPartyAccessService service() => MultiPartyAccessService(
    prefs: prefs,
    serverRevocations: ServerConsentRevocationCoordinator(),
    serverRenewals: coordinator,
  );

  Future<void> storeCaregiverToken(String tokenId) => prefs.writeJsonMap(
    MultiPartyAccessService.caregiverTokenKey,
    _caregiverToken(tokenId).toJson(),
  );

  Future<List<Map<String, Object?>>> auditEntries() async {
    final raw = await prefs.readJsonMap(
      MultiPartyAccessService.caregiverAuditKey,
    );
    final rows = raw?['entries'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, Object?>.from)
        .toList();
  }

  group('the owner renews and the device moves onto the successor', () {
    test('the held token is presented and the confirmation carried', () async {
      await storeCaregiverToken('token-care-1');

      final outcome = await service().renewGrant(
        _grant('token-care-1', MultiPartyAccessRole.caregiver),
        ownerConfirmedAt: confirmedAt,
      );

      expect(api.calls, hasLength(1));
      expect(api.calls.single.tokenId, 'token-care-1');
      expect(api.calls.single.token['signature'], 'server-signature');
      expect(
        api.calls.single.ownerConfirmedAt,
        confirmedAt,
        reason: 'the moment the owner confirmed, not the moment we called',
      );

      expect(outcome.renewed, isTrue);
      expect(outcome.previousGrantEnded, isTrue);
      expect(outcome.isUnsettled, isFalse);
      expect(outcome.newGrantId, 'token-care-2');
      expect(outcome.newExpiresAt, DateTime.utc(2026, 6, 14, 9));
      expect(outcome.failureCode, isNull);
    });

    test('the previous grant stops being listed and the successor takes over', () async {
      await storeCaregiverToken('token-care-1');

      await service().renewGrant(
        _grant('token-care-1', MultiPartyAccessRole.caregiver),
        ownerConfirmedAt: confirmedAt,
      );

      expect(
        ConsentRevocationStore.isRevoked('token-care-1'),
        isTrue,
        reason: 'the server withdrew it, so this device must stop listing it',
      );
      expect(
        (await prefs.readJsonMap(MultiPartyAccessService.caregiverTokenKey))?['tokenId'],
        'token-care-2',
      );

      final grants = await service().loadActiveGrants(
        now: DateTime.utc(2026, 6, 10),
      );
      expect(grants.map((g) => g.grantId), ['token-care-2']);
    });

    test('a session bound to the withdrawn token is cleared', () async {
      await storeCaregiverToken('token-care-1');
      await prefs.writeJsonMap(MultiPartyAccessService.caregiverSessionKey, {
        'tokenId': 'token-care-1',
      });

      await service().renewGrant(
        _grant('token-care-1', MultiPartyAccessRole.caregiver),
        ownerConfirmedAt: confirmedAt,
      );

      expect(
        await prefs.readJsonMap(MultiPartyAccessService.caregiverSessionKey),
        isEmpty,
      );
    });

    test('the audit row names both windows and carries no free text', () async {
      await storeCaregiverToken('token-care-1');

      await service().renewGrant(
        _grant('token-care-1', MultiPartyAccessRole.caregiver),
        ownerConfirmedAt: confirmedAt,
      );

      final row = (await auditEntries())
          .firstWhere((entry) => entry['action'] == 'consent_renewed');
      expect(row['resourceId'], 'token-care-2');
      final metadata = Map<String, Object?>.from(
        row['metadata']! as Map<Object?, Object?>,
      );
      expect(metadata['supersededGrantId'], 'token-care-1');
      expect(metadata['ownerConfirmedAt'], confirmedAt.toIso8601String());
      expect(metadata['serverRevocationConfirmed'], isTrue);
      expect(
        metadata.keys.toSet(),
        {
          'partyId',
          'role',
          'supersededGrantId',
          'ownerConfirmedAt',
          'serverRevocationConfirmed',
          'expiresAt',
        },
        reason:
            'ids, a role and timestamps — a server message has no field to '
            'arrive in',
      );
    });
  });

  group('nothing moves until the server confirms the swap', () {
    test('a refusal leaves the previous grant exactly as it was', () async {
      api.respond = _fails(_forbidden);
      await storeCaregiverToken('token-care-1');

      final outcome = await service().renewGrant(
        _grant('token-care-1', MultiPartyAccessRole.caregiver),
        ownerConfirmedAt: confirmedAt,
      );

      expect(outcome.renewed, isFalse);
      expect(outcome.previousGrantEnded, isFalse);
      expect(outcome.failureCode, ConsentRenewalFailureCode.notGrantOwner);
      expect(ConsentRevocationStore.isRevoked('token-care-1'), isFalse);
      expect(
        (await prefs.readJsonMap(MultiPartyAccessService.caregiverTokenKey))?['tokenId'],
        'token-care-1',
      );
      expect(
        (await auditEntries()).where((e) => e['action'] == 'consent_renewed'),
        isEmpty,
      );
    });

    test(
      'a successor whose predecessor was not withdrawn is not adopted',
      () async {
        api.respond = _confirms(successor, withdrewPredecessor: false);
        await storeCaregiverToken('token-care-1');

        final outcome = await service().renewGrant(
          _grant('token-care-1', MultiPartyAccessRole.caregiver),
          ownerConfirmedAt: confirmedAt,
        );

        expect(
          outcome.renewed,
          isFalse,
          reason:
              'without a withdrawal the response describes two live credentials, not a replacement',
        );
        expect(outcome.failureCode, ConsentRenewalFailureCode.notConfirmed);
        expect(
          (await prefs.readJsonMap(MultiPartyAccessService.caregiverTokenKey))?['tokenId'],
          'token-care-1',
        );
        expect(ConsentRevocationStore.isRevoked('token-care-1'), isFalse);
      },
    );

    test('a renewal is never queued for a later retry', () async {
      api.respond = _fails(_offline);
      await storeCaregiverToken('token-care-1');

      await service().renewGrant(
        _grant('token-care-1', MultiPartyAccessRole.caregiver),
        ownerConfirmedAt: confirmedAt,
      );

      await PendingConsentRevocationStore.ensureLoaded();
      expect(
        PendingConsentRevocationStore.entries,
        isEmpty,
        reason:
            'a queued renewal would extend access at a moment the owner was not asked',
      );
    });
  });

  group('what cannot be renewed from here', () {
    test('a grant this device holds no token for is refused locally', () async {
      final outcome = await service().renewGrant(
        _grant('token-unknown', MultiPartyAccessRole.caregiver),
        ownerConfirmedAt: confirmedAt,
      );

      expect(outcome.renewed, isFalse);
      expect(outcome.failureCode, ConsentRenewalFailureCode.notRenewable);
      expect(outcome.shouldOfferFreshGrant, isTrue);
      expect(api.calls, isEmpty, reason: 'no scope to renew, so nothing to ask');
    });

    test('a coach grant is refused without reaching the server', () async {
      final outcome = await service().renewGrant(
        _grant('token-coach-1', MultiPartyAccessRole.coach),
        ownerConfirmedAt: confirmedAt,
      );

      expect(outcome.renewed, isFalse);
      expect(outcome.failureCode, ConsentRenewalFailureCode.notRenewable);
      expect(api.calls, isEmpty);
    });
  });

  group('the outcome reports each state honestly', () {
    final cases = <String, (ApiFailure, String)>{
      'a lapsed window points at granting again': (
        _lapsed,
        ConsentRenewalFailureCode.grantExpired,
      ),
      'a withdrawn grant is settled, not retryable': (
        _notRenewable,
        ConsentRenewalFailureCode.notRenewable,
      ),
      'a missing confirmation asks for one': (
        _confirmationRequired,
        ConsentRenewalFailureCode.confirmationRequired,
      ),
      'an incomplete swap is a server problem': (
        _renewalFailed,
        ConsentRenewalFailureCode.serverUnavailable,
      ),
      'a lapsed session asks for sign-in': (
        _authRequired,
        ConsentRenewalFailureCode.authRequired,
      ),
      'no connection is a network answer': (
        _offline,
        ConsentRenewalFailureCode.network,
      ),
    };

    cases.forEach((name, expectation) {
      test(name, () async {
        final (failure, expectedCode) = expectation;
        api.respond = _fails(failure);
        await storeCaregiverToken('token-care-1');

        final outcome = await service().renewGrant(
          _grant('token-care-1', MultiPartyAccessRole.caregiver),
          ownerConfirmedAt: confirmedAt,
        );

        expect(outcome.failureCode, expectedCode);
        expect(
          _closedFailureCodes,
          contains(outcome.failureCode),
          reason: 'only codes from the closed set may reach local storage',
        );
        expect(
          outcome.failureCode,
          isNot(contains(' ')),
          reason: 'a server message must never become the failure code',
        );
      });
    });

    test('shouldOfferFreshGrant tracks the two settled answers', () {
      expect(
        ConsentRenewalOutcome.refused(
          ConsentRenewalFailureCode.grantExpired,
        ).shouldOfferFreshGrant,
        isTrue,
      );
      expect(
        ConsentRenewalOutcome.refused(
          ConsentRenewalFailureCode.notRenewable,
        ).shouldOfferFreshGrant,
        isTrue,
      );
      expect(
        ConsentRenewalOutcome.refused(
          ConsentRenewalFailureCode.network,
        ).shouldOfferFreshGrant,
        isFalse,
      );
      expect(ConsentRenewalOutcome.notAttempted.shouldOfferFreshGrant, isFalse);
    });
  });

  group('the coordinator degrades rather than throwing', () {
    test('a throwing client leaves the grant untouched', () async {
      coordinator = ServerConsentRenewalCoordinator(api: _ThrowingRenewalApi());
      await storeCaregiverToken('token-care-1');

      final outcome = await service().renewGrant(
        _grant('token-care-1', MultiPartyAccessRole.caregiver),
        ownerConfirmedAt: confirmedAt,
      );

      expect(outcome.renewed, isFalse);
      expect(outcome.failureCode, ConsentRenewalFailureCode.network);
      expect(ConsentRevocationStore.isRevoked('token-care-1'), isFalse);
    });

    test('with no client at all renewal is reported unavailable', () async {
      final attempt = await ServerConsentRenewalCoordinator().renewOnServer(
        tokenId: 'token-care-1',
        token: const {'tokenId': 'token-care-1'},
        ownerConfirmedAt: confirmedAt,
      );

      expect(attempt.outcome.renewed, isFalse);
      expect(
        attempt.outcome.failureCode,
        ConsentRenewalFailureCode.backendNotConfigured,
      );
      expect(attempt.successorToken, isNull);
    });

    test('a blank grant id is not attempted', () async {
      final attempt = await coordinator.renewOnServer(
        tokenId: '   ',
        token: const {},
        ownerConfirmedAt: confirmedAt,
      );

      expect(attempt.outcome.renewed, isFalse);
      expect(attempt.outcome.failureCode, isNull);
      expect(api.calls, isEmpty);
    });
  });
}
