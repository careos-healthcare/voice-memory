import 'dart:io';

import 'package:archiveme_mobile/billing/revenuecat_diagnostics.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevenueCat offerings expectations', () {
    test('purchase entitlement id is pro only', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
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

    test('paywall package selection uses PackageType monthly and annual', () {
      final paywallSource = File(
        'lib/screens/paywall_screen.dart',
      ).readAsStringSync();
      expect(paywallSource, contains('PackageType.monthly'));
      expect(paywallSource, contains('PackageType.annual'));
      expect(paywallSource, contains('offerings?.current'));
      expect(paywallSource, isNot(contains('getOffering(')));
    });

    test(
      'availability gate checks current offering package count not store ids',
      () {
        final paywallSource = File(
          'lib/screens/paywall_screen.dart',
        ).readAsStringSync();
        expect(paywallSource, contains('availablePackages'));
        expect(paywallSource, isNot(contains('storeProduct.identifier ==')));
      },
    );

    test('archive paywall plans match by package type not identifier', () {
      final plansSource = File(
        'lib/billing/archive_paywall_plans.dart',
      ).readAsStringSync();
      expect(plansSource, contains('PackageType.annual'));
      expect(plansSource, contains('PackageType.monthly'));
      expect(plansSource, isNot(contains('identifier ==')));
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

    test('paywall load always logs final purchase availability decision', () {
      final paywallSource = File(
        'lib/screens/paywall_screen.dart',
      ).readAsStringSync();
      expect(
        paywallSource,
        contains('RevenueCatOfferingsDebugLog.paywallLoadStarted'),
      );
      expect(paywallSource, contains('rc.fetchOfferings()'));
      expect(
        paywallSource,
        contains('RevenueCatOfferingsDebugLog.paywallLoadResult'),
      );
    });

    test('paywall restore path does not gate on package availability', () {
      final paywallSource = File(
        'lib/screens/paywall_screen.dart',
      ).readAsStringSync();
      final restoreStart = paywallSource.indexOf('Future<void> _restore()');
      final restoreEnd = paywallSource.indexOf(
        'Future<void> _dismissWithCapture',
        restoreStart,
      );
      expect(restoreStart, greaterThan(0));
      expect(restoreEnd, greaterThan(restoreStart));
      final restoreBody = paywallSource.substring(restoreStart, restoreEnd);
      expect(restoreBody, contains('_effectiveRestoreFlow'));
      expect(restoreBody, isNot(contains('_purchasePlansAvailable')));
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