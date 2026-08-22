import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Creates account identity anchors and the unified `user_relationships` table.
class Migration001UserRelationships implements SqliteMigration {
  @override
  int get version => 1;

  @override
  String get id => '001_user_relationships';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS account_identities (
        id TEXT PRIMARY KEY NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_relationships (
        id TEXT PRIMARY KEY NOT NULL,
        client_id TEXT NOT NULL,
        professional_id TEXT NOT NULL,
        relationship_type TEXT NOT NULL CHECK (
          relationship_type IN ('professional', 'caregiver')
        ),
        consent_status TEXT NOT NULL CHECK (
          consent_status IN ('pending', 'active', 'revoked')
        ),
        agreed_scope TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (client_id) REFERENCES account_identities(id),
        FOREIGN KEY (professional_id) REFERENCES account_identities(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_user_relationships_client
      ON user_relationships(client_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_user_relationships_professional
      ON user_relationships(professional_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_user_relationships_status
      ON user_relationships(consent_status)
    ''');
  }
}