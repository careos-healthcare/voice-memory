import 'package:archiveme_mobile/api/api_error_copy.dart';
import 'package:archiveme_mobile/api/api_errors.dart';
import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/billing/subscription_copy.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';

/// Shown when cloud/API features need a configured backend URL.
const String cloudBackendUnavailableMessage =
    BackendNotConfiguredException.userMessage;

String userMessageForApiFailure(
  ApiFailure failure, {
  String fallback = ApiErrorCopy.genericFallback,
}) {
  return switch (failure) {
    ApiFailureOffline(:final detail) => _nullableMessageOrFallback(
        detail,
        ApiErrorCopy.networkUnreachable,
      ),
    ApiFailureBackendNotConfigured() => cloudBackendUnavailableMessage,
    ApiFailureAuthRequired(:final detail) => _nullableMessageOrFallback(
        detail,
        ApiErrorCopy.signInRequired,
      ),
    ApiFailureRateLimited(:final message) => _messageOrFallback(
        message,
        ApiErrorCopy.tooManyRequests,
      ),
    ApiFailureBillingUnavailable() => SubscriptionCopy.temporarilyUnavailable,
    ApiFailureInvalidResponse(
      :final message,
      :final responseCode,
      :final serverCode,
    ) =>
      userMessageForGenericApiException(
        message: message,
        statusCode: responseCode,
        code: serverCode,
        fallback: fallback,
      ),
    ApiFailureServer(
      :final message,
      :final statusCode,
      :final serverCode,
    ) =>
      userMessageForGenericApiException(
        message: message,
        statusCode: statusCode,
        code: serverCode,
        fallback: fallback,
      ),
    ApiFailureUnknown() => fallback,
    ApiFailureCancelled() => fallback,
  };
}

String userMessageForApiException(
  ApiException error, {
  String fallback = ApiErrorCopy.genericFallback,
}) {
  return switch (error) {
    BackendNotConfiguredException() => cloudBackendUnavailableMessage,
    AuthRequiredException(:final message) => _messageOrFallback(
        message,
        ApiErrorCopy.signInRequired,
      ),
    NetworkOfflineException(:final message) => _messageOrFallback(
        message,
        ApiErrorCopy.networkUnreachable,
      ),
    BillingUnavailableException() => SubscriptionCopy.temporarilyUnavailable,
    NotImplementedNativeException(:final message) => _messageOrFallback(
        message,
        fallback,
      ),
    RateLimitedException(:final message) => _messageOrFallback(
        message,
        ApiErrorCopy.tooManyRequests,
      ),
    ApiException(:final message, :final statusCode, :final code) =>
      userMessageForGenericApiException(
        message: message,
        statusCode: statusCode,
        code: code,
        fallback: fallback,
      ),
  };
}

String userMessageForGenericApiException({
  required String message,
  required String fallback,
  int? statusCode,
  String? code,
}) {
  final normalizedCode = code?.trim().toUpperCase();
  if (normalizedCode != null && normalizedCode.isNotEmpty) {
    switch (normalizedCode) {
      case 'BACKEND_NOT_CONFIGURED':
        return cloudBackendUnavailableMessage;
      case 'BILLING_DISABLED':
        return SubscriptionCopy.temporarilyUnavailable;
      case 'OFFLINE':
        return _messageOrFallback(message, ApiErrorCopy.networkUnreachable);
      case 'AUTH_REQUIRED':
      case 'AUTH':
        return _messageOrFallback(message, ApiErrorCopy.signInRequired);
      case 'RATE_LIMIT':
      case 'TOO_MANY_REQUESTS':
        return _messageOrFallback(message, ApiErrorCopy.tooManyRequests);
      case 'PAYLOAD_TOO_LARGE':
      case 'TRANSCRIPT_TOO_LONG':
        return ApiErrorCopy.fileTooLarge;
      case 'NO_SPEECH':
      case 'TRANSCRIPT_REQUIRED':
        return _messageOrFallback(message, ApiErrorCopy.noSpeechDetected);
      case 'GEMINI_NOT_CONFIGURED':
      case 'OPENAI_NOT_CONFIGURED':
        return ApiErrorCopy.serviceUnavailable;
      case 'INTERNAL':
      case 'UNKNOWN':
      case 'HTML_RESPONSE':
      case 'CANCELLED':
        return fallback;
      case 'INVALID_BODY':
      case 'INVALID_REQUEST':
      case 'INVALID_ID':
      case 'INVALID_TOKEN':
      case 'INVALID_CONSENT_STATUS':
      case 'INVALID_PARTIES':
      case 'INVALID_DEVICE':
      case 'INVALID_CAREGIVER_ID':
      case 'INVALID_COACH_ID':
      case 'INVALID_AFFIRMATION':
      case 'INVALID_PERMISSIONS':
      case 'INVALID_INSIGHT_RESPONSE':
      case 'CONFIRM_REQUIRED':
      case 'FORBIDDEN':
      case 'NOT_FOUND':
      case 'INSUFFICIENT_EVIDENCE':
        return _messageOrFallback(message, fallback);
      default:
        break;
    }
  }

  final status = statusCode;
  if (status != null) {
    switch (status) {
      case 400:
      case 403:
      case 404:
        return _messageOrFallback(message, fallback);
      case 401:
        return _messageOrFallback(message, ApiErrorCopy.signInRequired);
      case 413:
        return ApiErrorCopy.fileTooLarge;
      case 422:
        return _messageOrFallback(message, ApiErrorCopy.noSpeechDetected);
      case 429:
        return _messageOrFallback(message, ApiErrorCopy.tooManyRequests);
      case 503:
        return _messageOrFallback(message, ApiErrorCopy.serviceUnavailable);
      default:
        if (status >= 500) {
          return fallback;
        }
        if (status >= 400) {
          return _messageOrFallback(message, fallback);
        }
        return _messageOrFallback(message, fallback);
    }
  }

  return fallback;
}

String _messageOrFallback(String message, String fallback) {
  final trimmed = message.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _nullableMessageOrFallback(String? message, String fallback) {
  if (message == null) {
    return fallback;
  }
  return _messageOrFallback(message, fallback);
}
