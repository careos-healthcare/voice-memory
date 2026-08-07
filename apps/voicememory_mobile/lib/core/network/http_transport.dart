import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../security/api_response_safety.dart';
import 'api_failure.dart';
import 'api_failure_mapper.dart';
import 'api_result.dart';
import 'network_cancel_token.dart';
import 'session_cookie_source.dart';

/// Low-level JSON HTTP transport — normalizes connectivity and response failures.
class HttpTransport {
  HttpTransport({
    http.Client? client,
    String? baseUrl,
    SessionCookieSource? sessionCookies,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _sessionCookies = sessionCookies;

  final http.Client _client;
  final String _baseUrl;
  final SessionCookieSource? _sessionCookies;
  final Duration timeout;

  /// Shared client for legacy [ApiClient] multipart routes during migration.
  http.Client get client => _client;

  static const jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<ApiResult<http.Response>> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    NetworkCancelToken? cancelToken,
  }) {
    return _execute(
      () {
        final uri = _requireUri(path, queryParameters: queryParameters);
        return _client.get(uri, headers: _mergeHeaders(headers));
      },
      cancelToken: cancelToken,
    );
  }

  Future<ApiResult<http.Response>> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    NetworkCancelToken? cancelToken,
  }) {
    return _execute(
      () {
        final uri = _requireUri(path);
        final encodedBody = switch (body) {
          null => null,
          String value => value,
          _ => jsonEncode(body),
        };
        return _client.post(
          uri,
          headers: _mergeHeaders(headers),
          body: encodedBody,
        );
      },
      cancelToken: cancelToken,
    );
  }

  Future<ApiResult<http.Response>> delete(
    String path, {
    Map<String, String>? headers,
    Object? body,
    NetworkCancelToken? cancelToken,
  }) {
    return _execute(
      () {
        final uri = _requireUri(path);
        final encodedBody = switch (body) {
          null => null,
          String value => value,
          _ => jsonEncode(body),
        };
        return _client.delete(
          uri,
          headers: _mergeHeaders(headers),
          body: encodedBody,
        );
      },
      cancelToken: cancelToken,
    );
  }

  ApiResult<T> decodeSuccess<T>(
    http.Response response,
    T Function(Map<String, dynamic> json) parse,
  ) {
    if (!_isSuccessStatus(response.statusCode)) {
      return ApiFailureResult(ApiFailureMapper.fromResponse(response));
    }
    try {
      final json = ApiResponseSafety.decodeJsonObject(response);
      return ApiSuccess(parse(json));
    } on FormatException catch (error) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
  }

  ApiResult<void> expectSuccess(http.Response response) {
    if (!_isSuccessStatus(response.statusCode)) {
      return ApiFailureResult(ApiFailureMapper.fromResponse(response));
    }
    try {
      ApiResponseSafety.ensureJsonResponse(response);
      return const ApiSuccess(null);
    } on FormatException catch (error) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
  }

  void dispose() => _client.close();

  Map<String, String> _mergeHeaders(Map<String, String>? headers) => {
    ...jsonHeaders,
    ...?_sessionCookies?.headerEntries(),
    ...?headers,
  };

  Uri? tryUri(String path, {Map<String, String>? queryParameters}) {
    if (!AppConfig.isBackendConfigured || _baseUrl.isEmpty) {
      debugPrint('HttpTransport: backend not configured — skipping $path');
      return null;
    }
    if (!ApiResponseSafety.isBaseUrlAllowed(_baseUrl)) {
      debugPrint(
        'HttpTransport: rejected API base URL for this build — skipping $path',
      );
      return null;
    }
    final uri = Uri.parse('$_baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(queryParameters: queryParameters);
  }

  Uri _requireUri(String path, {Map<String, String>? queryParameters}) {
    final uri = tryUri(path, queryParameters: queryParameters);
    if (uri == null) {
      throw const ApiFailureBackendNotConfigured();
    }
    return uri;
  }

  Future<ApiResult<http.Response>> _execute(
    Future<http.Response> Function() request, {
    NetworkCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      return const ApiFailureResult(ApiFailureCancelled());
    }
    try {
      final response = await request().timeout(timeout);
      if (cancelToken?.isCancelled ?? false) {
        return const ApiFailureResult(ApiFailureCancelled());
      }
      return ApiSuccess(response);
    } on ApiFailure catch (failure) {
      return ApiFailureResult(failure);
    } on TimeoutException {
      return const ApiFailureResult(ApiFailureOffline());
    } on Object catch (error) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
  }

  bool _isSuccessStatus(int statusCode) =>
      statusCode >= 200 && statusCode < 300;
}

/// Extracts `vm_session` from a Set-Cookie header on auth responses.
String? extractSessionCookie(http.Response response) {
  const sessionCookieName = ApiClientSessionCookie.sessionCookieName;
  final raw = response.headers['set-cookie'];
  if (raw == null) return null;
  for (final part in raw.split(',')) {
    final trimmed = part.trim();
    if (trimmed.startsWith('$sessionCookieName=')) {
      final semi = trimmed.indexOf(';');
      return semi > 0 ? trimmed.substring(0, semi) : trimmed;
    }
  }
  return null;
}

/// Shared auth cookie constant — keeps [HttpTransport] decoupled from [ApiClient].
abstract final class ApiClientSessionCookie {
  ApiClientSessionCookie._();

  static const sessionCookieName = 'vm_session';
}
