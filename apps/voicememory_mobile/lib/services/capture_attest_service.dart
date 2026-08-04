import '../api/api_client.dart';
import '../storage/capture_token_cache.dart';
import '../storage/device_id.dart';

class CaptureAttestService {
  CaptureAttestService({
    @Deprecated('Pass authApi and voiceApi instead.')
    VoiceCaptureApiClient? api,
    AuthApiClient? authApi,
    VoiceCaptureApiClient? voiceApi,
    required this._deviceIds,
    required this._tokenCache,
  }) : assert(authApi != null || api != null),
       assert(voiceApi != null || api != null),
       _authApi = authApi ?? AuthApiClient(api!.transport),
       _voiceApi = voiceApi ?? api!;

  final AuthApiClient _authApi;
  final VoiceCaptureApiClient _voiceApi;
  final DeviceIdStore _deviceIds;
  final CaptureTokenCache _tokenCache;

  /// Returns capture token for OpenAI routes. Re-attests when missing/expired.
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _tokenCache.hasValidToken) {
      return _tokenCache.token!;
    }
    _tokenCache.clear();

    final session = await _authApi.getSession();
    if (session != null) {
      // Signed-in users use session cookies — native has no cookie jar yet.
      // Fall through to device attest for MVP.
    }

    final deviceId = await _deviceIds.getOrCreate();
    final result = await _voiceApi.postCaptureAttest(deviceId);
    if (result.isSession) {
      throw StateError(
        'Server returned session attest but Flutter has no cookie session yet.',
      );
    }
    final token = result.token!;
    _tokenCache.setToken(
      token,
      expiresInSeconds: result.expiresInSeconds ?? 3600,
    );
    return token;
  }

  void clearToken() => _tokenCache.clear();
}
