import '../../api/api_client.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/network_cancel_token.dart';
import 'capture_api_client.dart';

class HttpCaptureApiClient implements CaptureApiClient {
  HttpCaptureApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    final responseResult = await _transport.post(
      '/api/capture/attest',
      body: {'deviceId': deviceId},
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(
            ApiFailureMapper.fromResponse(response),
          );
        }
        return _transport.decodeSuccess(response, (body) {
          if (body['via'] == 'session') {
            return AttestResult.session(
              userId: body['userId'] as String? ?? '',
            );
          }
          final token = body['token'] as String?;
          if (token == null || body['ok'] != true) {
            throw FormatException('Attest failed');
          }
          return AttestResult.capture(
            token: token,
            expiresInSeconds: (body['expiresInSeconds'] as num?)?.toInt() ?? 3600,
          );
        });
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
