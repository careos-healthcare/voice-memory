import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../audio/recording_service.dart';
import '../billing/billing_async_guard.dart';
import '../billing/restore_purchases_copy.dart';
import '../billing/subscription_copy.dart';
import '../config/app_config.dart';
import '../core/network/api_failure.dart';
import '../services/capture_pipeline_service.dart';
import 'api_error_copy.dart';
import 'api_exceptions.dart';

/// Shown when cloud/API features need a configured backend URL.
const String cloudBackendUnavailableMessage =
    'Cloud features are unavailable because a backend connection has not been configured.';

/// Maps errors to calm, user-facing copy — never stack traces or ApiException(...) formatting.
String userFacingErrorMessage(
  Object error, {
  String fallback = ApiErrorCopy.genericFallback,
}) {
  if (error is ApiFailure) {
    return error.toUserMessage(fallback: fallback);
  }
  if (error is BackendNotConfiguredException) {
    return cloudBackendUnavailableMessage;
  }
  if (error is ApiException) {
    if (error.code == 'BACKEND_NOT_CONFIGURED') {
      return cloudBackendUnavailableMessage;
    }
    if (error is BillingUnavailableException) {
      return _messageForApiException(error);
    }
    if (_shouldUseApiExceptionMessage(error)) {
      return error.message.trim();
    }
    return _messageForApiException(error);
  }
  if (error is RecordingException) {
    final msg = error.message.trim();
    return msg.isNotEmpty ? msg : fallback;
  }
  if (error is CapturePipelineFailure) {
    final msg = error.message.trim();
    return msg.isNotEmpty ? msg : fallback;
  }
  if (error is BillingOperationException) {
    return _messageForBillingOperation(error, fallback);
  }
  if (error is PlatformException) {
    return _messageForPlatformException(error, fallback);
  }
  if (error is SocketException) {
    return _messageForSocketException(error);
  }
  if (error is TimeoutException) {
    return ApiErrorCopy.requestTimedOut;
  }
  if (error is String) {
    final msg = error.trim();
    return msg.isNotEmpty && !_looksLikeInternalErrorText(msg) ? msg : fallback;
  }

  return fallback;
}

/// Legacy alias — prefer [userFacingErrorMessage] in UI.
String formatApiErrorMessage(Object error) => userFacingErrorMessage(error);

String _messageForBillingOperation(
  BillingOperationException error,
  String fallback,
) {
  final cause = error.cause;
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

  switch (error.code) {
    case 'UNAVAILABLE':
    case 'billing_unavailable':
      return SubscriptionCopy.temporarilyUnavailable;
    default:
      return fallback;
  }
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

String _messageForSocketException(SocketException error) {
  if (!AppConfig.isBackendConfigured) {
    return cloudBackendUnavailableMessage;
  }
  if (AppConfig.looksLikeLocalhost) {
    return ApiErrorCopy.localDeviceConnectionHint;
  }
  return ApiErrorCopy.networkUnreachable;
}

bool _shouldUseApiExceptionMessage(ApiException error) {
  final msg = error.message.trim();
  if (msg.isEmpty || _looksLikeInternalErrorText(msg)) return false;
  if (error is AuthRequiredException ||
      error is NetworkOfflineException ||
      error is BillingUnavailableException ||
      error is NotImplementedNativeException) {
    return true;
  }
  final code = error.code?.toUpperCase() ?? '';
  if (code.contains('INTERNAL') || code.contains('UNKNOWN')) return false;
  final status = error.statusCode;
  if (status != null && status >= 500) return false;
  if (status == 401 || status == 413 || status == 422 || status == 429) {
    return true;
  }
  return msg.length >= 12 && msg.contains(' ');
}

bool _looksLikeInternalErrorText(String text) {
  final lower = text.toLowerCase();
  if (lower.startsWith('apiexception(')) return true;
  if (lower.contains('stacktrace')) return true;
  if (RegExp(r'\b\d{3}\b').hasMatch(text) && lower.contains('request failed')) {
    return true;
  }
  if (text == AppConfig.backendNotConfiguredMessage) return true;
  return false;
}

String _messageForApiException(ApiException error) {
  if (error is AuthRequiredException) {
    return ApiErrorCopy.signInRequired;
  }
  if (error is NetworkOfflineException) {
    return error.message;
  }
  if (error is BillingUnavailableException) {
    return SubscriptionCopy.temporarilyUnavailable;
  }
  if (error is NotImplementedNativeException) {
    return error.message;
  }
  switch (error.statusCode) {
    case 401:
      return ApiErrorCopy.signInRequired;
    case 413:
      return ApiErrorCopy.fileTooLarge;
    case 422:
      return ApiErrorCopy.noSpeechDetected;
    case 429:
      return error.message.isNotEmpty
          ? error.message
          : ApiErrorCopy.tooManyRequests;
    case 503:
      return error.message.isNotEmpty
          ? error.message
          : ApiErrorCopy.serviceUnavailable;
    default:
      return ApiErrorCopy.genericFallback;
  }
}
