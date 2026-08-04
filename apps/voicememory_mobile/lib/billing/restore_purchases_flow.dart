import '../subscriptions/domain/subscription_models.dart';
import '../subscriptions/domain/subscription_repository.dart';
import 'restore_purchases_copy.dart';
import 'subscription_purchase_coordinator.dart';

enum RestorePurchasesOutcome {
  restored,
  cachedAccessRetained,
  noPurchase,
  unavailable,
  error,
  skippedBusy,
}

class RestorePurchasesResult {
  const RestorePurchasesResult({
    required this.outcome,
    this.subscriptionState,
    this.error,
  });

  final RestorePurchasesOutcome outcome;
  final SubscriptionState? subscriptionState;
  final Object? error;

  bool get isPro => subscriptionState?.isPro ?? false;

  String get userMessage => switch (outcome) {
    RestorePurchasesOutcome.restored => RestorePurchasesCopy.purchaseRestored,
    RestorePurchasesOutcome.cachedAccessRetained =>
      RestorePurchasesCopy.cachedAccessRetained,
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
    required this.repository,
    SubscriptionPurchaseCoordinator? coordinator,
  }) : _coordinator =
           coordinator ??
           SubscriptionPurchaseCoordinator(repository: repository);

  final SubscriptionRepository repository;
  final SubscriptionPurchaseCoordinator _coordinator;

  bool get isBusy => _coordinator.isBusy;

  Future<RestorePurchasesResult> restore() async {
    if (_coordinator.isBusy) {
      return const RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.skippedBusy,
      );
    }
    try {
      final state = await _coordinator.restore();
      return RestorePurchasesResult(
        outcome: state.verification == SubscriptionVerification.cached
            ? RestorePurchasesOutcome.cachedAccessRetained
            : state.isPro
            ? RestorePurchasesOutcome.restored
            : RestorePurchasesOutcome.noPurchase,
        subscriptionState: state,
      );
    } on SubscriptionOperationInProgressException {
      return const RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.skippedBusy,
      );
    } on SubscriptionRestoreException catch (e) {
      return RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.unavailable,
        error: e,
      );
    } catch (e) {
      return RestorePurchasesResult(
        outcome: RestorePurchasesOutcome.error,
        error: e,
      );
    }
  }
}
