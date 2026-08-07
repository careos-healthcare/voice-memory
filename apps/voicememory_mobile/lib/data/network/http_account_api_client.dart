import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/network_cancel_token.dart';
import 'account_api_client.dart';

class HttpAccountApiClient implements AccountApiClient {
  HttpAccountApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<void>> deleteAccount({NetworkCancelToken? cancelToken}) async {
    final responseResult = await _transport.post(
      '/api/account/delete',
      body: {'confirm': true},
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.expectSuccess(response);
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
