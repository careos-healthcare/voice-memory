import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/config/production_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(DeveloperSettingsGate.resetForTest);

  test('verification routes are debug-only', () {
    const routes = [
      '/native-push-verify',
      '/revenuecat-verify',
      '/restore-production-verify',
      '/offline-sync-verify',
    ];
    for (final route in routes) {
      expect(ProductionNavigation.isDebugOnlyRoute(route), isTrue);
      expect(ProductionNavigation.debugOnlyRoutes, contains(route));
    }
  });

  test('verification routes redirect when developer gate is closed', () {
    DeveloperSettingsGate.resetForTest();
    if (kDebugMode) return;
    for (final route in ProductionNavigation.debugOnlyRoutes) {
      expect(
        ProductionNavigation.redirectAwayFromIncomplete(route),
        '/settings',
      );
      expect(ProductionNavigation.isNavRouteVisible(route), isFalse);
    }
  });

  test('verification routes visible when gesture unlock is active', () {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.loadFromPrefs(true);
    for (final route in ProductionNavigation.debugOnlyRoutes) {
      expect(ProductionNavigation.redirectAwayFromIncomplete(route), isNull);
      expect(ProductionNavigation.isNavRouteVisible(route), isTrue);
    }
  });
}