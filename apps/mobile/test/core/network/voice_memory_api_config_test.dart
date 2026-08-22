import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_config.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceMemoryApiRoutes', () {
    test('catalog paths are unique', () {
      final paths = VoiceMemoryApiRoutes.all.map((e) => e.path).toList();
      expect(paths.toSet().length, paths.length);
    });

    test('every path starts with /api/', () {
      for (final endpoint in VoiceMemoryApiRoutes.all) {
        expect(endpoint.path.startsWith('/api/'), isTrue, reason: endpoint.path);
      }
    });

    test('dynamic journal entry path matches backend segment', () {
      expect(
        VoiceMemoryApiRoutes.journalEntry('abc-123'),
        '/api/journal/abc-123',
      );
    });

    test('dynamic user relationship path matches backend segment', () {
      expect(
        VoiceMemoryApiRoutes.userRelationship('rel-42'),
        '/api/user-relationships/rel-42',
      );
    });
  });

  group('VoiceMemoryApiConfig', () {
    test('normalizes trailing slash on base URL', () {
      final config = VoiceMemoryApiConfig(
        baseUrl: 'https://example.com/',
      );
      expect(config.baseUrl, 'https://example.com');
    });

    test('resolve builds full URI for catalog endpoint', () {
      final config = VoiceMemoryApiConfig(
        baseUrl: 'https://example.com',
      );
      final uri = config.resolve(VoiceMemoryApiRoutes.health);
      expect(uri.toString(), 'https://example.com/api/health');
    });
  });

  group('voiceMemoryApiBaseUrlProvider', () {
    test('throws when not overridden at bootstrap', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(voiceMemoryApiBaseUrlProvider),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('accepts injected VOICE_MEMORY_API_BASE_URL', () {
      AppConfig.configureForTest();
      addTearDown(AppConfig.resetTestConfiguration);

      final container = ProviderContainer(
        overrides: [
          voiceMemoryApiBaseUrlProvider.overrideWithValue(
            AppConfig.apiBaseUrl,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(voiceMemoryApiBaseUrlProvider), 'http://127.0.0.1:3000');
      expect(
        container.read(voiceMemoryApiConfigProvider).baseUrl,
        'http://127.0.0.1:3000',
      );
    });
  });
}