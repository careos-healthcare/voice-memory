import 'dart:io';

import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Paths declared in `packages/api_contract/openapi.yaml` that mobile Retrofit
/// clients must implement (mobile-used routes + health probes).
const _retrofitMobilePaths = {
  '/api/auth/send-code',
  '/api/auth/verify',
  '/api/auth/session',
  '/api/auth/signout',
  '/api/billing/entitlements',
  '/api/billing/checkout',
  '/api/capture/attest',
  '/api/analyze',
  '/api/transcribe',
  '/api/live-audio/session',
  '/api/live-audio/recover',
  '/api/sync/manifest',
  '/api/sync/pull',
  '/api/sync/changes',
  '/api/sync/push',
  '/api/journal',
  '/api/account/delete',
  '/api/insights/evidence',
  '/api/insights/corrections',
  '/api/ledger/bulk-import',
  '/api/onboarding/brain-dump',
  '/api/user-relationships',
  '/api/coach/consent/issue',
  '/api/coach/consent/verify',
  '/api/archive-synthesis',
  '/api/push/register',
  '/api/internal/send-test-push',
  '/api/health',
  '/api/healthz',
};

void main() {
  test('VoiceMemoryApiRoutes catalog matches OpenAPI mobile paths', () {
    final specFile = File('openapi/voice_memory_api.yaml');
    expect(specFile.existsSync(), isTrue, reason: 'Run from apps/mobile');

    final doc = loadYaml(specFile.readAsStringSync()) as YamlMap;
    final paths = (doc['paths'] as YamlMap).keys.cast<String>().toSet();

    for (final mobilePath in _retrofitMobilePaths) {
      expect(
        paths.contains(mobilePath) || paths.contains(_templatePath(mobilePath)),
        isTrue,
        reason: 'OpenAPI missing $mobilePath',
      );
    }

    for (final endpoint in VoiceMemoryApiRoutes.all) {
      expect(
        paths.contains(endpoint.path),
        isTrue,
        reason: 'OpenAPI missing catalog path ${endpoint.path}',
      );
    }
  });

  test('Retrofit source files declare mobile API paths', () {
    final retrofitDir = Directory('lib/api/retrofit');
    final sources = retrofitDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    for (final path in _retrofitMobilePaths) {
      expect(sources.contains("'$path'"), isTrue, reason: 'Retrofit missing $path');
    }
  });
}

String _templatePath(String concretePath) {
  if (concretePath.startsWith('/api/user-relationships/')) {
    return '/api/user-relationships/{id}';
  }
  if (concretePath.startsWith('/api/journal/') && concretePath != '/api/journal/export') {
    return '/api/journal/{id}';
  }
  return concretePath;
}