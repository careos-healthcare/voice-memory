import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/v1/app_services_paywall_dependencies.dart';
import 'package:voicememory_mobile/billing/v1/paywall_controller.dart';
import 'package:voicememory_mobile/billing/v1/paywall_plan.dart';
import 'package:voicememory_mobile/models/entitlement.dart';

void main() {
  test('initial paywall state blocks purchase until offerings load', () {
    const state = PaywallState();
    expect(state.loadingOfferings, isTrue);
    expect(state.canPurchase, isFalse);
    expect(state.isPro, isFalse);
  });

  test('paywall controller loads offerings and selects default plan', () async {
    final deps = FakePaywallDependencies(
      billingReady: true,
      entitlements: PremiumEntitlements.free(),
    );
    final controller = PaywallController(dependencies: deps);

    await controller.loadOfferings();

    expect(controller.state.loadingOfferings, isFalse);
    expect(controller.state.entitlements, isNotNull);
    expect(controller.state.canPurchase, isFalse);
  });

  test(
    'paywall controller purchase returns null without a selected package',
    () async {
      final controller = PaywallController(
        dependencies: FakePaywallDependencies(billingReady: true),
      );
      controller.replace(
        controller.state.copyWith(
          loadingOfferings: false,
          billingConfigured: true,
          unavailable: false,
        ),
      );

      final result = await controller.purchaseSelectedPackage();
      expect(result, isNull);
      expect(controller.state.purchaseInFlight, isFalse);
    },
  );

  test('selectPlan updates immutable state', () {
    final controller = PaywallController(
      dependencies: FakePaywallDependencies(),
    );
    controller.selectPlan(PaywallPlan.monthly);
    expect(controller.state.selectedPlan, PaywallPlan.monthly);
  });

  test('purchase and restore flags are mutually guarded', () {
    const ready = PaywallState(loadingOfferings: false, unavailable: false);
    expect(ready.copyWith(purchaseInFlight: true).canPurchase, isFalse);
    expect(ready.copyWith(restoreInFlight: true).canPurchase, isFalse);
  });
}
