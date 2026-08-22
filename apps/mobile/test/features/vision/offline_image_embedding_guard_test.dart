import 'dart:io';

import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/features/vision/offline_image_embedding_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineImageEmbeddingGuard', () {
    test('blocks HttpTransport while offline scope is active', () async {
      await OfflineImageEmbeddingGuard.runOffline(() async {
        expect(OfflineImageEmbeddingGuard.isActive, isTrue);
        expect(
          () => OfflineImageEmbeddingGuard.assertOfflineBlocked(
            operation: 'unit_test',
          ),
          throwsA(isA<OfflineImageEmbeddingViolation>()),
        );
      });
      expect(OfflineImageEmbeddingGuard.isActive, isFalse);
    });

    test('HttpTransport rejects requests during offline embedding scope', () async {
      final transport = HttpTransport(baseUrl: 'https://example.test');

      await OfflineImageEmbeddingGuard.runOffline(() async {
        final result = await transport.get('/health');
        expect(result.isFailure, isTrue);
      });
    });

    test('vision sources do not import network clients', () {
      final visionDir = Directory('lib/features/vision');
      expect(visionDir.existsSync(), isTrue);

      final banned = RegExp(r"import 'package:(http|dio)/");
      for (final entity in visionDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final contents = entity.readAsStringSync();
        expect(
          banned.hasMatch(contents),
          isFalse,
          reason: '${entity.path} must stay offline-only',
        );
      }
    });
  });
}
