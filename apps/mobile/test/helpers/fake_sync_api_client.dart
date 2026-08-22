import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

class FakeSyncApiClient implements SyncApiClient {
  FakeSyncApiClient();

  List<JournalEntry> legacyEntries = [];
  int listLegacyJournalCalls = 0;
  int syncPushCalls = 0;

  Future<ApiResult<Map<String, dynamic>>> Function(Map<String, dynamic> body)?
  onSyncPush;

  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() async {
    return const ApiSuccess({'blobs': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    return const ApiSuccess({'blobs': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncChanges({
    required int since,
  }) async {
    return const ApiSuccess({'changes': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    syncPushCalls++;
    if (onSyncPush != null) {
      return onSyncPush!(body);
    }
    return const ApiSuccess({
      'ok': true,
      'manifest': {'blobs': []},
    });
  }

  @override
  Future<ApiResult<List<JournalEntry>>> listLegacyJournal({
    NetworkCancelToken? cancelToken,
  }) async {
    listLegacyJournalCalls++;
    return ApiSuccess(List<JournalEntry>.from(legacyEntries));
  }
}