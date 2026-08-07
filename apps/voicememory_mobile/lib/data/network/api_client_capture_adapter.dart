import '../../api/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import 'capture_api_client.dart';

/// Adapts legacy [ApiClient] capture methods for tests and transitional call sites.
class ApiClientCaptureAdapter implements CaptureApiClient {
  const ApiClientCaptureAdapter(this._api);

  final ApiClient _api;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      return const ApiFailureResult(ApiFailureCancelled());
    }
    try {
      return ApiSuccess(await _api.postCaptureAttest(deviceId));
    } on Object catch (error) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
  }
}
