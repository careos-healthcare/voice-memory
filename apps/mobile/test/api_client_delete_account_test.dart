import 'dart:convert';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/data/network/http_account_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() async {
    await AppConfig.initApiResolution();
  });

  test('deleteAccount sends the server-required confirm:true body', () async {
    var sawConfirmedBody = false;

    final transport = HttpTransport(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/account/delete');

        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        sawConfirmedBody = decoded['confirm'] == true;

        if (!sawConfirmedBody) {
          return http.Response(
            jsonEncode({
              'error': 'Confirmation required.',
              'code': 'CONFIRM_REQUIRED',
            }),
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
    final client = HttpAccountApiClient(transport);

    final result = await client.deleteAccount();
    result.when(
      success: (_) {},
      onFailure: (failure) => throw failure.toApiException(),
    );

    expect(sawConfirmedBody, isTrue);
  });

  test(
    'deleteAccount surfaces CONFIRM_REQUIRED as a mapped API error, not a silent success',
    () async {
      final transport = HttpTransport(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'Confirmation required.',
              'code': 'CONFIRM_REQUIRED',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'https://voice-memory-iota.vercel.app',
      );
      final client = HttpAccountApiClient(transport);

      final result = await client.deleteAccount();
      expect(
        result.when(
          success: (_) => null,
          onFailure: (failure) => failure.toApiException(),
        ),
        isA<ApiException>(),
      );
    },
  );
}