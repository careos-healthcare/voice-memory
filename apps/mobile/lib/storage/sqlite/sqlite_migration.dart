import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_runner.dart' show SqliteMigrationRunner;
import 'package:sqflite/sqflite.dart';

/// Single versioned schema change applied by [SqliteMigrationRunner].
abstract class SqliteMigration {
  int get version;
  String get id;
  Future<void> up(DatabaseExecutor db);
}