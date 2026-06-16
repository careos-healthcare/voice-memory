import '../api/api_client.dart';
import '../storage/capture_token_cache.dart';
import '../storage/device_id.dart';

class CaptureAttestService {
  CaptureAttestService({
    required ApiClient api,
    required DeviceIdStore deviceIds,
    required CaptureTokenCache tokenCache,
  }) : _api = api,
       _deviceIds = deviceIds,
       _tokenCache = tokenCache;

  final ApiClient _api;
  final DeviceIdStore _deviceIds;
  final CaptureTokenCache _tokenCache;

  /// Returns capture token for OpenAI routes. Re-attests when missing/expired.
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _tokenCache.hasValidToken) {
      return _tokenCache.token!;
    }
    _tokenCache.clear();

    final session = await _api.getSession();
    if (session != null) {
      // Signed-in users use session cookies — native has no cookie jar yet.
      // Fall through to device attest for MVP.
    }

    final deviceId = await _deviceIds.getOrCreate();
    final result = await _api.postCaptureAttest(deviceId);
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
