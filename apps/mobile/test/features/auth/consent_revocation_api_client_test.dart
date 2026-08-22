import 'dart:convert';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/data/network/http_caregiver_consent_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Wire-level contract for `POST /api/coach/consent/revoke`.
///
/// Asserts the request body the backend parser receives, rather than what a
/// fake client chooses to record, so a rename on either side shows up here.
void main() {
  setUpAll(() async {
    await AppConfig.initApiResolution();
  });

  ({HttpCaregiverConsentApiClient client, List<http.Request> requests})
  clientReturning(http.Response Function() respond) {
    final requests = <http.Request>[];
    final transport = HttpTransport(
      client: MockClient((request) async {
        requests.add(request);
        return respond();
      }),
      baseUrl: 'http://test.invalid',
    );
    addTearDown(transport.dispose);
    return (client: HttpCaregiverConsentApiClient(transport), requests: requests);
  }

  http.Response confirmed({bool alreadyRevoked = false}) => http.Response(
    jsonEncode({
      'ok': true,
      'tokenId': 'token-1',
      'revoked': true,
      'alreadyRevoked': alreadyRevoked,
      'revokedAt': '2026-08-22T15:04:05.000Z',
    }),
    200,
    headers: const {'content-type': 'application/json'},
  );

  http.Response error(int status, String code) => http.Response(
    jsonEncode({
      'error': {'code': code, 'message': 'nope', 'retryable': status >= 500},
    }),
    status,
    headers: const {'content-type': 'application/json'},
  );

  test('caregiver revoke posts the canonical domain and the held token', () async {
    final harness = clientReturning(confirmed);

    final result = await harness.client.revokeConsent(
      domain: ConsentRevocationDomain.caregiverMonitoring,
      tokenId: 'token-1',
      token: const {'tokenId': 'token-1', 'signature': 'server-signature'},
    );

    expect(result.isSuccess, isTrue);
    final request = harness.requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/coach/consent/revoke');
    expect(jsonDecode(request.body), {
      'consentDomain': 'caregiverMonitoring',
      'tokenId': 'token-1',
      'reason': 'user_revoked',
      'token': {'tokenId': 'token-1', 'signature': 'server-signature'},
    });
  });

  test('coach revoke posts coachClient and omits token when none is held', () async {
    final harness = clientReturning(confirmed);

    await harness.client.revokeConsent(
      domain: ConsentRevocationDomain.coachClient,
      tokenId: 'token-coach-9',
    );

    expect(jsonDecode(harness.requests.single.body), {
      'consentDomain': 'coachClient',
      'tokenId': 'token-coach-9',
      'reason': 'user_revoked',
    });
  });

  test('a 200 with revoked true is a confirmation', () async {
    final harness = clientReturning(confirmed);

    final result = await harness.client.revokeConsent(
      domain: ConsentRevocationDomain.caregiverMonitoring,
      tokenId: 'token-1',
    );

    final confirmation = (result as ApiSuccess<ConsentRevocationConfirmation>)
        .value;
    expect(confirmation.isConfirmed, isTrue);
    expect(confirmation.alreadyRevoked, isFalse);
    expect(confirmation.revokedAt, DateTime.utc(2026, 8, 22, 15, 4, 5));
  });

  test('alreadyRevoked counts as a confirmation', () async {
    final harness = clientReturning(() => confirmed(alreadyRevoked: true));

    final result = await harness.client.revokeConsent(
      domain: ConsentRevocationDomain.caregiverMonitoring,
      tokenId: 'token-1',
    );

    final confirmation = (result as ApiSuccess<ConsentRevocationConfirmation>)
        .value;
    expect(confirmation.isConfirmed, isTrue);
    expect(confirmation.alreadyRevoked, isTrue);
  });

  test('401 maps to auth required', () async {
    final harness = clientReturning(() => error(401, 'AUTH_REQUIRED'));

    final result = await harness.client.revokeConsent(
      domain: ConsentRevocationDomain.caregiverMonitoring,
      tokenId: 'token-1',
    );

    expect(result.failureOrNull, isA<ApiFailureAuthRequired>());
  });

  test('403 and 503 keep their status codes for the retry policy', () async {
    final forbidden = clientReturning(() => error(403, 'FORBIDDEN'));
    final unavailable = clientReturning(
      () => error(503, 'CONSENT_REVOKE_FAILED'),
    );

    final forbiddenResult = await forbidden.client.revokeConsent(
      domain: ConsentRevocationDomain.caregiverMonitoring,
      tokenId: 'token-1',
    );
    final unavailableResult = await unavailable.client.revokeConsent(
      domain: ConsentRevocationDomain.caregiverMonitoring,
      tokenId: 'token-1',
    );

    expect(forbiddenResult.failureOrNull?.statusCode, 403);
    expect(unavailableResult.failureOrNull?.statusCode, 503);
  });

  test('backend not configured short-circuits before any request', () async {
    final requests = <http.Request>[];
    final transport = HttpTransport(
      client: MockClient((request) async {
        requests.add(request);
        return confirmed();
      }),
      baseUrl: '',
    );
    addTearDown(transport.dispose);

    final result = await HttpCaregiverConsentApiClient(transport).revokeConsent(
      domain: ConsentRevocationDomain.caregiverMonitoring,
      tokenId: 'token-1',
    );

    expect(result.failureOrNull, isA<ApiFailureBackendNotConfigured>());
    expect(requests, isEmpty);
  });
}
