import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:http/http.dart' as http;

/// A cloud upload that must not move the backfill cursor.
class CloudUploadException implements Exception {
  const CloudUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Uploads journal chunks and refuses to record progress when the API fails.
class CloudBackfillService {
  CloudBackfillService({
    Future<ApiResult<http.Response>> Function(List<JournalEntry> chunk)?
    postChunk,
    Future<ApiResult<http.Response>> Function(DirtyJournalRow row)? postDirty,
    Future<ApiResult<http.Response>> Function(String entryId)? deleteDirty,
    Future<List<DirtyJournalRow>> Function()? loadDirtyEntries,
    Future<List<String>> Function()? loadDirtyTombstones,
    Future<void> Function(String id)? clearEntryDirty,
    Future<void> Function(String id)? clearTombstoneDirty,
    Future<void> Function(int cursor)? writeCursor,
    Future<void> Function(String entryId)? writeLastEntryId,
    Future<void> Function(String timestamp)? writeTimestamp,
  }) : _postChunk = postChunk,
       _postDirty = postDirty,
       _deleteDirty = deleteDirty,
       _loadDirtyEntries = loadDirtyEntries,
       _loadDirtyTombstones = loadDirtyTombstones,
       _clearEntryDirty = clearEntryDirty,
       _clearTombstoneDirty = clearTombstoneDirty,
       _writeCursor = writeCursor,
       _writeLastEntryId = writeLastEntryId,
       _writeTimestamp = writeTimestamp;

  static const cursorKey = 'cloud_backfill_cursor';
  static const lastSyncedEntryIdKey = 'last_synced_entry_id';
  static const lastCloudSyncTimestampKey = 'last_cloud_sync_timestamp';

  final Future<ApiResult<http.Response>> Function(List<JournalEntry> chunk)?
  _postChunk;
  final Future<ApiResult<http.Response>> Function(DirtyJournalRow row)?
  _postDirty;
  final Future<ApiResult<http.Response>> Function(String entryId)? _deleteDirty;
  final Future<List<DirtyJournalRow>> Function()? _loadDirtyEntries;
  final Future<List<String>> Function()? _loadDirtyTombstones;
  final Future<void> Function(String id)? _clearEntryDirty;
  final Future<void> Function(String id)? _clearTombstoneDirty;
  final Future<void> Function(int cursor)? _writeCursor;
  final Future<void> Function(String entryId)? _writeLastEntryId;
  final Future<void> Function(String timestamp)? _writeTimestamp;

  /// Sends edits and deletions made while cloud sync was off.
  ///
  /// The sequential cursor stays where it is.
  Future<void> flushDirty() async {
    final entries = await (_loadDirtyEntries ?? _readDirtyEntries)();
    for (final row in entries) {
      final result = row.deleted
          ? await (_deleteDirty ?? _deleteEntry)(row.id)
          : await (_postDirty ?? _postEntry)(row);
      rejectFailedUpload(result);
      await (_writeLastEntryId ?? _storeLastEntryId)(row.id);
      await (_writeTimestamp ?? _storeTimestamp)(
        DateTime.now().toUtc().toIso8601String(),
      );
      await (_clearEntryDirty ?? _clearEntry)(row.id);
    }
    final tombstones = await (_loadDirtyTombstones ?? _readDirtyTombstones)();
    for (final id in tombstones) {
      final result = await (_deleteDirty ?? _deleteEntry)(id);
      rejectFailedUpload(result);
      await (_writeLastEntryId ?? _storeLastEntryId)(id);
      await (_clearTombstoneDirty ?? _clearTombstone)(id);
    }
  }

