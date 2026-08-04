import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/router/developer_route_guard.dart';
import 'package:voicememory_mobile/router/legacy_route_aliases.dart';
import 'package:voicememory_mobile/router/onboarding_route_policy.dart';
import 'package:voicememory_mobile/router/route_catalog.dart';

void main() {
  test('V1 shell exposes four ordered canonical destinations', () {
    expect(RouteCatalog.primaryRoutes, [
      '/record',
      '/archive-belief',
      '/belief-changes',
      '/account',
    ]);
    expect(RouteCatalog.primaryRoutes, hasLength(4));
    expect(RouteCatalog.primaryRoutes, isNot(contains('/life-os/graph')));
  });

  test('every retired deep link uses the shared compatibility registry', () {
    expect(
      LegacyRouteAliases.redirects.keys,
      containsAll({
        '/memory',
        '/discover',
        '/timeline',
        '/search',
        '/discover-changes',
        '/archive-detail',
        '/discover-yourself',
      }),
    );
    for (final alias in LegacyRouteAliases.redirects.entries) {
      expect(alias.value, RouteCatalog.archiveHome, reason: alias.key);
      expect(
        DeveloperRouteGuard.redirectFor('${alias.key}?source=old-build'),
        RouteCatalog.archiveHome,
        reason: alias.key,
      );
    }
    expect(
      DeveloperRouteGuard.redirectFor(
        '/discover-yourself/chapter/old-id?source=push',
      ),
      RouteCatalog.archiveHome,
    );
  });

  test('retired paths are not declared as GoRouter records', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    for (final path in LegacyRouteAliases.redirects.keys) {
      expect(router.contains("'$path'"), isFalse, reason: path);
    }
  });

  test('router starts on Record and context is never a required next step', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    expect(router, contains('initialLocation: RouteCatalog.recordHome'));
    expect(
      router,
      contains(
        "GoRoute(path: '/', redirect: (_, _) => RouteCatalog.recordHome)",
      ),
    );
    expect(
      router,
      contains('path: RouteCatalog.optionalContext'),
      reason: 'optional context remains reachable from post-save and Settings',
    );
    expect(router, isNot(contains('fastPathRedirect(')));
    expect(
      OnboardingRoutePolicy.redirectBeforeCapture(
        path: RouteCatalog.optionalContext,
        onboardingComplete: false,
        screenshotMode: false,
        trialMode: false,
        isInstantCapture: false,
      ),
      RouteCatalog.onboarding,
    );
    expect(
      OnboardingRoutePolicy.redirectBeforeCapture(
        path: RouteCatalog.recordHome,
        onboardingComplete: true,
        screenshotMode: false,
        trialMode: false,
        isInstantCapture: false,
      ),
      isNull,
    );
  });
}
