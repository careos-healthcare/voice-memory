import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Guards against HTML misconfiguration responses and unsafe JSON decoding.
abstract class ApiResponseSafety {
  ApiResponseSafety._();

  static const String htmlResponseMessage =
      'API base URL returned HTML, expected JSON';

  static bool responseLooksLikeHtml(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('text/html')) return true;
    final trimmed = response.body.trimLeft();
    if (trimmed.startsWith('<!DOCTYPE') ||
        trimmed.startsWith('<!doctype') ||
        trimmed.startsWith('<html') ||
        trimmed.startsWith('<HTML')) {
      return true;
    }
    return false;
  }

  /// Throws [FormatException] when the host returned HTML (wrong API base URL).
  static void ensureJsonResponse(http.Response response) {
    if (responseLooksLikeHtml(response)) {
      debugPrint(
        'ApiClient: $htmlResponseMessage (status=${response.statusCode})',
      );
      throw FormatException(htmlResponseMessage);
    }
  }

  static Map<String, dynamic> decodeJsonObject(http.Response response) {
    ensureJsonResponse(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Expected JSON object from API');
    }
    return decoded;
  }

  /// Rejects non-HTTPS / localhost URLs in release builds unless debug tools.
  static bool isBaseUrlAllowed(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;

    if (AppConfig.isReleaseBuild && !AppConfig.isDebugBuild) {
      if (uri.scheme != 'https') return false;
      if (_isLocalhostHost(uri.host)) return false;
    }
    return true;
  }

  static bool _isLocalhostHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'localhost' ||
        lower == '127.0.0.1' ||
        lower == '10.0.2.2' ||
        lower.endsWith('.local');
  }
}