  /// Posts one accepted chunk, then records the cursor and last entry id.
  Future<void> acceptChunk({
    required List<JournalEntry> chunk,
    required int nextCursor,
  }) async {
    if (chunk.isEmpty) return;
    final result = await (_postChunk ?? _postBulk)(chunk);
    rejectFailedUpload(result);
    await (_writeCursor ?? _storeCursor)(nextCursor);
    await (_writeLastEntryId ?? _storeLastEntryId)(chunk.last.id);
    await (_writeTimestamp ?? _storeTimestamp)(
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// A 200 response tests and injected posters can return after a throw-free send.
  static ApiResult<http.Response> acceptedResponse() {
    return ApiSuccess(http.Response('{"ok":true}', 200));
  }

  /// Throws when the transport reports an error or the server rejects the body.
  static void rejectFailedUpload(ApiResult<http.Response> result) {
    if (result.isError) {
      throw CloudUploadException(
        result.failureOrNull?.message ?? 'Cloud upload failed',
      );
    }
    final status = result.valueOrNull?.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw const CloudUploadException('Cloud upload failed');
    }
  }

  static Future<List<DirtyJournalRow>> _readDirtyEntries() async {
    if (!AppServices.isInitialized) return const [];
    return DatabaseProvider(
      AppServices.instance.sqliteDatabase.database,
    ).dirtyEntries();
  }

  static Future<List<String>> _readDirtyTombstones() async {
    if (!AppServices.isInitialized) return const [];
    return DatabaseProvider(
      AppServices.instance.sqliteDatabase.database,
    ).dirtyTombstoneIds();
  }

  static Future<void> _clearEntry(String id) async {
    if (!AppServices.isInitialized) return;
    await DatabaseProvider(
      AppServices.instance.sqliteDatabase.database,
    ).clearEntryDirty(id);
  }

  static Future<void> _clearTombstone(String id) async {
    if (!AppServices.isInitialized) return;
    await DatabaseProvider(
      AppServices.instance.sqliteDatabase.database,
    ).clearTombstoneDirty(id);
  }

  static Future<ApiResult<http.Response>> _postBulk(
    List<JournalEntry> chunk,
  ) {
    return _post(CloudSyncService.bulkImportPath, {
      'chunks': [
        for (final entry in chunk)
          {
            'entryId': entry.id,
            'rawText': entry.transcript.trim(),
            'createdAt': entry.createdAt.toUtc().toIso8601String(),
          },
      ],
    });
  }

  static Future<ApiResult<http.Response>> _postEntry(DirtyJournalRow row) {
    return _post(CloudSyncService.ingestPath, {
      'entryId': row.id,
      'createdAt': row.createdAt.toUtc().toIso8601String(),
      'transcript': row.transcript.trim(),
    });
  }

  static Future<ApiResult<http.Response>> _deleteEntry(String entryId) async {
    if (!AppServices.isInitialized) {
      throw const CloudUploadException('Cloud upload failed');
    }
    return AppServices.instance.httpTransport.delete(
      CloudSyncService.entryPath,
      body: {'entryId': entryId},
    );
  }

  static Future<ApiResult<http.Response>> _post(
    String path,
    Map<String, Object> body,
  ) async {
    if (!AppServices.isInitialized) {
      throw const CloudUploadException('Cloud upload failed');
    }
    return AppServices.instance.httpTransport.post(path, body: body);
  }

  static Future<void> _storeCursor(int cursor) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(cursorKey, '$cursor');
  }

  static Future<void> _storeLastEntryId(String entryId) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(lastSyncedEntryIdKey, entryId);
  }

  static Future<void> _storeTimestamp(String timestamp) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(
      lastCloudSyncTimestampKey,
      timestamp,
    );
  }
}

/// Records a local create, edit, or delete as needing a cloud upload.
class JournalSyncDirtyInterceptor implements JournalSaveInterceptor {
  const JournalSyncDirtyInterceptor();

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    if (!AppServices.isInitialized || entry.id.isEmpty) return;
    try {
      final db = DatabaseProvider(AppServices.instance.sqliteDatabase.database);
      await db.markEntryDirty(
        id: entry.id,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        transcript: entry.transcript,
        deletedAt: entry.deletedAt,
      );
      if (entry.isDeleted) {
        await db.recordTombstone(entry.id, deletedAt: entry.deletedAt);
      }
    } on Object {
      return;
    }
  }
}
