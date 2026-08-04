import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/revenuecat_diagnostics.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  group('RevenueCat offerings expectations', () {
    test('purchase entitlement id is the canonical ArchiveMe id', () {
      expect(RevenueCatService.proEntitlementId, 'archive_loop_pro');
    });

    test('diagnostics record current offering not a hardcoded default id', () {
      const d = RevenueCatDiagnostics(
        revenueCatConfigured: true,
        apiKeyMissing: false,
        offeringsLoaded: true,
        offeringCount: 1,
        packageCount: 2,
        requestedOfferingId: 'current',
        currentOfferingId: 'default',
      );
      expect(d.requestedOfferingId, 'current');
      expect(d.currentOfferingId, isNotNull);
    });

    test('store adapter maps PackageType monthly and annual', () {
      final source = File(
        'lib/subscriptions/data/revenuecat_subscription_data_source.dart',
      ).readAsStringSync();
      expect(source, contains('PackageType.monthly'));
      expect(source, contains('PackageType.annual'));
      expect(source, contains('offerings?.current'));
    });

    test('availability gate validates current offering and exact products', () {
      final source = File(
        'lib/subscriptions/data/revenuecat_subscription_data_source.dart',
      ).readAsStringSync();
      final config = File(
        'lib/billing/revenuecat_configuration.dart',
      ).readAsStringSync();
      expect(source, contains('availablePackages'));
      expect(source, contains('configuration.validateOffers'));
      expect(config, contains('monthly_product_mismatch'));
      expect(config, contains('yearly_product_mismatch'));
    });

    test('the paywall preselects the annual offer', () {
      // lib/billing/archive_paywall_plans.dart was folded into the paywall,
      // which now picks the preferred offer itself.
      final preferred = _methodBody(
        File('lib/screens/paywall_screen.dart').readAsStringSync(),
        'static SubscriptionOffer? _preferredOffer(',
      );

      expect(preferred, contains('SubscriptionPeriod.annual'));
      expect(
        preferred,
        contains('offers.firstOrNull'),
        reason:
            'With no annual package the paywall must still offer some '
            'plan rather than showing nothing.',
      );
    });

    test('legacy paywall plans module stays deleted', () {
      expect(
        File('lib/billing/archive_paywall_plans.dart').existsSync(),
        isFalse,
        reason:
            'Plan ordering belongs to the paywall now. Two sources of '
            'truth is how the displayed plan and the purchased one diverge.',
      );
    });

    test('unavailable copy is separate from billing configured state', () {
      expect(
        ConsumerUiCopy.paywallSetupUnavailableBody,
        'Purchases are not available right now.',
      );
      expect(
        ConsumerUiCopy.paywallBillingNotConfigured,
        contains('Purchases are not available right now'),
      );
    });

    test('invalid offering logs a privacy-safe rejection code', () {
      final source = File(
        'lib/subscriptions/data/revenuecat_subscription_data_source.dart',
      ).readAsStringSync();
      expect(source, contains('RevenueCat offering rejected:'));
      expect(source, contains('purchase controls disabled'));
    });

    test('paywall restore path does not gate on package availability', () {
      // Sliced to the method's own closing brace rather than to whichever
      // member happened to follow it. The previous anchor was deleted, the
      // slice silently became invalid, and the test failed for a reason
      // unrelated to restore.
      final restoreBody = _methodBody(
        File('lib/screens/paywall_screen.dart').readAsStringSync(),
        'Future<void> _restore() async {',
      );

      // A purchase can be refused when no package loads. A restore may not:
      // someone who already paid has to be able to get their access back on a
      // new device, which is also what the stores require.
      expect(
        restoreBody,
        contains('_restoreFlow.restore()'),
        reason:
            'The paywall must use the canonical restore coordinator rather '
            'than creating a second restore path.',
      );
      for (final gate in [
        'offers.isEmpty',
        '_offers.isEmpty',
        'packagesAvailable',
        'plansAvailable',
        'billingNotConfigured',
      ]) {
        expect(
          restoreBody,
          isNot(contains(gate)),
          reason: 'Restore must not be gated on $gate.',
        );
      }
    });

    test('standalone restore remains visible when offerings are unavailable', () {
      final source = File(
        'lib/screens/restore_purchases_screen.dart',
      ).readAsStringSync();

      expect(source, contains('FilledButton('));
      expect(source, contains('onPressed: _busy ? null : _restore'));
      expect(
        source,
        isNot(contains('subscriptionsAvailable')),
        reason:
            'An unavailable offering may block a new purchase, not restoration.',
      );
      expect(source, isNot(contains('SubscriptionAvailability.available')));
    });

    test('debug offerings log module exists for device QA', () {
      final logSource = File(
        'lib/billing/revenuecat_offerings_debug_log.dart',
      ).readAsStringSync();
      expect(logSource, contains('ARCHIVEME_RC_PAYWALL_LOAD'));
      expect(logSource, contains('ARCHIVEME_RC_FETCH'));
      expect(logSource, contains('ARCHIVEME_RC_OFFERINGS'));
      expect(logSource, contains('ARCHIVEME_RC_OFFERING_IDS'));
      expect(logSource, contains('ARCHIVEME_RC_PACKAGE'));
      expect(logSource, contains('ARCHIVEME_RC_ENTITLEMENTS'));
      expect(logSource, contains('ARCHIVEME_RC_PAYWALL'));
    });
  });
}

/// The body of the member starting at [signature], to its closing brace.
///
/// Brace counting, so the slice ends with the method rather than at the next
/// member name. Anchoring on a neighbour is what let an unrelated rename break
/// these assertions.
String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    fail('$signature not found. If it was renamed, update this guard.');
  }

  var depth = 0;
  for (var i = source.indexOf('{', start); i < source.length; i++) {
    final char = source[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  fail('$signature is never closed.');
}
