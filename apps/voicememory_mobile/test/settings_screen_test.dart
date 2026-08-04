import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The V1 reduction replaced `settings_screen.dart` with a much smaller
/// surface. This suite follows it there rather than guarding a deleted file.
const _settings = 'lib/screens/v1_settings_screen.dart';

void main() {
  test('settings lists the V1 consumer rows', () {
    final src = File(_settings).readAsStringSync();

    for (final row in [
      'Archive lock',
      '_ProcessingControlsTile',
      'Privacy centre',
      'Export archive',
      'Restore purchases',
      'About ArchiveMe',
      'Privacy policy',
      'Terms',
      '_VersionTile',
    ]) {
      expect(src, contains(row), reason: row);
    }
  });

  test('export is reachable from settings and is not gated', () {
    final src = File(_settings).readAsStringSync();

    final exportIndex = src.indexOf("route: '/export'");
    expect(exportIndex, greaterThan(-1), reason: 'Export must be reachable.');

    // Export is a portability guarantee, so nothing between the row and its
    // route may make it conditional on entitlement.
    for (final gate in ['isPro', 'entitlement', 'requiresPro', 'paywall']) {
      expect(
        src.toLowerCase(),
        isNot(contains(gate.toLowerCase())),
        reason: 'Export and the settings rows must not be entitlement gated.',
      );
    }
  });

  // Study mode and the real-user protocols run production behaviour, so no
  // debug affordance may be reachable from a shipping settings screen.
  test('no developer or diagnostic surfaces are exposed', () {
    final src = File(_settings).readAsStringSync();

    for (final forbidden in [
      'Developer',
      'diagnostic',
      'API base URL',
      'Backend health',
      'debug',
    ]) {
      expect(
        src.toLowerCase(),
        isNot(contains(forbidden.toLowerCase())),
        reason: forbidden,
      );
    }
  });
}
