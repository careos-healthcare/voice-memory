import '../core/network/api_failure.dart';
import '../data/repositories/capture_repository.dart';
import '../storage/capture_token_cache.dart';
import '../storage/device_id.dart';

class CaptureAttestService {
  CaptureAttestService({
    required CaptureRepository captureRepository,
    required DeviceIdStore deviceIds,
    required CaptureTokenCache tokenCache,
  }) : _captureRepository = captureRepository,
       _deviceIds = deviceIds,
       _tokenCache = tokenCache;

  final CaptureRepository _captureRepository;
  final DeviceIdStore _deviceIds;
  final CaptureTokenCache _tokenCache;

  /// Returns capture token for OpenAI routes. Re-attests when missing/expired.
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _tokenCache.hasValidToken) {
      return _tokenCache.token!;
    }
    _tokenCache.clear();

    final deviceId = await _deviceIds.getOrCreate();
    final result = await _captureRepository.postCaptureAttest(deviceId);
    return result.when(
      success: (attest) {
        if (attest.isSession) {
          throw StateError(
            'Server returned session attest but Flutter has no cookie session yet.',
          );
        }
        final token = attest.token!;
        _tokenCache.setToken(
          token,
          expiresInSeconds: attest.expiresInSeconds ?? 3600,
        );
        return token;
      },
      onFailure: (failure) => throw failure.toApiException(),
    );
  }

  void clearToken() => _tokenCache.clear();
}
