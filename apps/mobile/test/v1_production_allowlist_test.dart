import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/core/config/v1_production_allowlist.dart';
import 'package:archiveme_mobile/router/v1_route_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 launch capabilities are stable and non-empty', () {
    expect(V1ProductionAllowlist.launchCapabilities, isNotEmpty);
    expect(V1ProductionAllowlist.launchCapabilities, contains('voice_capture'));
    expect(
      V1ProductionAllowlist.launchCapabilities,
      contains('optional_paid_deeper_history'),
    );
  });

  test('startup phases are ordered for staged boot', () {
    expect(V1ProductionAllowlist.startupPhases.length, 4);
    expect(V1ProductionAllowlist.startupPhases.first.id, 'privacy_safe_shell');
    expect(
      V1ProductionAllowlist.startupPhases.last.id,
      'optional_async_services',
    );
  });

  test('production router screens exclude deferred experiments', () {
    for (final blocked in V1ProductionAllowlist.blockedProductionScreens) {
      expect(
        V1ProductionAllowlist.productionRouterScreens,
        isNot(contains(blocked)),
        reason: '$blocked must stay deferred',
      );
    }
  });

  test('blocked packages stay out of production lib imports', () {
    final libRoot = Directory('lib');
    for (final blocked in V1ProductionAllowlist.blockedProductionPackages) {
      for (final file
          in libRoot
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final content = file.readAsStringSync();
        expect(
          content,
          isNot(contains("import 'package:$blocked/")),
          reason: '${file.path} imports blocked package $blocked',
        );
      }
    }
  });

  test('V1-only flag and capability registry align with allowlist', () {
    expect(V1FeatureFlags.enableV1Only, isTrue);
    expect(V1CapabilityRegistry.liveVoice, isFalse);
    expect(V1CapabilityRegistry.caregiverMonitoring, isFalse);
    expect(V1CapabilityRegistry.watchCompanion, isFalse);
    expect(V1CapabilityRegistry.speechRecognition, isTrue);
    expect(V1ProductionAllowlist.v1OnlyEnabled, isTrue);
    expect(
      V1ProductionAllowlist.allowlistedRouteCount,
      V1RouteInventory.v1AllowlistedRouteCount,
    );
  });

  test('permission matrix doc references real validators', () {
    final doc = File('docs/V1_PERMISSION_MATRIX.md').readAsStringSync();
    expect(doc, contains('tool/audit_v1_permissions.sh'));
    expect(doc, contains('tool/validate_v1_production_graph.sh'));
    expect(doc, contains('v1_capability_registry.dart'));
  });
}