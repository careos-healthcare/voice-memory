import 'package:archiveme_mobile/core/network/http_transport.dart'
    show ApiClientSessionCookie;
import 'package:dio/dio.dart';

/// Captures the latest `Set-Cookie` header from Dio responses (auth verify).
class SessionCookieCapture {
  String? lastSetCookie;

  void clear() => lastSetCookie = null;
}

class SessionCookieCaptureInterceptor extends Interceptor {
  SessionCookieCaptureInterceptor(this._capture);

  final SessionCookieCapture _capture;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final cookie = extractSessionCookieFromHeaders(response.headers);
    if (cookie != null && cookie.isNotEmpty) {
      _capture.lastSetCookie = cookie;
    }
    handler.next(response);
  }
}

String? extractSessionCookieFromHeaders(Headers headers) {
  const sessionCookieName = ApiClientSessionCookie.sessionCookieName;
  final values = headers.map['set-cookie'];
  if (values == null || values.isEmpty) {
    return null;
  }
  for (final raw in values) {
    for (final part in raw.split(',')) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$sessionCookieName=')) {
        final semi = trimmed.indexOf(';');
        return semi > 0 ? trimmed.substring(0, semi) : trimmed;
      }
    }
  }
  return null;
}
