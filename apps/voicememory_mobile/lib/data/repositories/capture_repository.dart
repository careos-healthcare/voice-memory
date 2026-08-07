import '../../api/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../network/capture_api_client.dart';

/// Capture attestation with typed [ApiResult] boundaries.
class CaptureRepository {
  CaptureRepository({
    required CaptureApiClient api,
    required NetworkRequestScope requestScope,
  }) : _api = api,
       _requestScope = requestScope;

  final CaptureApiClient _api;
  final NetworkRequestScope _requestScope;

  Future<ApiResult<AttestResult>> postCaptureAttest(String deviceId) async {
    final token = _requestScope.register();
    try {
      return await _api.postCaptureAttest(deviceId, cancelToken: token);
    } finally {
      _requestScope.release(token);
    }
  }
}
