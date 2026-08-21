import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/account_api_client.dart';

class HttpAccountApiClient implements AccountApiClient {
  HttpAccountApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<void>> deleteAccount({
    NetworkCancelToken? cancelToken,
  }) async {
    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.accountDelete.path,
      body: {'confirm': true},
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeEnvelopeOk(response);
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
