import 'package:archiveme_mobile/core/network/session_cookie_source.dart';
import 'package:archiveme_mobile/api/dio/session_cookie_capture.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/security/api_response_safety.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Builds a configured [Dio] for Voice Memory Retrofit clients.
///
/// Base URL comes from [voiceMemoryApiBaseUrlProvider] — never hardcoded here.
Dio createVoiceMemoryDio({
  required String baseUrl,
  required SessionCookieSource sessionCookies,
  SessionCookieCapture? sessionCookieCapture,
  Duration connectTimeout = const Duration(seconds: 30),
  Duration receiveTimeout = const Duration(seconds: 30),
}) {
  final normalized = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  final dio = Dio(
    BaseOptions(
      baseUrl: normalized,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (status) => status != null && status >= 100 && status < 600,
    ),
  );

  dio.interceptors.add(_SessionCookieInterceptor(sessionCookies));
  if (sessionCookieCapture != null) {
    dio.interceptors.add(
      SessionCookieCaptureInterceptor(sessionCookieCapture),
    );
  }
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: false));
  }

  return dio;
}

/// Returns null when the backend URL is not configured for this build.
Dio? tryCreateVoiceMemoryDio({
  required String baseUrl,
  required SessionCookieSource sessionCookies,
  SessionCookieCapture? sessionCookieCapture,
}) {
  if (baseUrl.isEmpty || !ApiResponseSafety.isBaseUrlAllowed(baseUrl)) {
    AppLogger.debug('VoiceMemoryDio: backend not configured — skipping client');
    return null;
  }
  return createVoiceMemoryDio(
    baseUrl: baseUrl,
    sessionCookies: sessionCookies,
    sessionCookieCapture: sessionCookieCapture,
  );
}

final class _SessionCookieInterceptor extends Interceptor {
  _SessionCookieInterceptor(this._sessionCookies);

  final SessionCookieSource _sessionCookies;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.addAll(_sessionCookies.headerEntries());
    handler.next(options);
  }
}