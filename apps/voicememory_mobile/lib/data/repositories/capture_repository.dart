import '../../api/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/proof_admission/proof_admission_models.dart';
import '../network/capture_api_client.dart';

/// Capture pipeline HTTP with typed [ApiResult] boundaries and cancellation.
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

  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
  }) async {
    final token = _requestScope.register();
    try {
      return await _api.postAnalyzeRaw(
        transcript: transcript,
        captureToken: captureToken,
        priorEvidence: priorEvidence,
        idempotencyKey: idempotencyKey,
        cancelToken: token,
      );
    } finally {
      _requestScope.release(token);
    }
  }
}
