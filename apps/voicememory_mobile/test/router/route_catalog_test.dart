import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/router/developer_route_guard.dart';
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
  });

  test('every retired deep link uses the shared compatibility registry', () {
    expect(
      DeveloperRouteGuard.legacyRedirects.keys,
      containsAll({
        '/memory',
        '/discover',
        '/timeline',
        '/search',
        '/discover-changes',
        '/archive-detail',
      }),
    );
    for (final alias in DeveloperRouteGuard.legacyRedirects.entries) {
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
    for (final path in DeveloperRouteGuard.legacyRedirects.keys) {
      expect(router.contains("'$path'"), isFalse, reason: path);
    }
  });

  test('router starts on Record and never treats context as onboarding', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    expect(router, contains('initialLocation: RouteCatalog.recordHome'));
    expect(
      router,
      contains(
        "GoRoute(path: '/', redirect: (context, state) => RouteCatalog.recordHome)",
      ),
    );
    final onboardingPaths = router.substring(
      router.indexOf('const onboardingPaths'),
      router.indexOf('const startPaths'),
    );
    expect(onboardingPaths, isNot(contains('/cold-start/seed')));
  });
}
