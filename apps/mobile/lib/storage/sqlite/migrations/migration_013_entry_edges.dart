import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Automated semantic edges between journal entries for the personal knowledge graph.
class Migration013EntryEdges implements SqliteMigration {
  @override
  int get version => 13;

  @override
  String get id => '013_entry_edges';

  static const edgesTable = 'entry_edges';
  static const relationSemanticSimilarity = 'semantic_similarity';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $edgesTable (
        source_entry_id TEXT NOT NULL,
        target_entry_id TEXT NOT NULL,
        relation TEXT NOT NULL DEFAULT '$relationSemanticSimilarity',
        weight REAL NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (source_entry_id, target_entry_id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entry_edges_source
      ON $edgesTable(source_entry_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entry_edges_target
      ON $edgesTable(target_entry_id)
    ''');
  }
}
