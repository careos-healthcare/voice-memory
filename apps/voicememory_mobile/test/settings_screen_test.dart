import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings screen lists consumer items', () {
    final src = File('lib/screens/settings_screen.dart').readAsStringSync();
    for (final label in [
      'ConsumerUiCopy.privacyPolicy',
      'ConsumerUiCopy.termsOfUse',
      'ConsumerUiCopy.restorePurchases',
      'ConsumerUiCopy.exportReflections',
      'ConsumerUiCopy.deleteAccount',
      'ConsumerUiCopy.appVersion',
    ]) {
      expect(src, contains(label), reason: label);
    }
  });

  test('developer tools are behind developer gate', () {
    final src = File('lib/screens/settings_screen.dart').readAsStringSync();
    final gateIndex = src.indexOf('canShowDeveloperSettings');
    expect(gateIndex, greaterThan(-1));
    expect(src.indexOf('Developer diagnostics'), greaterThan(gateIndex));
    expect(src.indexOf('API base URL'), equals(-1));
    expect(src.indexOf('Backend health'), equals(-1));
  });
}
