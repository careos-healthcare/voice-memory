import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/api/api_error_copy.dart';
import 'package:archiveme_mobile/api/api_error_user_message.dart';
import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/billing/billing_async_guard.dart';
import 'package:archiveme_mobile/billing/restore_purchases_copy.dart';
import 'package:archiveme_mobile/billing/subscription_copy.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

export 'package:archiveme_mobile/api/api_error_user_message.dart'
    show cloudBackendUnavailableMessage;

/// Maps errors to calm, user-facing copy — never stack traces or ApiException(...) formatting.
String userFacingErrorMessage(
  Object error, {
  String fallback = ApiErrorCopy.genericFallback,
}) {
  return switch (error) {
    ApiFailure failure => userMessageForApiFailure(failure, fallback: fallback),
    BackendNotConfiguredException() => cloudBackendUnavailableMessage,
    ApiException exception =>
      userMessageForApiException(exception, fallback: fallback),
    RecordingException(:final message) => _nonEmptyOrFallback(message, fallback),
    CapturePipelineFailure(:final message) =>
      _nonEmptyOrFallback(message, fallback),
    BillingOperationException(:final cause) =>
      _messageForBillingOperation(cause, fallback),
    PlatformException exception =>
      _messageForPlatformException(exception, fallback),
    SocketException _ => _messageForSocketException(),
    TimeoutException _ => ApiErrorCopy.requestTimedOut,
    String _ => fallback,
    _ => fallback,
  };
}

/// Legacy alias — prefer [userFacingErrorMessage] in UI.
String formatApiErrorMessage(Object error) => userFacingErrorMessage(error);

String _nonEmptyOrFallback(String message, String fallback) {
  final trimmed = message.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _messageForBillingOperation(Object? cause, String fallback) {
  if (cause != null) {
    return userFacingErrorMessage(cause, fallback: fallback);
  }
  return RestorePurchasesCopy.restoreError;
}

String _messageForPlatformException(PlatformException error, String fallback) {
  final purchasesCode = _purchasesErrorCodeFromPlatform(error);
  if (purchasesCode != null) {
    return _messageForPurchasesErrorCode(purchasesCode, fallback);
  }

  return switch (error.code) {
    'UNAVAILABLE' || 'billing_unavailable' =>
      SubscriptionCopy.temporarilyUnavailable,
    _ => fallback,
  };
}

PurchasesErrorCode? _purchasesErrorCodeFromPlatform(PlatformException error) {
  if (int.tryParse(error.code) == null) {
    return null;
  }
  try {
    return PurchasesErrorHelper.getErrorCode(error);
  } on FormatException {
    return null;
  }
}

String _messageForPurchasesErrorCode(PurchasesErrorCode code, String fallback) {
  switch (code) {
    case PurchasesErrorCode.purchaseCancelledError:
      return ApiErrorCopy.purchaseCancelled;
    case PurchasesErrorCode.networkError:
    case PurchasesErrorCode.offlineConnectionError:
    case PurchasesErrorCode.productRequestTimeout:
      return ApiErrorCopy.networkUnreachable;
    case PurchasesErrorCode.configurationError:
    case PurchasesErrorCode.invalidCredentialsError:
    case PurchasesErrorCode.storeProblemError:
    case PurchasesErrorCode.unexpectedBackendResponseError:
    case PurchasesErrorCode.unknownBackendError:
    case PurchasesErrorCode.apiEndpointBlocked:
      return SubscriptionCopy.temporarilyUnavailable;
    case PurchasesErrorCode.productNotAvailableForPurchaseError:
    case PurchasesErrorCode.productDiscountMissingIdentifierError:
    case PurchasesErrorCode
        .productDiscountMissingSubscriptionGroupIdentifierError:
      return SubscriptionCopy.paywallNoOfferings;
    case PurchasesErrorCode.purchaseNotAllowedError:
    case PurchasesErrorCode.insufficientPermissionsError:
      return SubscriptionCopy.paywallNoOfferings;
    default:
      return RestorePurchasesCopy.restoreError;
  }
}

String _messageForSocketException() {
  if (!AppConfig.isBackendConfigured) {
    return cloudBackendUnavailableMessage;
  }
  if (AppConfig.looksLikeLocalhost) {
    return ApiErrorCopy.localDeviceConnectionHint;
  }
  return ApiErrorCopy.networkUnreachable;
}
