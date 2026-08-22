import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_graph_backfill.dart';
import 'package:sqflite/sqflite.dart';

/// Stamps `transcriptProvenance: unknown_legacy` onto journal payloads written
/// before the field existed.
///
/// This is a materialisation, not a correction. `JournalEntry.fromJson` already
/// maps a missing value to [TranscriptProvenance.unknownLegacy], so a row that
/// has not been stamped yet still reads back as untrusted and still yields no
/// evidence source. Nothing is quotable on the strength of this backfill having
/// run, which is why it is allowed to take its time.
///
/// What the stamp buys is that the row says so on disk: a payload that has been
/// through here can no longer be mistaken for one written by a build that knew
/// about provenance, and a future change to the decoder's default cannot
/// retroactively promote it.
///
/// Properties, and how each is obtained:
///
/// * **Idempotent.** The predicate selects rows whose payload has no
///   `transcriptProvenance` key. Stamping a row removes it from that set, so a
///   second run over the same database matches nothing. There is no "already
///   applied" bookkeeping that could disagree with the data.
/// * **Safe after a kill.** Each batch is one `UPDATE` — atomic in SQLite — and
///   the predicate is re-evaluated from the rows themselves on the next run, so
///   a process killed between batches resumes exactly where it stopped. No
///   cursor is persisted, so no cursor can be stale.
/// * **Lossless.** `json_set` adds one member and rewrites nothing else, and
///   the statement touches no other column. In particular `updated_at`,
///   `revision`, and `change_id` are left alone, so the backfill cannot look
///   like a user edit, cannot enqueue an upload, and cannot lose a conflict
///   against another device.
/// * **Bounded per pass.** Work is done [batchSize] rows at a time rather than
///   as one table-wide statement, so a large archive cannot hold a write lock
///   or a transaction open for the length of the whole rewrite.
abstract final class TranscriptProvenanceBackfill {
  TranscriptProvenanceBackfill._();

  static const metaTable = ReflectionGraphBackfill.metaTable;
  static const backfillCompleteKey = 'transcript_provenance_backfill_v1';

  static const table = DatabaseConstants.journalEntriesTable;

  /// Rows per statement. Small enough that one batch is a short write lock even
  /// on a slow device, large enough that a big archive finishes in few passes.
  static const int batchSize = 500;

  static const String _jsonPath = r'$.transcriptProvenance';

  static final String _legacyValue =
      TranscriptProvenance.unknownLegacy.storageValue;

  /// Rows that are candidates for stamping.
  ///
  /// `json_valid` matters: `json_extract` raises on malformed text, which would
  /// abort the statement and strand every later row. A payload that will not
  /// parse is skipped here and still decodes to `unknownLegacy` at read time,
  /// because the decoder cannot find the key either.
  ///
  /// A NULL or empty payload is excluded as well. `json_set` returns NULL for
  /// those, so including them would rewrite nothing while leaving them matched
  /// — the batch would report progress forever without making any.
  static const String _pendingWhere = '''
    payload_json IS NOT NULL
    AND payload_json != ''
    AND json_valid(payload_json) = 1
    AND json_extract(payload_json, '$_jsonPath') IS NULL
  ''';

  /// Whether any payload still lacks the field.
  static Future<bool> isPending(DatabaseExecutor db) async {
    if (await _hasCompletionFlag(db)) return false;
    return await pendingCount(db, limit: 1) > 0;
  }

  /// Number of unstamped rows, capped at [limit] so callers can ask the cheap
  /// "is there any" question without counting a whole archive.
  static Future<int> pendingCount(DatabaseExecutor db, {int? limit}) async {
    final limitClause = limit == null ? '' : 'LIMIT $limit';
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS pending FROM (
        SELECT 1 FROM $table WHERE $_pendingWhere $limitClause
      )
    ''');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Stamps up to [batchSize] rows with a rowid greater than [afterRowid].
  ///
  /// Working in rowid order lets [run] carry a watermark forward so that later
  /// batches in one pass do not re-examine the rows earlier batches already
  /// stamped. The watermark is held in memory only — it is an optimisation, not
  /// state the correctness of a resumed run depends on. Starting again from
  /// zero produces the same result, just after a longer scan.
  static Future<TranscriptProvenanceBatch> runBatch(
    DatabaseExecutor db, {
    int batchSize = batchSize,
    int afterRowid = 0,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT rowid AS row_id FROM $table
      WHERE rowid > ? AND $_pendingWhere
      ORDER BY rowid ASC
      LIMIT $batchSize
      ''',
      [afterRowid],
    );
    if (rows.isEmpty) {
      return TranscriptProvenanceBatch(stamped: 0, lastRowid: afterRowid);
    }

    final rowIds = rows.map((row) => row['row_id'] as int).toList();
    final placeholders = List.filled(rowIds.length, '?').join(',');
    final stamped = await db.rawUpdate(
      '''
      UPDATE $table
      SET payload_json = json_set(payload_json, '$_jsonPath', ?)
      WHERE rowid IN ($placeholders)
      ''',
      [_legacyValue, ...rowIds],
    );
    return TranscriptProvenanceBatch(stamped: stamped, lastRowid: rowIds.last);
  }

  /// Runs batches until nothing is left, then records completion.
  ///
  /// [maxBatches] caps a single invocation so one app launch cannot spend
  /// unbounded time here. Whatever is left is picked up next launch, and the
  /// completion flag is written only after a batch genuinely finds no remaining
  /// rows — a run that stops early because it hit the cap leaves the flag
  /// unset, so it will be resumed rather than assumed done.
  static Future<int> run(
    DatabaseExecutor db, {
    int batchSize = batchSize,
    int maxBatches = 40,
  }) async {
    var stamped = 0;
    var afterRowid = 0;
    for (var batch = 0; batch < maxBatches; batch++) {
      final result = await runBatch(
        db,
        batchSize: batchSize,
        afterRowid: afterRowid,
      );
      if (result.stamped == 0) {
        await markComplete(db);
        return stamped;
      }
      stamped += result.stamped;
      afterRowid = result.lastRowid;
    }
    return stamped;
  }

  static Future<void> markComplete(DatabaseExecutor db) async {
    if (!await _tableExists(db, metaTable)) return;
    await db.insert(
      metaTable,
      {'key': backfillCompleteKey, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<bool> _hasCompletionFlag(DatabaseExecutor db) async {
    if (!await _tableExists(db, metaTable)) return false;
    final rows = await db.query(
      metaTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [backfillCompleteKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Clears the completion flag so a later pass re-examines every row.
  static Future<void> resetForTest(DatabaseExecutor db) async {
    if (!await _tableExists(db, metaTable)) return;
    await db.delete(
      metaTable,
      where: 'key = ?',
      whereArgs: [backfillCompleteKey],
    );
  }

  static Future<bool> _tableExists(
    DatabaseExecutor db,
    String tableName,
  ) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return rows.isNotEmpty;
  }
}

/// Outcome of one [TranscriptProvenanceBackfill.runBatch] pass.
class TranscriptProvenanceBatch {
  const TranscriptProvenanceBatch({
    required this.stamped,
    required this.lastRowid,
  });

  final int stamped;

  /// Highest rowid considered, so the next batch can start past it.
  final int lastRowid;
}
