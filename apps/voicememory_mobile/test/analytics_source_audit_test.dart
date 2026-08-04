import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/analytics/analytics_catalog.dart';

void main() {
  // An event that reaches ActivationFunnelAnalytics.track must be in the V1
  // catalog. Registering it only as a legacy id makes trackActivation reject
  // it, which throws from an unawaited future at runtime rather than failing
  // any test that does not happen to exercise that code path.
  // Pre-existing offenders, recorded so this guard blocks new ones without
  // inventing catalog entries for features outside the V1 slice. Two of them
  // ("correction_memory_*") also trip the content-safety marker, so they need
  // renaming rather than registering.
  const knownUncatalogued = {
    'evidence_anchor_extraction_seen',
    'evidence_anchor_extraction_empty',
    'archive_moment_deleted',
    'pattern_evidence_excluded',
    'correction_memory_saved',
    'correction_memory_seen',
    'pattern_match_quality_resolved',
    'proof_caution_guard_applied',
    'proof_caution_guard_blocked',
    'proof_confidence_calibrated',
    'anchor_calibration_applied',
  };

  test('every event routed through the activation funnel is catalogued', () {
    final declaration = RegExp(
      r"static const (?:String )?\w*[Ee]vent\w* = '([a-z0-9_]+)';",
    );
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('ActivationFunnelAnalytics.track(')) continue;
      for (final match in declaration.allMatches(source)) {
        final event = match.group(1)!;
        if (knownUncatalogued.contains(event)) continue;
        if (AnalyticsCatalog.activationEvent(event) == null) {
          offenders.add('${entity.path}: "$event"');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These events are emitted through the activation funnel but the '
          'catalog rejects them:\n${offenders.join('\n')}',
    );
  });

  test('Firebase Analytics is reachable only through ProductAnalytics', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('services/product_analytics.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('firebase_analytics') ||
          source.contains('FirebaseAnalytics') ||
          source.contains('.logEvent(') &&
              source.contains('FirebaseAnalytics')) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Direct Firebase analytics access bypasses the final guard.',
    );
  });
}
