import 'dart:async';
import 'dart:io';

import '../audio/recording_service.dart';
import '../config/app_config.dart';
import '../billing/subscription_copy.dart';
import '../services/capture_pipeline_service.dart';
import 'api_exceptions.dart';

/// Shown when cloud/API features need a configured backend URL.
const String cloudBackendUnavailableMessage =
    'Cloud features are unavailable because a backend connection has not been configured.';

/// Maps errors to calm, user-facing copy — never stack traces or ApiException(...) formatting.
String userFacingErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is BackendNotConfiguredException) {
    return cloudBackendUnavailableMessage;
  }
  if (error is ApiException) {
    if (error.code == 'BACKEND_NOT_CONFIGURED') {
      return cloudBackendUnavailableMessage;
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
  if (error is SocketException) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  if (error is TimeoutException) {
    return 'The request timed out. Please try again.';
  }
  if (error is StateError) {
    final msg = error.message.toLowerCase();
    if (msg.contains('revenuecat') || msg.contains('not configured')) {
      return SubscriptionCopy.temporarilyUnavailable;
    }
    return fallback;
  }
  if (error is String) {
    final msg = error.trim();
    return msg.isNotEmpty && !_looksLikeInternalErrorText(msg) ? msg : fallback;
  }

  final text = error.toString().trim();
  if (text.isEmpty || _looksLikeInternalErrorText(text)) {
    return fallback;
  }
  if (text.contains('Connection refused') || text.contains('connection refused')) {
    return _connectionRefusedMessage();
  }
  return fallback;
}

/// Legacy alias — prefer [userFacingErrorMessage] in UI.
String formatApiErrorMessage(Object error) => userFacingErrorMessage(error);

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
    return 'Sign in to continue.';
  }
  if (error is NetworkOfflineException) {
    return error.message;
  }
  if (error is BillingUnavailableException) {
    return error.message;
  }
  if (error is NotImplementedNativeException) {
    return error.message;
  }
  switch (error.statusCode) {
    case 401:
      return 'Sign in to continue.';
    case 413:
      return 'This file is too large. Try a shorter recording.';
    case 422:
      return 'No speech detected. Try speaking a little longer.';
    case 429:
      return error.message.isNotEmpty
          ? error.message
          : 'Too many requests. Please wait a moment.';
    case 503:
      return error.message.isNotEmpty
          ? error.message
          : 'Service is temporarily unavailable.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

String _connectionRefusedMessage() {
  if (!AppConfig.isBackendConfigured) {
    return cloudBackendUnavailableMessage;
  }
  if (AppConfig.looksLikeLocalhost) {
    return 'Could not reach the server. On a physical device, set '
        '--dart-define=${AppConfig.apiBaseUrlDefineKey}=http://YOUR_LAN_IP:3000';
  }
  return 'Could not reach the server. Check your connection and try again.';
}
