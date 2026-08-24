import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/router/v1_quarantine_redirects.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _billingPaths = [
  V1RouteRegistry.subscriptionPath,
  V1RouteRegistry.pricingPath,
  V1RouteRegistry.restorePurchasesPath,
];

void main() {
  test('store billing stays frozen', () {
    expect(V1CapabilityRegistry.storeBilling, isFalse);
    expect(V1BillingCapability.isEnabled, isFalse);
  });

  test('production router has no paywall builders', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    expect(router, isNot(contains('PaywallScreen')));
    expect(router, isNot(contains('PricingScreen')));
    expect(router, isNot(contains('RestorePurchasesScreen')));
    expect(router, contains('V1QuarantineRedirects.routes'));
    expect(router, contains('billingCapabilityRedirect'));
  });

  test('billing paths redirect to Archive when capability is disabled', () {
    expect(V1BillingCapability.isEnabled, isFalse);
    for (final path in _billingPaths) {
      expect(
        V1RouteRegistry.billingCapabilityRedirect(path),
        RouteCatalog.archiveHome,
        reason: path,
      );
      expect(
        V1QuarantineRedirects.redirectTarget(path),
        RouteCatalog.archiveHome,
        reason: path,
      );
    }
  });

  testWidgets(
    'GoRouter quarantine redirect lands billing paths on Archive',
    (tester) async {
      expect(V1BillingCapability.isEnabled, isFalse);
      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: RouteCatalog.archiveHome,
        routes: [
          GoRoute(
            path: RouteCatalog.archiveHome,
            builder: (_, __) => const Scaffold(body: Text('Archive home')),
          ),
          ...V1QuarantineRedirects.routes(rootNavigatorKey: navigatorKey),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      for (final path in _billingPaths) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(
          router.state.uri.path,
          RouteCatalog.archiveHome,
          reason: path,
        );
        expect(find.text('Archive home'), findsOneWidget, reason: path);
      }
    },
  );
}
