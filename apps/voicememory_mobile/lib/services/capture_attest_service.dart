import '../core/network/api_failure.dart';
import '../data/network/api_client_capture_adapter.dart';
import '../data/repositories/capture_repository.dart';
import '../storage/capture_token_cache.dart';
import '../storage/device_id.dart';
import '../api/api_client.dart';
import '../core/network/network_cancel_token.dart';

class CaptureAttestService {
  CaptureAttestService({
    CaptureRepository? captureRepository,
    ApiClient? api,
    required DeviceIdStore deviceIds,
    required CaptureTokenCache tokenCache,
    NetworkRequestScope? requestScope,
  }) : assert(
         captureRepository != null || api != null,
         'Provide captureRepository or legacy api',
       ),
       _captureRepository =
           captureRepository ??
           CaptureRepository(
             api: ApiClientCaptureAdapter(api!),
             requestScope: requestScope ?? NetworkRequestScope(),
           ),
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
