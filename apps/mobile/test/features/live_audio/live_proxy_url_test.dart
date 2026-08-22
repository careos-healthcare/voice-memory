import 'package:archiveme_mobile/features/live_audio/domain/services/live_proxy_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeProxyWebSocketUrl', () {
    test('converts http origin to ws', () {
      expect(
        normalizeProxyWebSocketUrl('http://127.0.0.1:3000/api/live-audio/ws'),
        'ws://127.0.0.1:3000/api/live-audio/ws',
      );
    });

    test('converts https origin to wss', () {
      expect(
        normalizeProxyWebSocketUrl('https://api.example.com/api/live-audio/ws'),
        'wss://api.example.com/api/live-audio/ws',
      );
    });

    test('leaves ws scheme unchanged', () {
      const url = 'wss://example.test/api/live-audio/ws';
      expect(normalizeProxyWebSocketUrl(url), url);
    });
  });

  group('redactProxyWebSocketUrlForLog', () {
    test('redacts sessionToken query param', () {
      final redacted = redactProxyWebSocketUrlForLog(
        'ws://127.0.0.1:3000/api/live-audio/ws?sessionToken=secret-token',
      );
      expect(redacted, contains('sessionToken=%5Bredacted%5D'));
      expect(redacted, isNot(contains('secret-token')));
    });
  });
}