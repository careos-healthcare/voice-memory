import 'package:sqflite/sqflite.dart';

/// Single versioned schema change applied by [SqliteMigrationManager].
abstract class SqliteMigration {
  int get version;
  String get id;
  Future<void> up(DatabaseExecutor db);
}