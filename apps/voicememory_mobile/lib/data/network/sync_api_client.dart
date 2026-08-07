import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../models/journal_entry.dart';

/// Encrypted journal sync REST boundary — `/api/sync/*`.
abstract class SyncApiClient {
  Future<ApiResult<Map<String, dynamic>>> syncManifest();

  Future<ApiResult<Map<String, dynamic>>> syncPull();

  Future<ApiResult<Map<String, dynamic>>> syncChanges({required int since});

  Future<ApiResult<Map<String, dynamic>>> syncPush(Map<String, dynamic> body);

  /// **Migration-only.** Reads legacy plaintext journal rows from
  /// `GET /api/journal`. Production mobile sync uses encrypted
  /// `/api/sync/*`; do not call this from normal sync paths.
  Future<ApiResult<List<JournalEntry>>> listLegacyJournal({
    NetworkCancelToken? cancelToken,
  });
}
