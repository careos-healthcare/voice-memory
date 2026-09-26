import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_backfill_service.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:http/http.dart' as http;

/// Deletes the server copy of the journal and rewinds the local backfill.
class CloudDataService {
  const CloudDataService({
    Future<ApiResult<http.Response>> Function()? sendDelete,
    Future<void> Function()? resetLocal,
  }) : _sendDelete = sendDelete,
       _resetLocal = resetLocal;

  static const path = '/api/user/cloud-data';

  final Future<ApiResult<http.Response>> Function()? _sendDelete;
  final Future<void> Function()? _resetLocal;

  /// Calls `DELETE /api/user/cloud-data`.
  ///
  /// The cursor and last sync time change only after a successful response.
  Future<bool> deleteCloudCopy() async {
    final result = await (_sendDelete ?? _delete)();
    if (result.isError) return false;
    final status = result.valueOrNull?.statusCode ?? 0;
    if (status != 200) return false;
    await (_resetLocal ?? _resetCursors)();
    return true;
  }

  static Future<ApiResult<http.Response>> _delete() async {
    if (!AppServices.isInitialized) {
      return const ApiFailureResult(ApiFailureOffline());
    }
    return AppServices.instance.httpTransport.delete(path);
  }

  static Future<void> _resetCursors() async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    await prefs.writeString(CloudBackfillService.cursorKey, '0');
    await prefs.writeString(CloudSyncService.backfillCursorKey, '0');
    await prefs.remove(CloudBackfillService.lastSyncedEntryIdKey);
    await prefs.remove(CloudBackfillService.lastCloudSyncTimestampKey);
  }
}
