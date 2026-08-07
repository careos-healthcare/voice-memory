import '../../api/api_client.dart' show AttestResult, ApiClient;
import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/proof_admission/proof_admission_models.dart';

/// Capture HTTP boundary — attestation, analysis, and (future) transcribe.
abstract interface class CaptureApiClient {
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  });
}
