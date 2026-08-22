import 'dart:io';

import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/auth/application/server_consent_revocation_coordinator.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/pending_consent_revocation_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_audit_service.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConsentRevocationApi implements ConsentRevocationApiClient {
  _FakeConsentRevocationApi({required this.confirms});

  final bool confirms;

  @override
  Future<ApiResult<ConsentRevocationConfirmation>> revokeConsent({
    required ConsentRevocationDomain domain,
    required String tokenId,
    String? reason,
    Map<String, dynamic>? token,
    NetworkCancelToken? cancelToken,
  }) async {
    if (!confirms) return const ApiFailureResult(ApiFailureOffline());
    return ApiSuccess(
      ConsentRevocationConfirmation(
        tokenId: tokenId,
        revoked: true,
        alreadyRevoked: false,
      ),
    );
  }
}

MonitoringConsentToken _token(String tokenId) => MonitoringConsentToken(
  tokenId: tokenId,
  subjectAccountId: 'subject-1',
  caregiverId: 'caregiver-ada',
  permissions: CaregiverPermissions.defaultScopes,
  issuedAt: DateTime.utc(2026, 6),
  expiresAt: DateTime.utc(2027, 6),
  policyVersion: 1,
  signature: 'server-signature',
);

void main() {
  late Directory sandbox;
  late MobilePrefsStore prefs;

  setUp(() async {
    sandbox = Directory.systemTemp.createTempSync('consent_audit_copy_');
    prefs = await MobilePrefsStore.open('${sandbox.path}/prefs.json');
    await ConsentRevocationStore.resetForTest();
    await PendingConsentRevocationStore.resetForTest();
    ConsentRevocationStore.debugPrefsOverride = prefs;
    PendingConsentRevocationStore.debugPrefsOverride = prefs;
  });

  tearDown(() async {
    await ConsentRevocationStore.resetForTest();
    await PendingConsentRevocationStore.resetForTest();
    ServerConsentRevocationCoordinator.resetForTest();
    sandbox.deleteSync(recursive: true);
  });

  Future<ConsentGrantRecord> storedCaregiverGrant(String tokenId) async {
    await CaregiverModeStore(prefs).writeStoredToken(_token(tokenId));
    final grants = await ConsentAuditService(
      prefs: prefs,
    ).loadGrants(now: DateTime.utc(2026, 7));
    return grants.single;
  }

  ConsentAuditService serviceThatServerConfirms({required bool confirms}) =>
      ConsentAuditService(
        prefs: prefs,
        serverRevocations: ServerConsentRevocationCoordinator(
          api: _FakeConsentRevocationApi(confirms: confirms),
        ),
      );

  group('the revoke snack reports which half of revocation landed', () {
    test('a confirmed revoke reports the server too', () async {
      final record = await storedCaregiverGrant('token-confirmed');

      final outcome = await serviceThatServerConfirms(
        confirms: true,
      ).revokeGrant(record);

      expect(outcome.localRevoked, isTrue);
      expect(outcome.serverConfirmed, isTrue);
      expect(
        ConsentAuditCopy.revokedSnackFor(outcome),
        ConsentAuditCopy.revokedSnack,
      );
    });

    test('an unsent revoke says so rather than claiming the server', () async {
      final record = await storedCaregiverGrant('token-offline');

      final outcome = await serviceThatServerConfirms(
        confirms: false,
      ).revokeGrant(record);

      expect(
        outcome.localRevoked,
        isTrue,
        reason: 'the local half is not gated on the network',
      );
      expect(outcome.serverConfirmed, isFalse);
      expect(outcome.queuedForRetry, isTrue);
      expect(
        ConsentAuditCopy.revokedSnackFor(outcome),
        ConsentAuditCopy.revokedQueuedSnack,
        reason: 'telling an offline user the server has stopped honouring the '
            'token is the one claim on this screen they would act on',
      );
    });

    test('the queued snack does not claim the server has stopped', () {
      final queued = ConsentAuditCopy.revokedQueuedSnack.toLowerCase();

      expect(queued, contains('here'));
      expect(
        queued,
        anyOf(contains('will finish'), contains('online')),
        reason: 'the sentence has to say the server half is still owed',
      );
    });

    test('the confirmed snack names both halves', () {
      final confirmed = ConsentAuditCopy.revokedSnack.toLowerCase();

      expect(confirmed, contains('here'));
      expect(confirmed, contains('server'));
    });
  });
}
