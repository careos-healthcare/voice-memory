import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/config/app_config.dart';

void main() {
  setUpAll(() async {
    await AppConfig.initApiResolution();
  });

  test('deleteAccount sends the server-required confirm:true body', () async {
    var sawConfirmedBody = false;

    final client = ApiClient(
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/account/delete');

        // The server contract (app/api/account/delete/route.ts) rejects the
        // request with CONFIRM_REQUIRED unless the JSON body contains
        // {"confirm": true}. A regression here silently breaks deletion.
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        sawConfirmedBody = decoded['confirm'] == true;

        if (!sawConfirmedBody) {
          return http.Response(
            jsonEncode({'error': 'Confirmation required.', 'code': 'CONFIRM_REQUIRED'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode({'ok': true, 'removed': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUrl: 'https://voice-memory-iota.vercel.app',
    );

    await client.deleteAccount();

    expect(sawConfirmedBody, isTrue);
  });

  test('deleteAccount surfaces CONFIRM_REQUIRED as a mapped API error, not a silent success', () async {
    final client = ApiClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Confirmation required.', 'code': 'CONFIRM_REQUIRED'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUrl: 'https://voice-memory-iota.vercel.app',
    );

    await expectLater(
      client.deleteAccount(),
      throwsA(isA<ApiException>()),
    );
  });
}
