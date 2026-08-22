import 'dart:io';

import 'package:yaml/yaml.dart';

/// Validates OpenAPI spec ↔ Retrofit source parity without compiling the app.
///
/// Run from apps/mobile: `dart run tool/validate_api_contract.dart`
void main() {
  final mobileRoot = Directory.current;

  // `repoRoot` below is only correct when the cwd *is* apps/mobile. Run from
  // anywhere else it points two directories above the wrong tree, and the
  // failure reads as a missing spec rather than a missing `cd`. Anchor on a
  // directory that exists only here, and say so, before deriving anything.
  if (!Directory('${mobileRoot.path}/lib/api/retrofit').existsSync()) {
    stderr.writeln(
      'run this from apps/mobile — no lib/api/retrofit under '
      '${mobileRoot.path}',
    );
    exit(2);
  }

  final repoRoot = mobileRoot.parent.parent;

  final specFile = File('${repoRoot.path}/packages/api_contract/openapi.yaml');
  if (!specFile.existsSync()) {
    stderr.writeln('Missing ${specFile.path}');
    exit(1);
  }

  final doc = loadYaml(specFile.readAsStringSync()) as YamlMap;
  final openApiPaths = (doc['paths'] as YamlMap).keys.cast<String>().toSet();

  const mobilePaths = {
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

  var failed = false;
  for (final path in mobilePaths) {
    if (!openApiPaths.contains(path)) {
      stderr.writeln('OpenAPI missing path: $path');
      failed = true;
    }
  }

  final retrofitDir = Directory('${mobileRoot.path}/lib/api/retrofit');
  final sources = retrofitDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .map((f) => f.readAsStringSync())
      .join('\n');

  for (final path in mobilePaths) {
    if (!sources.contains("'$path'")) {
      stderr.writeln('Retrofit missing path: $path');
      failed = true;
    }
  }

  if (failed) exit(1);
  stdout.writeln(
    'OK: ${mobilePaths.length} mobile paths present in OpenAPI and Retrofit',
  );
}