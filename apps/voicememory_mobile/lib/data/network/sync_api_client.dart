import '../../core/network/api_result.dart';

/// Encrypted journal sync REST boundary — `/api/sync/*`.
abstract class SyncApiClient {
  Future<ApiResult<Map<String, dynamic>>> syncManifest();

  Future<ApiResult<Map<String, dynamic>>> syncPull();

  Future<ApiResult<Map<String, dynamic>>> syncChanges({required int since});

  Future<ApiResult<Map<String, dynamic>>> syncPush(Map<String, dynamic> body);
}
