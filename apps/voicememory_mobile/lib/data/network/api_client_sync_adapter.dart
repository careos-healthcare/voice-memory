import '../../api/api_client.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import 'sync_api_client.dart';

/// Adapts legacy [ApiClient] sync methods for tests and transitional call sites.
class ApiClientSyncAdapter implements SyncApiClient {
  const ApiClientSyncAdapter(this._api);

  final ApiClient _api;

  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() =>
      _wrap(_api.syncManifest());

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() =>
      _wrap(_api.syncPull());

  @override
  Future<ApiResult<Map<String, dynamic>>> syncChanges({required int since}) =>
      _wrap(_api.syncChanges(since: since));

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(Map<String, dynamic> body) =>
      _wrap(_api.syncPush(body));

  Future<ApiResult<Map<String, dynamic>>> _wrap(
    Future<Map<String, dynamic>> call,
  ) async {
    try {
      return ApiSuccess(await call);
    } on Object catch (error) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
  }
}
