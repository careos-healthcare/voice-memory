import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/storage/capture_token_cache.dart';
import 'package:archiveme_mobile/storage/device_id.dart';

class CaptureAttestService {
  CaptureAttestService({
    required this._captureRepository,
    required this._deviceIds,
    required this._tokenCache,
  });

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