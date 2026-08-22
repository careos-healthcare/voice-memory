import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('router file lists primary routes', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    for (final route in [
      '/record',
      '/archive-belief',
      '/memory',
      '/discover-yourself',
      '/belief-changes',
      '/weekly-story',
      '/discover',
      '/archive-debug',
      '/search',
      '/timeline',
      '/account',
      '/onboarding',
      '/blind-spots',
      '/updates',
      '/pricing',
      '/export',
      '/delete-account',
      '/settings',
      '/about',
    ]) {
      expect(router.contains(route), isTrue, reason: route);
    }
    expect(router.contains('/internal'), isFalse);
    expect(router.contains('founder-test'), isFalse);
    expect(router.contains("initialLocation: '/record'"), isTrue);
    expect(
      router.contains("entries.isNotEmpty && state.uri.path == '/record'"),
      isFalse,
      reason: 'Record tab must stay reachable when journal has entries',
    );
  });
}