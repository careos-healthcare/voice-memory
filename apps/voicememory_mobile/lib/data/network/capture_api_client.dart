import '../../api/api_client.dart' show AttestResult;
import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';

/// Capture attestation HTTP boundary.
abstract interface class CaptureApiClient {
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  });
}
