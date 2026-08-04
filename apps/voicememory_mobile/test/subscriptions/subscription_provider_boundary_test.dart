import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('store SDK imports remain inside subscription infrastructure', () {
    const allowed = <String>{
      'lib/billing/purchase_failure.dart',
      'lib/billing/billing_platform.dart',
      'lib/billing/revenuecat_diagnostics_log.dart',
      'lib/billing/revenuecat_offerings_debug_log.dart',
      'lib/billing/revenuecat_service.dart',
      'lib/features/monetization/presentation/services/'
          'revenuecat_paywall_presenter.dart',
      'lib/subscriptions/data/revenuecat_subscription_data_source.dart',
    };
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relativePath = p.posix.normalize(
        p.relative(entity.path).replaceAll(r'\', '/'),
      );
      if (allowed.contains(relativePath)) continue;

      final source = entity.readAsStringSync();
      if (source.contains("package:purchases_flutter/") ||
          source.contains("package:purchases_ui_flutter/")) {
        violations.add(relativePath);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'RevenueCat SDK types must not cross the subscription data-source '
          'or native-paywall launcher boundary.',
    );
  });
}
