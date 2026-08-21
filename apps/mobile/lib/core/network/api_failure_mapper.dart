import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/api/api_errors.dart';
import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/security/api_response_safety.dart';
import 'package:http/http.dart' as http;

/// Maps HTTP responses and transport errors to [ApiFailure].
abstract final class ApiFailureMapper {
  ApiFailureMapper._();

  static ApiFailure fromException(Object error) {
    if (error is ApiFailure) return error;
    if (error is BackendNotConfiguredException) {
      return const ApiFailureBackendNotConfigured();
    }
    if (error is AuthRequiredException) {
      return ApiFailureAuthRequired(error.message);
    }
    if (error is NetworkOfflineException) {
      return ApiFailureOffline(error.message);
    }
    if (error is RateLimitedException) {
      return ApiFailureRateLimited(
        message: error.message,
        serverCode: error.code,
      );
    }
    if (error is BillingUnavailableException) {
      return const ApiFailureBillingUnavailable();
    }
    if (error is ApiException) {
      return fromApiException(error);
    }
    if (error is SocketException) {
      return ApiFailureOffline(error.message);
    }
    if (error is TimeoutException) {
      return const ApiFailureOffline();
    }
    if (error is HttpException) {
      return ApiFailureOffline(error.message);
    }
    if (error is FormatException) {
      return ApiFailureInvalidResponse(message: error.message);
    }
    return ApiFailureUnknown(error);
  }

  static ApiFailure fromApiException(ApiException error) {
    if (error is AuthRequiredException) {
      return ApiFailureAuthRequired(error.message);
    }
    if (error is NetworkOfflineException) {
      return ApiFailureOffline(error.message);
    }
    if (error is BillingUnavailableException) {
      return const ApiFailureBillingUnavailable();
    }
    if (error is BackendNotConfiguredException) {
      return const ApiFailureBackendNotConfigured();
    }
    if (error is RateLimitedException) {
      return ApiFailureRateLimited(
        message: error.message,
        serverCode: error.code,
      );
    }
    final status = error.statusCode;
    if (status != null) {
      return ApiFailureServer(
        message: error.message,
        statusCode: status,
        serverCode: error.code,
      );
    }
    return ApiFailureInvalidResponse(
      message: error.message,
      serverCode: error.code,
    );
  }

  static ApiFailure fromResponse(http.Response response) {
    if (ApiResponseSafety.responseLooksLikeHtml(response)) {
      return ApiFailureInvalidResponse(
        message: ApiResponseSafety.htmlResponseMessage,
        responseCode: response.statusCode,
        serverCode: 'HTML_RESPONSE',
      );
    }

    var message = 'Request failed (${response.statusCode})';
    String? code;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = ApiResponseSafety.parseApiErrorFields(body);
      message = parsed.message ?? message;
      code = parsed.code;
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }

    switch (response.statusCode) {
      case 401:
        return ApiFailureAuthRequired(message);
      case 413:
        return ApiFailureServer(
          message: message,
          statusCode: 413,
          serverCode: code ?? 'PAYLOAD_TOO_LARGE',
        );
      case 422:
        return ApiFailureServer(
          message: message,
          statusCode: 422,
          serverCode: code ?? 'NO_SPEECH',
        );
      case 429:
        return ApiFailureRateLimited(message: message, serverCode: code);
      case 503:
        if (code == 'BILLING_DISABLED') {
          return const ApiFailureBillingUnavailable();
        }
        return ApiFailureServer(
          message: message,
          statusCode: 503,
          serverCode: code,
        );
      default:
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiFailureInvalidResponse(
            message: message,
            responseCode: response.statusCode,
            serverCode: code,
          );
        }
        return ApiFailureServer(
          message: message,
          statusCode: response.statusCode,
          serverCode: code,
        );
    }
  }
}