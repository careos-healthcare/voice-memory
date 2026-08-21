import 'package:archiveme_mobile/api/models/push_dto.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/push_api_client.dart';

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
      VoiceMemoryApiRoutes.pushRegister.path,
      body: {'deviceId': deviceId, 'platform': platform, 'fcmToken': fcmToken},
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: _transport.decodeEnvelopeOk,
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
      VoiceMemoryApiRoutes.internalSendTestPush.path,
      headers: headers,
      body: {'deviceId': deviceId, 'targetRoute': targetRoute},
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) => _transport.decodeEnvelope(
        response,
        parseData: SendTestPushResponseDto.fromJson,
        toDomain: (dto) => dto.toJson(),
      ),
      onFailure: ApiFailureResult.new,
    );
  }
}
