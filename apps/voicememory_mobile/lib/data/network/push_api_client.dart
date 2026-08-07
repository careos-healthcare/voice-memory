import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';

abstract interface class PushApiClient {
  Future<ApiResult<void>> registerPushDevice({
    required String deviceId,
    required String platform,
    required String fcmToken,
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<Map<String, dynamic>>> sendInternalTestPush({
    required String deviceId,
    required String targetRoute,
    String? debugToken,
    NetworkCancelToken? cancelToken,
  });
}
