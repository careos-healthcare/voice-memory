import '../../api/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/proof_admission/proof_admission_models.dart';
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

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      return const ApiFailureResult(ApiFailureCancelled());
    }
    try {
      return ApiSuccess(
        await _api.postAnalyzeRaw(
          transcript: transcript,
          captureToken: captureToken,
          priorEvidence: priorEvidence,
          idempotencyKey: idempotencyKey,
        ),
      );
    } on Object catch (error) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
  }
}
