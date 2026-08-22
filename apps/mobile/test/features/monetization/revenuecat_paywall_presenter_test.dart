import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/features/monetization/presentation/models/paywall_result.dart';
import 'package:archiveme_mobile/features/monetization/presentation/services/revenuecat_paywall_presenter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' as purchases_ui;

void main() {
  group('RevenueCatPaywallPresenter', () {
    testWidgets(
      'falls back to subscription route when paywall gate is closed',
      (tester) async {
        var fallbackCalls = 0;
        PaywallRouteArgs? capturedArgs;
        final presenter = RevenueCatPaywallPresenter(
          canOpenPaywall: () async => false,
          openFallbackRouteOverride: (context, args) async {
            fallbackCalls++;
            capturedArgs = args;
          },
        );

        final result = await _triggerFromHost(tester, presenter);

        expect(result, PaywallResult.fallbackRoute);
        expect(fallbackCalls, 1);
        expect(capturedArgs?.source, PaywallSource.valueMoment);
        expect(capturedArgs?.sourceRoute, '/record');
      },
    );

    testWidgets('presents native paywall with close button when gate opens', (
      tester,
    ) async {
      var paywallCalls = 0;
      var closeButtonEnabled = false;
      final presenter = RevenueCatPaywallPresenter(
        canOpenPaywall: () async => true,
        presentPaywallOverride: ({offering, displayCloseButton = false}) async {
          paywallCalls++;
          closeButtonEnabled = displayCloseButton;
          return purchases_ui.PaywallResult.cancelled;
        },
      );

      final result = await _triggerFromHost(tester, presenter);

      expect(paywallCalls, 1);
      expect(closeButtonEnabled, isTrue);
      expect(result, PaywallResult.cancelled);
    });

    testWidgets('falls back when native paywall returns error', (tester) async {
      var fallbackCalls = 0;
      final presenter = RevenueCatPaywallPresenter(
        canOpenPaywall: () async => true,
        presentPaywallOverride: ({offering, displayCloseButton = false}) async {
          return purchases_ui.PaywallResult.error;
        },
        openFallbackRouteOverride: (_, _) async {
          fallbackCalls++;
        },
      );

      final result = await _triggerFromHost(tester, presenter);

      expect(fallbackCalls, 1);
      expect(result, PaywallResult.fallbackRoute);
    });

    testWidgets('returns purchased when entitlement verification succeeds', (
      tester,
    ) async {
      final presenter = RevenueCatPaywallPresenter(
        canOpenPaywall: () async => true,
        presentPaywallOverride: ({offering, displayCloseButton = false}) async {
          return purchases_ui.PaywallResult.purchased;
        },
        getCustomerInfoOverride: () async => _customerInfo(proActive: true),
      );

      final result = await _triggerFromHost(
        tester,
        presenter,
        requiredEntitlementId: 'pro',
      );

      expect(result, PaywallResult.purchased);
    });

    testWidgets('returns restored when native restore verifies entitlement', (
      tester,
    ) async {
      final presenter = RevenueCatPaywallPresenter(
        canOpenPaywall: () async => true,
        presentPaywallOverride: ({offering, displayCloseButton = false}) async {
          return purchases_ui.PaywallResult.restored;
        },
        getCustomerInfoOverride: () async => _customerInfo(proActive: true),
      );

      final result = await _triggerFromHost(
        tester,
        presenter,
        requiredEntitlementId: 'pro',
      );

      expect(result, PaywallResult.restored);
    });

    testWidgets('presentIfNeeded delegates to native conditional presenter', (
      tester,
    ) async {
      var ifNeededCalls = 0;
      String? capturedEntitlement;
      var closeButtonEnabled = false;
      final presenter = RevenueCatPaywallPresenter(
        canOpenPaywall: () async => true,
        presentPaywallIfNeededOverride:
            (
              requiredEntitlementIdentifier, {
              offering,
              displayCloseButton = false,
            }) async {
              ifNeededCalls++;
              capturedEntitlement = requiredEntitlementIdentifier;
              closeButtonEnabled = displayCloseButton;
              return purchases_ui.PaywallResult.notPresented;
            },
      );

      PaywallResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await presenter.presentIfNeeded('pro');
                },
                child: const Text('trigger'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(ifNeededCalls, 1);
      expect(capturedEntitlement, 'pro');
      expect(closeButtonEnabled, isTrue);
      expect(result, PaywallResult.notPresented);
    });
  });
}

Future<PaywallResult> _triggerFromHost(
  WidgetTester tester,
  RevenueCatPaywallPresenter presenter, {
  String? requiredEntitlementId,
}) async {
  late BuildContext hostContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          hostContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return presenter.triggerNativePaywallSheet(
    requiredEntitlementId: requiredEntitlementId,
    fallbackContext: hostContext,
    fallbackArgs: const PaywallRouteArgs(
      source: PaywallSource.valueMoment,
      sourceRoute: '/record',
    ),
  );
}

CustomerInfo _customerInfo({required bool proActive}) {
  final entitlement = <String, dynamic>{
    'identifier': 'pro',
    'isActive': proActive,
    'willRenew': proActive,
    'latestPurchaseDate': '2026-01-01T00:00:00Z',
    'originalPurchaseDate': '2026-01-01T00:00:00Z',
    'productIdentifier': 'pro_monthly',
    'isSandbox': false,
    'periodType': 'NORMAL',
    'ownershipType': 'PURCHASED',
    'store': 'APP_STORE',
    'verification': 'NOT_REQUESTED',
  };

  return CustomerInfo.fromJson(<String, dynamic>{
    'entitlements': <String, dynamic>{
      'all': <String, dynamic>{'pro': entitlement},
      'active': proActive
          ? <String, dynamic>{'pro': entitlement}
          : <String, dynamic>{},
      'verification': 'NOT_REQUESTED',
    },
    'allPurchaseDates': proActive
        ? <String, dynamic>{'pro_monthly': '2026-01-01T00:00:00Z'}
        : <String, dynamic>{},
    'activeSubscriptions': proActive ? <String>['pro_monthly'] : <String>[],
    'allPurchasedProductIdentifiers': proActive
        ? <String>['pro_monthly']
        : <String>[],
    'nonSubscriptionTransactions': <dynamic>[],
    'firstSeen': '2026-01-01T00:00:00Z',
    'originalAppUserId': 'test-user',
    'allExpirationDates': proActive
        ? <String, dynamic>{'pro_monthly': '2099-01-01T00:00:00Z'}
        : <String, dynamic>{},
    'requestDate': '2026-01-01T00:00:00Z',
    'latestExpirationDate': proActive ? '2099-01-01T00:00:00Z' : null,
  });
}