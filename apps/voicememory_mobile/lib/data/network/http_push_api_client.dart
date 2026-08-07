import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/network_cancel_token.dart';
import 'push_api_client.dart';

class HttpPushApiClient implements PushApiClient {
  HttpPushApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<void>> registerPushDevice({
    required String deviceId,
    required String platform,
    required String fcmToken,
    NetworkCancelToken? cancelToken,
  }) async {
    final responseResult = await _transport.post(
      '/api/push/register',
      body: {
        'deviceId': deviceId,
        'platform': platform,
        'fcmToken': fcmToken,
      },
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) => _transport.expectSuccess(response),
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> sendInternalTestPush({
    required String deviceId,
    required String targetRoute,
    String? debugToken,
    NetworkCancelToken? cancelToken,
  }) async {
    final headers = <String, String>{};
    if (debugToken != null && debugToken.isNotEmpty) {
      headers['x-vm-debug-token'] = debugToken;
    }
    final responseResult = await _transport.post(
      '/api/internal/send-test-push',
      headers: headers,
      body: {'deviceId': deviceId, 'targetRoute': targetRoute},
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) => _transport.decodeSuccess(response, (json) => json),
      onFailure: ApiFailureResult.new,
    );
  }
}
