import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../security/api_response_safety.dart';
import 'api_errors.dart';
import 'api_exceptions.dart';

final class ApiRequestContext {
  const ApiRequestContext({
    required this.method,
    required this.uri,
    this.acceptedStatusCodes = const <int>{},
  });

  final String method;
  final Uri uri;
  final Set<int> acceptedStatusCodes;

  bool accepts(int statusCode) =>
      (statusCode >= 200 && statusCode < 300) ||
      acceptedStatusCodes.contains(statusCode);
}

abstract interface class ApiResponseInterceptor {
  FutureOr<http.Response> intercept(
    ApiRequestContext request,
    http.Response response,
  );
}

/// Converts every unexpected HTTP response into the app's domain error model.
///
/// This interceptor is always the final stage in [ApiTransport], so custom
/// interceptors can observe or normalize responses without allowing an
/// unhandled non-2xx response to leak into a domain-specific API client.
final class ApiErrorMappingInterceptor implements ApiResponseInterceptor {
  const ApiErrorMappingInterceptor();

  @override
  http.Response intercept(ApiRequestContext request, http.Response response) {
    if (request.accepts(response.statusCode)) return response;
    throw ApiErrorMapper.fromResponse(response);
  }
}

/// Shared HTTP transport and mutable session state for domain API clients.
///
/// One instance should be shared by all four clients so authentication cookie
/// changes are immediately visible to capture, journal sync, and billing.
final class ApiTransport {
  ApiTransport({
    http.Client? httpClient,
    String? baseUrl,
    this.sessionCookie,
    Iterable<ApiResponseInterceptor> responseInterceptors = const [],
  }) : httpClient = httpClient ?? http.Client(),
       _responseInterceptors = List<ApiResponseInterceptor>.unmodifiable([
         ...responseInterceptors,
         const ApiErrorMappingInterceptor(),
       ]),
       baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  static const captureTokenHeader = 'x-vm-capture-token';
  static const sessionCookieName = 'vm_session';
  static const idempotencyHeader = 'x-vm-idempotency-key';

  final http.Client httpClient;
  final String baseUrl;
  final List<ApiResponseInterceptor> _responseInterceptors;
  String? sessionCookie;

  void setSessionCookie(String? cookie) => sessionCookie = cookie;

  Map<String, String> get jsonHeaders => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (sessionCookie != null && sessionCookie!.isNotEmpty)
      'Cookie': sessionCookie!,
  };

  Map<String, String> headersWithIdempotency({
    required Map<String, String> base,
    String? idempotencyKey,
  }) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) return base;
    return {...base, idempotencyHeader: idempotencyKey};
  }

  Uri? tryUri(String path) {
    if (!AppConfig.isBackendConfigured || baseUrl.isEmpty) {
      debugPrint('ApiTransport: backend not configured — skipping $path');
      return null;
    }
    if (!ApiResponseSafety.isBaseUrlAllowed(baseUrl)) {
      debugPrint(
        'ApiTransport: rejected API base URL for this build — skipping $path',
      );
      return null;
    }
    return Uri.parse('$baseUrl$path');
  }

  Uri uri(String path) {
    final resolved = tryUri(path);
    if (resolved == null) throw BackendNotConfiguredException();
    return resolved;
  }

  Map<String, dynamic> decodeJson(http.Response response) {
    try {
      return ApiResponseSafety.decodeJsonObject(response);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        InvalidApiResponseException(error.message, cause: error),
        stackTrace,
      );
    }
  }

  String? extractSessionCookie(http.Response response) {
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

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Set<int> acceptedStatusCodes = const <int>{},
  }) {
    final target = uri(path);
    return _send(
      ApiRequestContext(
        method: 'GET',
        uri: target,
        acceptedStatusCodes: acceptedStatusCodes,
      ),
      () => httpClient.get(target, headers: headers ?? jsonHeaders),
    );
  }

  Future<http.Response> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Set<int> acceptedStatusCodes = const <int>{},
  }) {
    final target = uri(path);
    return _send(
      ApiRequestContext(
        method: 'POST',
        uri: target,
        acceptedStatusCodes: acceptedStatusCodes,
      ),
      () => httpClient.post(
        target,
        headers: headers ?? jsonHeaders,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Set<int> acceptedStatusCodes = const <int>{},
  }) {
    final target = uri(path);
    return _send(
      ApiRequestContext(
        method: 'DELETE',
        uri: target,
        acceptedStatusCodes: acceptedStatusCodes,
      ),
      () => httpClient.delete(target, headers: headers ?? jsonHeaders),
    );
  }

  Future<http.Response> send(
    http.BaseRequest request, {
    Set<int> acceptedStatusCodes = const <int>{},
  }) => _send(
    ApiRequestContext(
      method: request.method,
      uri: request.url,
      acceptedStatusCodes: acceptedStatusCodes,
    ),
    () async => http.Response.fromStream(await httpClient.send(request)),
  );

  Future<http.Response> _send(
    ApiRequestContext request,
    Future<http.Response> Function() operation,
  ) async {
    var response = await _mapTransportErrors(operation);
    for (final interceptor in _responseInterceptors) {
      response = await interceptor.intercept(request, response);
    }
    return response;
  }

  Future<T> _mapTransportErrors<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on TimeoutException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        RequestTimeoutException(cause: error),
        stackTrace,
      );
    } on SocketException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ConnectivityException(cause: error),
        stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ConnectivityException(cause: error),
        stackTrace,
      );
    }
  }

  void dispose() => httpClient.close();
}
