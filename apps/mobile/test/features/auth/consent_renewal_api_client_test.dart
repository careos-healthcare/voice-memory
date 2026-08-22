import 'dart:convert';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/data/network/consent_renewal_api_client.dart';
import 'package:archiveme_mobile/data/network/http_caregiver_consent_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Wire-level contract for `POST /api/coach/consent/renew`.
///
/// Asserts the body the backend parser actually receives. The server refuses a
/// renewal whose confirmation is absent, stale, or about a different grant, so
/// a client that stopped sending one — or sent the wrong grant id — would fail
/// in production and pass against a fake. This test is where that shows up.
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

  Map<String, dynamic> successorToken() => {
    'tokenId': 'token-2',
    'subjectAccountId': 'subject-1',
    'caregiverId': 'caregiver-ada',
    'permissions': {
      'evidenceStreamIds': <String>['mood'],
      'reviewSummaries': true,
      'thresholdAlerts': false,
    },
    'issuedAt': '2026-06-07T09:00:00.000Z',
    'expiresAt': '2026-06-14T09:00:00.000Z',
    'policyVersion': 1,
    'signature': 'successor-signature',
  };

  http.Response renewed({bool withPreviousRevokedAt = true}) => http.Response(
    jsonEncode({
      'ok': true,
      'renewed': true,
      'consentDomain': 'caregiverMonitoring',
      'token': successorToken(),
      'previousTokenId': 'token-1',
      if (withPreviousRevokedAt)
        'previousRevokedAt': '2026-06-07T09:00:00.000Z',
      'ownerConfirmedAt': '2026-06-07T08:59:00.000Z',
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

  const heldToken = {
    'tokenId': 'token-1',
    'signature': 'server-signature',
  };

  test('the production consent client offers the renewal seam', () {
    final harness = clientReturning(renewed);
    expect(
      harness.client,
      isA<ConsentRenewalApiClient>(),
      reason:
          'renewal is resolved by type from the consent provider, so this is '
          'the wiring that keeps it reachable',
    );
  });

  test('renewal posts the held token and a confirmation bound to it', () async {
    final harness = clientReturning(renewed);

    final result = await harness.client.renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59),
    );

    expect(result.isSuccess, isTrue);
    final request = harness.requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/coach/consent/renew');
    expect(jsonDecode(request.body), {
      'consentDomain': 'caregiverMonitoring',
      'tokenId': 'token-1',
      'token': heldToken,
      'ownerConfirmation': {
        'confirmedTokenId': 'token-1',
        'acknowledgedAt': '2026-06-07T08:59:00.000Z',
      },
    });
  });

  test('a local confirmation time is sent as UTC', () async {
    final harness = clientReturning(renewed);

    await harness.client.renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59).toLocal(),
    );

    final body = jsonDecode(harness.requests.single.body) as Map<String, dynamic>;
    final confirmation = body['ownerConfirmation'] as Map<String, dynamic>;
    expect(confirmation['acknowledgedAt'], '2026-06-07T08:59:00.000Z');
  });

  test('a successor plus a withdrawal is a confirmed replacement', () async {
    final harness = clientReturning(renewed);

    final result = await harness.client.renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59),
    );

    final confirmation =
        (result as ApiSuccess<ConsentRenewalConfirmation>).value;
    expect(confirmation.isConfirmed, isTrue);
    expect(confirmation.token.tokenId, 'token-2');
    expect(confirmation.token.expiresAt, DateTime.utc(2026, 6, 14, 9));
    expect(confirmation.previousTokenId, 'token-1');
    expect(confirmation.previousRevokedAt, DateTime.utc(2026, 6, 7, 9));
  });

  test('a successor without a withdrawal is not a confirmation', () async {
    final harness = clientReturning(
      () => renewed(withPreviousRevokedAt: false),
    );

    final result = await harness.client.renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59),
    );

    final confirmation =
        (result as ApiSuccess<ConsentRenewalConfirmation>).value;
    expect(
      confirmation.isConfirmed,
      isFalse,
      reason:
          'a new token whose predecessor may still be live is two credentials '
          'for one arrangement',
    );
  });

  test('401 maps to auth required', () async {
    final harness = clientReturning(() => error(401, 'AUTH_REQUIRED'));

    final result = await harness.client.renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59),
    );

    expect(result.failureOrNull, isA<ApiFailureAuthRequired>());
  });

  test('the server code survives so 409 answers stay distinguishable', () async {
    final lapsed = clientReturning(() => error(409, 'GRANT_EXPIRED'));
    final settled = clientReturning(() => error(409, 'GRANT_NOT_RENEWABLE'));

    final lapsedResult = await lapsed.client.renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59),
    );
    final settledResult = await settled.client.renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59),
    );

    expect(lapsedResult.failureOrNull?.code, 'GRANT_EXPIRED');
    expect(settledResult.failureOrNull?.code, 'GRANT_NOT_RENEWABLE');
  });

  test('403 and 503 keep their status codes', () async {
    final forbidden = clientReturning(() => error(403, 'FORBIDDEN'));
    final unavailable = clientReturning(
      () => error(503, 'CONSENT_RENEWAL_FAILED'),
    );

    final forbiddenResult = await forbidden.client.renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59),
    );
    final unavailableResult = await unavailable.client.renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59),
    );

    expect(forbiddenResult.failureOrNull?.statusCode, 403);
    expect(unavailableResult.failureOrNull?.statusCode, 503);
  });

  test('backend not configured short-circuits before any request', () async {
    final requests = <http.Request>[];
    final transport = HttpTransport(
      client: MockClient((request) async {
        requests.add(request);
        return renewed();
      }),
      baseUrl: '',
    );
    addTearDown(transport.dispose);

    final result = await HttpCaregiverConsentApiClient(
      transport,
    ).renewCaregiverConsent(
      tokenId: 'token-1',
      token: heldToken,
      ownerConfirmedAt: DateTime.utc(2026, 6, 7, 8, 59),
    );

    expect(result.failureOrNull, isA<ApiFailureBackendNotConfigured>());
    expect(requests, isEmpty);
  });
}
