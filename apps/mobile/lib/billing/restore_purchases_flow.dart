import 'package:archiveme_mobile/billing/billing_async_guard.dart';
import 'package:archiveme_mobile/billing/billing_service.dart';
import 'package:archiveme_mobile/billing/restore_purchases_copy.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/models/entitlement.dart';

enum RestorePurchasesOutcome {
  restored,
  noPurchase,
  unavailable,
  error,
  skippedBusy,
}

class RestorePurchasesResult {
  const RestorePurchasesResult({
    required this.outcome,
    this.entitlements,
    this.error,
  });

  final RestorePurchasesOutcome outcome;
  final PremiumEntitlements? entitlements;
  final Object? error;

  bool get isPro => entitlements?.isPro ?? false;

  String get userMessage => switch (outcome) {
    RestorePurchasesOutcome.restored => RestorePurchasesCopy.purchaseRestored,
    RestorePurchasesOutcome.noPurchase => RestorePurchasesCopy.noActivePurchase,
    RestorePurchasesOutcome.unavailable =>
      RestorePurchasesCopy.billingUnavailable,
    RestorePurchasesOutcome.error => RestorePurchasesCopy.restoreError,
    RestorePurchasesOutcome.skippedBusy => '',
  };
}

/// Shared restore flow — loading guard, entitlement refresh, calm outcomes.
class RestorePurchasesFlow {
  RestorePurchasesFlow({
    required this._billing,
    bool Function()? isBillingConfigured,
  }) : _isBillingConfigured =
           isBillingConfigured ??
           (() => RevenueCatService.instance.isConfigured);

  final BillingService _billing;
  final bool Function() _isBillingConfigured;

  bool _busy = false;

  bool get isBusy => _busy;

  Future<RestorePurchasesResult> restore() async {
    if (_busy) {
      return const RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.skippedBusy,
      );
    }
    if (!_isBillingConfigured()) {
      return const RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.unavailable,
      );
    }

    _busy = true;
    try {
      final ent = await _billing.restoreNative();
      return RestorePurchasesResult(
        outcome: ent.isPro
            ? RestorePurchasesOutcome.restored
            : RestorePurchasesOutcome.noPurchase,
        entitlements: ent,
      );
    } on BillingOperationException catch (e, stackTrace) {
      return RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.unavailable,
        error: e,
      );
    } catch (e, stackTrace) {
      return RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.error,
        error: e,
      );
    } finally {
      _busy = false;
    }
  }
}