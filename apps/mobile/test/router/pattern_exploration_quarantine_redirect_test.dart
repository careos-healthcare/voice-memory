import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_feature_flags.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/router/v1_quarantine_redirects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('pattern exploration stays frozen', () {
    expect(V1CapabilityRegistry.patternExploration, isFalse);
    expect(PatternExplorationFeatureFlags.isEnabled, isFalse);
  });

  test('explore path redirects to Archive when capability is disabled', () {
    expect(PatternExplorationFeatureFlags.isEnabled, isFalse);
    expect(
      V1QuarantineRedirects.redirectTarget(RouteCatalog.explorePatterns),
      RouteCatalog.archiveHome,
    );
  });

  testWidgets(
    'GoRouter quarantine redirect lands /explore on Archive',
    (tester) async {
      expect(PatternExplorationFeatureFlags.isEnabled, isFalse);
      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: RouteCatalog.archiveHome,
        routes: [
          GoRoute(
            path: RouteCatalog.archiveHome,
            builder: (_, _) => const Scaffold(body: Text('Archive home')),
          ),
          ...V1QuarantineRedirects.routes(rootNavigatorKey: navigatorKey),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      router.go(RouteCatalog.explorePatterns);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, RouteCatalog.archiveHome);
      expect(find.text('Archive home'), findsOneWidget);
    },
  );
}
