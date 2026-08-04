import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/errors/domain_exception.dart';

enum PurchaseFailureKind {
  cancelled,
  temporary,
  pending,
  productUnavailable,
  verification,
  unexpected,
}

class PurchaseFailure implements UserFacingException {
  const PurchaseFailure(this.kind, {required this.cause});

  final PurchaseFailureKind kind;
  @override
  final Object cause;

  bool get isCancelled => kind == PurchaseFailureKind.cancelled;

  @override
  String get userMessage => switch (kind) {
    PurchaseFailureKind.cancelled => '',
    PurchaseFailureKind.temporary =>
      'The store is temporarily unreachable. Check your connection and try again.',
    PurchaseFailureKind.pending =>
      'This purchase is already pending. Pro will activate after the store confirms it.',
    PurchaseFailureKind.productUnavailable =>
      'This plan is not available right now. Please try again later.',
    PurchaseFailureKind.verification =>
      'The store could not verify this purchase. Try Restore Purchases.',
    PurchaseFailureKind.unexpected =>
      'Purchase could not be completed. Please try again.',
  };

  @override
  String get userFacingCode => 'PURCHASE_${kind.name.toUpperCase()}';

  @override
  String toString() => 'PurchaseFailure(${kind.name}, $cause)';
}

abstract final class PurchaseFailureMapper {
  static PurchaseFailure from(Object error) {
    if (error is PurchaseFailure) return error;
    if (error is TimeoutException) {
      return PurchaseFailure(PurchaseFailureKind.temporary, cause: error);
    }
    if (error is! PlatformException) {
      return PurchaseFailure(PurchaseFailureKind.unexpected, cause: error);
    }

    PurchasesErrorCode code;
    try {
      code = PurchasesErrorHelper.getErrorCode(error);
    } on Object {
      return PurchaseFailure(PurchaseFailureKind.unexpected, cause: error);
    }

    final kind = switch (code) {
      PurchasesErrorCode.purchaseCancelledError =>
        PurchaseFailureKind.cancelled,
      PurchasesErrorCode.networkError ||
      PurchasesErrorCode.offlineConnectionError ||
      PurchasesErrorCode.storeProblemError ||
      PurchasesErrorCode.productRequestTimeout ||
      PurchasesErrorCode.apiEndpointBlocked ||
      PurchasesErrorCode.unknownBackendError => PurchaseFailureKind.temporary,
      PurchasesErrorCode.paymentPendingError ||
      PurchasesErrorCode.operationAlreadyInProgressError ||
      PurchasesErrorCode.productAlreadyPurchasedError =>
        PurchaseFailureKind.pending,
      PurchasesErrorCode.productNotAvailableForPurchaseError ||
      PurchasesErrorCode.configurationError ||
      PurchasesErrorCode.invalidCredentialsError ||
      PurchasesErrorCode.purchaseNotAllowedError =>
        PurchaseFailureKind.productUnavailable,
      PurchasesErrorCode.invalidReceiptError ||
      PurchasesErrorCode.missingReceiptFileError ||
      PurchasesErrorCode.receiptAlreadyInUseError ||
      PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
      PurchasesErrorCode.signatureVerificationFailed =>
        PurchaseFailureKind.verification,
      _ => PurchaseFailureKind.unexpected,
    };
    return PurchaseFailure(kind, cause: error);
  }
}

class RestorePurchasesUnavailableException implements UserFacingException {
  const RestorePurchasesUnavailableException({required this.cause});

  @override
  final Object cause;

  @override
  String get userMessage =>
      'Purchases could not be checked. Connect to the internet and try again.';

  @override
  String get userFacingCode => 'RESTORE_PURCHASES_UNAVAILABLE';

  @override
  String toString() => 'RestorePurchasesUnavailableException($cause)';
}
