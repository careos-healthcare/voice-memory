@Tags(['gate'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `RemoteProcessingConsentStore.isPurposeGrantedNow` answers only "did the
/// customer grant this purpose?". It deliberately does **not** know about the
/// "Never send to server" toggle, so calling it directly at a remote boundary
/// re-creates the leak this guard exists to prevent. The composed predicate is
/// `RemoteProcessingConsentGate.isPurposePermittedNow`.
/// Matches invocations, not prose: doc comments may name the method.
const _rawConsentAccessor = '.isPurposeGrantedNow(';

/// Path suffixes allowed to mention the raw accessor.
const _rawAccessorAllowlist = <String>[
  'features/proof_admission/remote_processing_consent_store.dart',
];

Iterable<Directory> _scanRoots() sync* {
  for (final path in const ['lib', 'retired_sprawl', 'apps/mobile/lib']) {
    final dir = Directory(path);
    if (dir.existsSync()) yield dir;
  }
}

/// Normalises a scanned path so symlinked `lib/features/<x>` and the real
/// `retired_sprawl/lib_features/<x>` compare the same way.
String _normalise(String path) => path.replaceAll(r'\', '/');

/// Locates `tool/check_remote_egress_gating.py` from wherever `flutter test`
/// was invoked. Not found is a failure, never a skip: this file used to hold a
/// list of five boundaries that quietly excluded the one that leaked, and a
/// guard that no-ops when it cannot find itself is the same defect wearing a
/// different hat.
({Directory workingDirectory, File script})? _locateGuard() {
  var dir = Directory.current;
  for (var depth = 0; depth < 5; depth++) {
    final candidate = File('${dir.path}/tool/check_remote_egress_gating.py');
    if (candidate.existsSync()) {
      return (workingDirectory: dir, script: candidate);
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

void main() {
  test('no new direct callers of the raw consent accessor', () {
    final offenders = <String>[];
    var scanned = 0;
    // Which allowlist entries the walk actually reached. `lib/features/*` is
    // symlinked into `retired_sprawl/`, and both roots are scanned, so a file
    // under there is visited more than once — hence a set rather than a count.
    final allowlistSeen = <String>{};

    for (final root in _scanRoots()) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = _normalise(entity.path);
        scanned += 1;
        final allowed = _rawAccessorAllowlist.where(path.endsWith);
        if (allowed.isNotEmpty) {
          allowlistSeen.addAll(allowed);
          continue;
        }
        if (!entity.readAsStringSync().contains(_rawConsentAccessor)) continue;
        offenders.add(path);
      }
    }

    // A scan that reaches nothing reports no offenders, so an empty result is
    // only evidence once the scan is shown to have run. `lib/features/*` is
    // almost entirely symlinks into `retired_sprawl/`, and a listing that
    // stopped following them would look exactly like a clean bill of health.
    expect(
      scanned,
      greaterThan(500),
      reason: 'the scan walked $scanned Dart files, too few to have covered '
          'lib/ — check that symlinked feature directories are still followed',
    );
    expect(
      allowlistSeen,
      unorderedEquals(_rawAccessorAllowlist),
      reason: 'every allowlisted path must actually be found, otherwise the '
          'allowlist is stale and the scan is not looking where it thinks',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'These files call $_rawConsentAccessor directly, which ignores the '
          '"Never send to server" setting. Use '
          'RemoteProcessingConsentGate.isPurposePermittedNow instead:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the scan would actually catch a bypass', () {
    // Exercises the same predicate against known-positive and known-negative
    // text. Without this, a typo in `_rawConsentAccessor` would silently turn
    // the guard above into an assertion that nothing matches nothing.
    const bypass = 'if (await store.isPurposeGrantedNow(purpose)) upload();';
    const composed = 'if (await gate.isPurposePermittedNow(purpose)) upload();';

    expect(bypass.contains(_rawConsentAccessor), isTrue);
    expect(
      composed.contains(_rawConsentAccessor),
      isFalse,
      reason: 'the composed gate must not read as a bypass',
    );
  });

  // This test used to be a map of five (file, required substring) pairs. It
  // passed for the entire life of the onboarding brain-dump leak, because the
  // brain-dump pipeline was not one of the five and nothing about adding a
  // sixth boundary was enforced. The list has been replaced by a scan that
  // discovers boundaries from the egress primitives themselves — WebSocket
  // sends, Retrofit write annotations, the transport's own write methods — and
  // requires each content-carrying one to be reached only through the gate.
  //
  // The scan lives in Python because it has to walk symlinks: 373 of the 387
  // entries under `lib/features/` point into `retired_sprawl/`, which the
  // analyzer excludes and the app still ships.
  test(
    'every remote boundary is discovered and gated',
    () {
      final located = _locateGuard();
      expect(
        located,
        isNotNull,
        reason: 'tool/check_remote_egress_gating.py was not found from '
            '${Directory.current.path}. It is the boundary discovery scan; '
            'without it this test asserts nothing.',
      );

      final result = Process.runSync(
        'python3',
        [located!.script.path],
        workingDirectory: located.workingDirectory.path,
      );

      final output = '${result.stdout}${result.stderr}'.trim();

      // The scan self-tests on every invocation, including against a
      // reconstruction of the brain-dump shape. If that line is absent the
      // scan did not run its own checks and its silence means nothing.
      expect(
        output,
        contains('self-test ok'),
        reason: 'the egress scan did not complete its self-test:\n$output',
      );

      expect(
        result.exitCode,
        0,
        reason: 'user content can reach the network without passing '
            'RemoteProcessingConsentGate:\n\n$output',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
