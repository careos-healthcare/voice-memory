import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/v1/paywall_controller.dart';
import 'package:voicememory_mobile/models/entitlement.dart';

void main() {
  test('initial paywall state blocks purchase until offerings load', () {
    const state = PaywallState();
    expect(state.loadingOfferings, isTrue);
    expect(state.canPurchase, isFalse);
    expect(state.tier, BillingTier.free);
  });

  test('paywall controller replaces immutable state without mutation', () {
    final controller = PaywallController();
    expect(controller.state.loadingOfferings, isTrue);

    controller.replace(
      controller.state.copyWith(
        loadingOfferings: false,
        unavailable: true,
        errorMessage: 'Store unavailable',
      ),
    );

    expect(controller.state.loadingOfferings, isFalse);
    expect(controller.state.unavailable, isTrue);
    expect(controller.state.errorMessage, 'Store unavailable');
    expect(controller.state.canPurchase, isFalse);
  });

  test('purchase and restore flags are mutually guarded', () {
    const ready = PaywallState(loadingOfferings: false, unavailable: false);
    expect(
      ready.copyWith(purchaseInFlight: true).canPurchase,
      isFalse,
    );
    expect(
      ready.copyWith(restoreInFlight: true).canPurchase,
      isFalse,
    );
  });
}
