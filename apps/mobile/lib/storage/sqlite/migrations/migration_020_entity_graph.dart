import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Local entity graph: entities, relationships, and moment links.
class Migration020EntityGraph implements SqliteMigration {
  @override
  int get version => 20;

  @override
  String get id => '020_entity_graph';

  static const entitiesTable = 'entities';
  static const relationshipsTable = 'relationships';
  static const entryEntitiesTable = 'entry_entities';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $entitiesTable (
        id TEXT PRIMARY KEY,
        name TEXT,
        category TEXT,
        description TEXT,
        created_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $relationshipsTable (
        id TEXT PRIMARY KEY,
        source_id TEXT,
        target_id TEXT,
        relation_type TEXT,
        weight REAL,
        last_seen INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $entryEntitiesTable (
        entry_id TEXT,
        entity_id TEXT,
        PRIMARY KEY (entry_id, entity_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entities_category_name
      ON $entitiesTable(category, name)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_relationships_source
      ON $relationshipsTable(source_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_relationships_target
      ON $relationshipsTable(target_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entry_entities_entity
      ON $entryEntitiesTable(entity_id)
    ''');
  }
}
