import '../subscriptions/domain/subscription_models.dart';
import '../subscriptions/domain/subscription_repository.dart';

class SubscriptionOperationInProgressException implements Exception {
  const SubscriptionOperationInProgressException();
}

/// Single transaction boundary for purchase and restore entry points.
///
/// It rejects duplicate taps, serializes purchase/restore, and performs an
/// immediate entitlement refresh before reporting success.
class SubscriptionPurchaseCoordinator {
  factory SubscriptionPurchaseCoordinator({
    required SubscriptionRepository repository,
  }) {
    return _instances[repository] ??= SubscriptionPurchaseCoordinator._(
      repository,
    );
  }

  SubscriptionPurchaseCoordinator._(this.repository);

  static final Expando<SubscriptionPurchaseCoordinator> _instances =
      Expando<SubscriptionPurchaseCoordinator>();

  final SubscriptionRepository repository;
  Future<SubscriptionState>? _operation;

  bool get isBusy => _operation != null;

  Future<SubscriptionState> purchase(SubscriptionOffer offer) => _run(
    () async {
      final purchased = await repository.purchase(offer.id);
      final refreshed = await repository.refresh(force: true);
      return _selectRefreshedState(purchased, refreshed);
    },
    duplicateError: const SubscriptionPurchaseException(
      SubscriptionPurchaseFailureKind.pending,
      cause: SubscriptionOperationInProgressException(),
    ),
  );

  Future<SubscriptionState> restore() => _run(() async {
    final restored = await repository.restore();
    final refreshed = await repository.refresh(force: true);
    return _selectRefreshedState(restored, refreshed);
  }, duplicateError: const SubscriptionOperationInProgressException());

  static SubscriptionState _selectRefreshedState(
    SubscriptionState operationState,
    SubscriptionState refreshed,
  ) {
    if (refreshed.isVerified) return refreshed;
    return refreshed.isPro ? refreshed : operationState;
  }

  Future<SubscriptionState> _run(
    Future<SubscriptionState> Function() operation, {
    required Object duplicateError,
  }) {
    if (_operation != null) {
      return Future<SubscriptionState>.error(duplicateError);
    }
    final future = operation();
    _operation = future;
    return future.whenComplete(() {
      if (identical(_operation, future)) _operation = null;
    });
  }
}
