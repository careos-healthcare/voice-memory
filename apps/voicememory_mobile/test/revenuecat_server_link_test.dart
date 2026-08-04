import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_transport.dart';
import 'package:voicememory_mobile/api/billing_api_client.dart';
import 'package:voicememory_mobile/config/app_config.dart';

void main() {
  setUpAll(AppConfig.initApiResolution);

  test('links only RevenueCat app user ID over session transport', () async {
    late http.Request captured;
    final transport = ApiTransport(
      baseUrl: 'https://voice-memory-iota.vercel.app',
      sessionCookie: 'vm_session=authenticated',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'linked': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    const appUserId = '0123456789abcdef0123456789abcdef';
    await BillingApiClient(transport).linkRevenueCatAppUserId(appUserId);

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/billing/revenuecat/link');
    expect(captured.headers['cookie'], 'vm_session=authenticated');
    expect(jsonDecode(captured.body), {'appUserId': appUserId});
    expect(captured.body, isNot(contains('captureToken')));
    expect(captured.body, isNot(contains('session')));
  });
}
