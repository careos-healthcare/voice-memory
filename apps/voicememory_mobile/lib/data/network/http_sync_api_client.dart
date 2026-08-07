import 'package:http/http.dart' as http;

import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import 'sync_api_client.dart';

class HttpSyncApiClient implements SyncApiClient {
  HttpSyncApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() async {
    final responseResult = await _transport.get('/api/sync/manifest');
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    final responseResult = await _transport.get('/api/sync/pull');
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncChanges({
    required int since,
  }) async {
    final responseResult = await _transport.get(
      '/api/sync/changes',
      queryParameters: {'since': '$since'},
    );
    return _decodeObject(responseResult);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    final responseResult = await _transport.post('/api/sync/push', body: body);
    return _decodeObject(responseResult);
  }

  ApiResult<Map<String, dynamic>> _decodeObject(
    ApiResult<http.Response> responseResult,
  ) {
    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _transport.decodeSuccess(response, (json) => json);
        }
        return ApiFailureResult(ApiFailureMapper.fromResponse(response));
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
