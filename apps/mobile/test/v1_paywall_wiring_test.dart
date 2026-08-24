import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paywall screen delegates billing load to PaywallController', () {
    final source = File('lib/billing/screens/paywall_screen.dart').readAsStringSync();
    expect(source, contains('PaywallController'));
    expect(source, contains('loadOfferings'));
    expect(source, contains('purchaseSelectedPackage'));
    expect(source, contains('_ps.purchaseInFlight'));
    expect(
      source,
      isNot(contains('RevenueCatOfferingsDebugLog.paywallLoadStarted')),
    );
  });
}