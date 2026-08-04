import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/api/api_transport.dart';
import 'package:voicememory_mobile/config/app_config.dart';

void main() {
  const baseUrl = 'https://voice-memory-iota.vercel.app';

  setUpAll(AppConfig.initApiResolution);

  test('maps SocketException to ConnectivityException with cause', () async {
    final source = const SocketException('connection refused');
    final transport = ApiTransport(
      baseUrl: baseUrl,
      httpClient: MockClient((_) async => throw source),
    );

    await expectLater(
      transport.get('/api/test'),
      throwsA(
        isA<ConnectivityException>().having(
          (error) => error.cause,
          'cause',
          same(source),
        ),
      ),
    );
  });

  test('maps ClientException to ConnectivityException with cause', () async {
    final source = http.ClientException('connection closed');
    final transport = ApiTransport(
      baseUrl: baseUrl,
      httpClient: MockClient((_) async => throw source),
    );

    await expectLater(
      transport.postJson('/api/test'),
      throwsA(
        isA<ConnectivityException>().having(
          (error) => error.cause,
          'cause',
          same(source),
        ),
      ),
    );
  });

  test('maps TimeoutException to RequestTimeoutException with cause', () async {
    final source = TimeoutException('slow request');
    final transport = ApiTransport(
      baseUrl: baseUrl,
      httpClient: MockClient((_) async => throw source),
    );

    await expectLater(
      transport.delete('/api/test'),
      throwsA(
        isA<RequestTimeoutException>().having(
          (error) => error.cause,
          'cause',
          same(source),
        ),
      ),
    );
  });

  test('maps 401 before a response reaches a domain client', () async {
    final transport = ApiTransport(
      baseUrl: baseUrl,
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":"Sign in required","code":"AUTH_REQUIRED"}',
          401,
        ),
      ),
    );

    await expectLater(
      transport.get('/api/private'),
      throwsA(isA<AuthRequiredException>()),
    );
  });

  test('maps service and billing 503 responses centrally', () async {
    final responses = <http.Response>[
      http.Response('{"error":"maintenance"}', 503),
      http.Response(
        '{"error":"billing disabled","code":"BILLING_DISABLED"}',
        503,
      ),
    ];
    final transport = ApiTransport(
      baseUrl: baseUrl,
      httpClient: MockClient((_) async => responses.removeAt(0)),
    );

    await expectLater(
      transport.postJson('/api/analyze'),
      throwsA(isA<ServiceUnavailableException>()),
    );
    await expectLater(
      transport.postJson('/api/billing/checkout'),
      throwsA(isA<BillingUnavailableException>()),
    );
  });

  test('maps general non-2xx responses for every request method', () async {
    final transport = ApiTransport(
      baseUrl: baseUrl,
      httpClient: MockClient(
        (_) async => http.Response('{"error":"teapot","code":"TEAPOT"}', 418),
      ),
    );

    await expectLater(
      transport.delete('/api/test'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 418)
            .having((error) => error.code, 'code', 'TEAPOT'),
      ),
    );
    await expectLater(
      transport.send(http.Request('PATCH', Uri.parse('$baseUrl/api/test'))),
      throwsA(isA<ApiException>()),
    );
  });

  test('accepted status codes bypass error mapping for endpoint semantics', () {
    final transport = ApiTransport(
      baseUrl: baseUrl,
      httpClient: MockClient((_) async => http.Response('', 404)),
    );

    expect(
      transport.delete('/api/missing', acceptedStatusCodes: const {404}),
      completion(
        isA<http.Response>().having(
          (response) => response.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
  });

  test('custom interceptors run before mandatory error mapping', () async {
    final recorder = _RecordingInterceptor();
    final transport = ApiTransport(
      baseUrl: baseUrl,
      responseInterceptors: [recorder],
      httpClient: MockClient(
        (_) async => http.Response('{"error":"upstream"}', 502),
      ),
    );

    final response = await transport.get('/api/test');

    expect(response.statusCode, 200);
    expect(recorder.methods, ['GET']);
    expect(recorder.paths, ['/api/test']);
  });

  test('maps malformed response without breaking FormatException contract', () {
    final transport = ApiTransport(baseUrl: baseUrl);

    expect(
      () => transport.decodeJson(http.Response('<html>bad host</html>', 200)),
      throwsA(
        isA<InvalidApiResponseException>()
            .having(
              (error) => error.userMessage,
              'userMessage',
              'Service is temporarily unavailable.',
            )
            .having((error) => error.cause, 'cause', isA<FormatException>()),
      ),
    );
  });
}

final class _RecordingInterceptor implements ApiResponseInterceptor {
  final List<String> methods = [];
  final List<String> paths = [];

  @override
  http.Response intercept(ApiRequestContext request, http.Response response) {
    methods.add(request.method);
    paths.add(request.uri.path);
    return http.Response(response.body, 200, headers: response.headers);
  }
}
