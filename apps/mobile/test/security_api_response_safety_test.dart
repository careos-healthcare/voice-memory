import 'package:archiveme_mobile/config/backend_url_resolver.dart';
import 'package:archiveme_mobile/security/api_response_safety.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('ApiResponseSafety', () {
    test('detects HTML responses by content-type', () {
      final response = http.Response(
        '<html><body>Not Found</body></html>',
        404,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
      expect(ApiResponseSafety.responseLooksLikeHtml(response), isTrue);
    });

    test('detects HTML responses by body prefix', () {
      final response = http.Response('<!DOCTYPE html><html></html>', 200);
      expect(ApiResponseSafety.responseLooksLikeHtml(response), isTrue);
    });

    test('decodeJsonObject throws safe error for HTML body', () {
      final response = http.Response(
        '<!DOCTYPE html><title>nginx</title>',
        502,
        headers: {'content-type': 'text/html'},
      );
      expect(
        () => ApiResponseSafety.decodeJsonObject(response),
        throwsA(
          predicate(
            (e) =>
                e is FormatException &&
                e.message == ApiResponseSafety.htmlResponseMessage,
          ),
        ),
      );
    });

    test('decodeJsonObject parses valid JSON', () {
      final response = http.Response('{"ok":true}', 200);
      final body = ApiResponseSafety.decodeJsonObject(response);
      expect(body['ok'], isTrue);
    });

    test('allows https production URLs', () {
      expect(
        ApiResponseSafety.isBaseUrlAllowed(
          'https://voice-memory-iota.vercel.app',
        ),
        isTrue,
      );
    });

    test('remaps marketing-only careosapp host to production API', () {
      expect(
        BackendUrlResolver.normalizeApiBaseUrl('https://careosapp.co.uk'),
        BackendUrlResolver.productionApiBaseUrl,
      );
      expect(
        BackendUrlResolver.normalizeApiBaseUrl('https://www.careosapp.co.uk/'),
        BackendUrlResolver.productionApiBaseUrl,
      );
    });
  });
}