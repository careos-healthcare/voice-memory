import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:archiveme_mobile/storage/sqlite/transcript_provenance_backfill.dart';
import 'package:sqflite/sqflite.dart';

/// Prepares the one-time `transcriptProvenance` stamp for pre-existing rows.
///
/// The schema step itself is deliberately O(1): it only ensures the metadata
/// table the backfill records completion in exists. Rewriting every journal
/// payload happens in [TranscriptProvenanceBackfill], off this path.
///
/// That split is safe because the field's default does the load-bearing work.
/// `JournalEntry.fromJson` maps an absent `transcriptProvenance` to
/// `unknownLegacy`, so an un-stamped row is already read as untrusted and
/// already contributes no evidence source. Nothing is presented to the user as
/// their own words on the strength of this migration having finished, which is
/// what makes it acceptable for it to finish later — or, on a very large
/// archive, across several launches.
///
/// Migrations here run inside a single transaction that also bumps
/// `PRAGMA user_version`. Rewriting an entire archive inside that transaction
/// would hold a write lock across app start and would have to be re-done from
/// the beginning if the process were killed. Keeping the step O(1) means the
/// version bump is instant and cannot be left half-applied.
class Migration018TranscriptProvenance implements SqliteMigration {
  @override
  int get version => 18;

  @override
  String get id => '018_transcript_provenance';

  static const metaTable = TranscriptProvenanceBackfill.metaTable;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $metaTable (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      )
    ''');
  }
}
