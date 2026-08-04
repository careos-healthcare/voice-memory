import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/router/legacy_route_aliases.dart';
import 'package:voicememory_mobile/router/route_catalog.dart';

void main() {
  test('router file lists primary routes', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    for (final route in [
      RouteCatalog.recordHome,
      RouteCatalog.archiveHome,
      'RouteCatalog.changesHome',
      '/weekly-story',
      '/archive-debug',
      RouteCatalog.accountHome,
      '/onboarding',
      '/self-discovery',
      '/updates',
      '/pricing',
      '/export',
      '/delete-account',
      '/settings',
      '/about',
    ]) {
      expect(router.contains(route), isTrue, reason: route);
    }
    expect(router.contains('/life-os/graph'), isFalse);
    expect(
      LegacyRouteAliases.redirects.keys,
      containsAll(['/memory', '/discover', '/search', '/timeline']),
    );
    expect(router.contains('/internal'), isFalse);
    expect(router.contains('founder-test'), isFalse);
    expect(router.contains('initialLocation: RouteCatalog.recordHome'), isTrue);
    expect(
      router.contains("entries.isNotEmpty && state.uri.path == '/record'"),
      isFalse,
      reason: 'Record tab must stay reachable when journal has entries',
    );
  });
}
