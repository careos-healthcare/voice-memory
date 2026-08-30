import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:archiveme_mobile/router/primary_navigation_controller.dart';
import 'package:archiveme_mobile/router/record_navigation_activity_controller.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/router/v1_quarantine_redirects.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/screens/archive_belief_screen.dart';
import 'package:archiveme_mobile/screens/belief_changes_screen.dart';
import 'package:archiveme_mobile/screens/delete_account_screen.dart';
import 'package:archiveme_mobile/screens/export_screen.dart';
import 'package:archiveme_mobile/screens/privacy_screen.dart';
import 'package:archiveme_mobile/screens/record_screen.dart';
import 'package:archiveme_mobile/screens/support_feedback_screen.dart';
import 'package:archiveme_mobile/screens/terms_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/app_provider_scope.dart';
import '../support/localized_test_app.dart';
import '../support/test_storage_sandbox.dart';

GoRouter buildProductionRouterHarness({GlobalKey<NavigatorState>? rootKey}) {
  final navigatorKey = rootKey ?? GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: RouteCatalog.recordHome,
    redirect: (context, state) {
      if (!onboardingGate.complete &&
          state.uri.path != V1RouteRegistry.onboardingPath) {
        return V1RouteRegistry.onboardingPath;
      }
      return V1NavigationGuard.redirectFor(state.uri.path);
    },
    routes: [
      GoRoute(
        path: V1RouteRegistry.onboardingPath,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Onboarding'))),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(
          navigationShell: navigationShell,
          primaryNavigationController: primaryNavigationController,
          recordNavigationActivityController: recordNavigationActivityController,
        ),
        branches: [
          StatefulShellBranch(
            navigatorKey: recordBranchNavigatorKey,
            routes: [
              GoRoute(
                path: RouteCatalog.recordHome,
                builder: (context, state) => CaptureScreenHost(
                  navigationActivityController:
                      recordNavigationActivityController,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: archiveBranchNavigatorKey,
            routes: [
              GoRoute(
                path: RouteCatalog.archiveHome,
                builder: (context, state) => const ArchiveBeliefScreen(),
                routes: [
                  GoRoute(
                    path: 'changes',
                    builder: (context, state) => const BeliefChangesScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: accountBranchNavigatorKey,
            routes: [
              GoRoute(
                path: RouteCatalog.accountHome,
                builder: (context, state) =>
                    const Scaffold(body: Center(child: Text('Account branch'))),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: V1RouteRegistry.exportPath,
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: V1RouteRegistry.deleteAccountPath,
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: V1RouteRegistry.privacyPath,
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: V1RouteRegistry.supportFeedbackPath,
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const SupportFeedbackScreen(),
      ),
      GoRoute(
        path: V1RouteRegistry.termsPath,
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const TermsScreen(),
      ),
      ...V1QuarantineRedirects.routes(rootNavigatorKey: navigatorKey),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestStorageSandbox sandbox;
  late GoRouter router;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      skipRevenueCat: true,
    );
    await AppServices.instance.prefs.setOnboardingCompleted(true);
    onboardingGate.markComplete();
    onboardingGate.resetSessionRedirectsForTest();
    router = buildProductionRouterHarness();
  });

  tearDown(() {
    sandbox.dispose();
    onboardingGate.resetSessionRedirectsForTest();
  });

  Future<void> pumpLocation(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpWithAppProviderScope(
      tester,
      localizedMaterialAppRouter(routerConfig: router),
    );
    router.go(location);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('production route-link integration', () {
    test('primary shell routes stay on the allowlist', () {
      for (final route in RouteCatalog.primaryRoutes) {
        expect(V1NavigationGuard.redirectFor(route), isNull, reason: route);
      }
    });

    testWidgets('quarantined archive-export deep link redirects to export', (
      tester,
    ) async {
      await pumpLocation(tester, '/archive-export');
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ExportScreen), findsOneWidget);
      expect(router.state.uri.path, V1RouteRegistry.exportPath);
    });

    testWidgets('export delete privacy support and terms routes mount', (
      tester,
    ) async {
      final cases = <String, Type>{
        V1RouteRegistry.exportPath: ExportScreen,
        V1RouteRegistry.deleteAccountPath: DeleteAccountScreen,
        V1RouteRegistry.privacyPath: PrivacyScreen,
        V1RouteRegistry.supportFeedbackPath: SupportFeedbackScreen,
        V1RouteRegistry.termsPath: TermsScreen,
      };

      for (final entry in cases.entries) {
        await pumpLocation(tester, entry.key);
        expect(find.byType(entry.value), findsOneWidget);
      }
    });

    testWidgets('account shell branch stays inside MainShell', (tester) async {
      await pumpLocation(tester, RouteCatalog.accountHome);
      expect(find.byType(MainShell), findsOneWidget);
    });
  });
}
