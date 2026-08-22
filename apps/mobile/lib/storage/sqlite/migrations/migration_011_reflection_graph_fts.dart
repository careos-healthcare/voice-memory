import 'package:archiveme_mobile/storage/sqlite/reflection_graph_backfill.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Persisted reflection knowledge-graph nodes + FTS5 index for label/kind search.
class Migration011ReflectionGraphFts implements SqliteMigration {
  @override
  int get version => 11;

  @override
  String get id => '011_reflection_graph_fts';

  static const nodesTable = 'reflection_graph_nodes';
  static const ftsTable = 'reflection_graph_node_fts';
  static const metaTable = ReflectionGraphBackfill.metaTable;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $nodesTable (
        id TEXT PRIMARY KEY NOT NULL,
        entry_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        label TEXT NOT NULL,
        payload_json TEXT,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reflection_graph_nodes_entry_id
      ON $nodesTable(entry_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reflection_graph_nodes_kind
      ON $nodesTable(kind)
    ''');

    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $ftsTable USING fts5(
        node_id UNINDEXED,
        entry_id UNINDEXED,
        kind,
        label,
        tokenize = 'porter unicode61'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $metaTable (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      )
    ''');
  }
}
