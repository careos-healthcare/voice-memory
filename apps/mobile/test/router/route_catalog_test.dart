import 'dart:io';

import 'package:archiveme_mobile/router/archive_changes_deep_link.dart';
import 'package:archiveme_mobile/router/developer_route_guard.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 shell exposes three ordered canonical destinations', () {
    expect(RouteCatalog.primaryRoutes, [
      '/record',
      '/archive-belief',
      '/account',
    ]);
    expect(RouteCatalog.primaryRoutes, hasLength(3));
    expect(RouteCatalog.changesHome, '/belief-changes');
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
    expect(
      DeveloperRouteGuard.redirectFor('/discover-changes'),
      ArchiveChangesDeepLink.nestedChangesPath,
    );
    for (final alias in DeveloperRouteGuard.legacyRedirects.entries) {
      if (alias.key == '/discover-changes') continue;
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