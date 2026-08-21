import 'package:archiveme_mobile/config/backend_url_resolver.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/security/api_response_safety.dart';

/// Resolved API base URL plus helpers for building request URIs.
///
/// Inject via [voiceMemoryApiConfigProvider] after [AppConfig.initApiResolution]
/// so network code never reads unresolved globals at runtime.
class VoiceMemoryApiConfig {
  VoiceMemoryApiConfig({required String baseUrl})
    : baseUrl = BackendUrlResolver.normalizeApiBaseUrl(baseUrl);

  final String baseUrl;

  bool get isConfigured =>
      baseUrl.isNotEmpty && ApiResponseSafety.isBaseUrlAllowed(baseUrl);

  Uri resolve(
    VoiceMemoryApiEndpoint endpoint, {
    Map<String, String>? queryParameters,
  }) => resolvePath(endpoint.path, queryParameters: queryParameters);

  Uri resolvePath(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  /// WebSocket upgrade URL for live audio (maps to `/api/live-audio/ws`).
  Uri liveAudioWebSocketUri({Map<String, String>? queryParameters}) =>
      resolve(VoiceMemoryApiRoutes.liveAudioWebSocket, queryParameters: queryParameters);
}