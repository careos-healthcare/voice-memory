import 'dart:convert';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/data/network/http_caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Wire-level contract for `POST /api/coach/consent/issue` invite email.
///
/// Asserts the request body the backend parser receives, rather than what a
/// fake verification service records, so omitting `caregiverEmail` on the
/// opt-out path is visible here.
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
    return (
      client: HttpCaregiverConsentApiClient(transport),
      requests: requests,
    );
  }

  http.Response issued({bool emailSent = false}) => http.Response(
    jsonEncode({
      'ok': true,
      'token': {
        'tokenId': 'token-1',
        'subjectAccountId': 'user-1',
        'caregiverId': 'caregiver-1',
        'permissions': CaregiverPermissions.defaultScopes.toJson(),
        'issuedAt': '2026-01-01T00:00:00.000Z',
        'expiresAt': '2026-01-08T00:00:00.000Z',
        'policyVersion': 1,
        'signature': 'sig',
      },
      'redemption': {
        'linkToken': 'link-1',
        'manualCode': 'code-1',
        'reference': 'ref-1',
        'emailSent': emailSent,
      },
    }),
    200,
    headers: const {'content-type': 'application/json'},
  );

  test('opt-out issue body omits caregiverEmail', () async {
    final harness = clientReturning(issued);

    final result = await harness.client.issueToken(
      subjectAccountId: 'user-1',
      caregiverId: 'caregiver-1',
      permissions: CaregiverPermissions.defaultScopes,
      caregiverEmail: 'sam@example.com',
      sendInviteEmail: false,
    );

    expect(result.isSuccess, isTrue);
    expect(jsonDecode(harness.requests.single.body), {
      'consentDomain': 'caregiverMonitoring',
      'caregiverId': 'caregiver-1',
      'permissions': CaregiverPermissions.defaultScopes.toJson(),
    });
  });

  test('opt-in issue body includes caregiverEmail', () async {
    final harness = clientReturning(() => issued(emailSent: true));

    final result = await harness.client.issueToken(
      subjectAccountId: 'user-1',
      caregiverId: 'caregiver-1',
      permissions: CaregiverPermissions.defaultScopes,
      caregiverEmail: 'sam@example.com',
      sendInviteEmail: true,
    );

    expect(result.isSuccess, isTrue);
    expect(jsonDecode(harness.requests.single.body), {
      'consentDomain': 'caregiverMonitoring',
      'caregiverId': 'caregiver-1',
      'permissions': CaregiverPermissions.defaultScopes.toJson(),
      'caregiverEmail': 'sam@example.com',
    });
    expect(
      (result as ApiSuccess<MonitoringConsentToken>)
          .value
          .redemption
          ?.emailSent,
      isTrue,
    );
  });
}
