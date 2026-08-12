import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/router/production_route_cta_registry.dart';
import 'package:archiveme_mobile/router/production_route_link_gate.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/router/v1_route_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/prohibited_route_link_examples.dart';

void main() {
  test('route registry is single source for allowlist count', () {
    expect(
      V1RouteInventory.v1AllowlistedRouteCount,
      V1RouteRegistry.allowlistedRouteCount,
    );
    expect(V1RouteRegistry.exportPath, '/export');
    expect(V1RouteRegistry.allQuarantinedPaths, contains('/archive-export'));
  });

  test('quarantined archive-export deep link redirects to canonical export', () {
    expect(
      V1NavigationGuard.redirectFor('/archive-export'),
      V1RouteRegistry.exportPath,
    );
    expect(V1NavigationGuard.isAllowed('/archive-export'), isFalse);
    expect(V1NavigationGuard.isNavRouteVisible('/archive-export'), isFalse);
  });

  test('CTA registry routes are allowlisted', () {
    final failures = ProductionRouteLinkGate.validateCtaRegistry();
    expect(failures, isEmpty);
  });

  test('production route link gate passes on active graph', () {
    final failures = ProductionRouteLinkGate.validateActiveProductionGraph(
      Directory.current.path,
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('gate detects injected quarantined route targets', () {
    final failures = ProductionRouteLinkGate.scanSource(
      path: 'lib/widgets/account/injected.dart',
      lines: ["onTap: () => context.push('/archive-export'),"],
    );
    expect(failures, isNotEmpty);
    expect(failures.single, contains('/archive-export'));
  });

  test('fixture file excludes marked prohibited CTA examples', () {
    final fixturePath = 'test/router/fixtures/prohibited_route_link_examples.dart';
    final lines = File(fixturePath).readAsLinesSync();
    final failures = ProductionRouteLinkGate.scanSource(
      path: fixturePath,
      lines: lines,
    );
    expect(failures, isEmpty);
    expect(
      ProhibitedRouteLinkFixtureExamples.examples.join('\n'),
      contains('/archive-export'),
    );
  });

  test('account privacy export uses canonical route constant', () {
    final section = File(
      'lib/widgets/account/account_privacy_controls_section.dart',
    ).readAsStringSync();
    expect(section, contains('V1RouteRegistry.exportPath'));
    expect(section, isNot(contains("context.push('/archive-export')")));
  });
}
