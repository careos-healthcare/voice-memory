import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _sqliteTestFfiConfigured = false;

/// Initializes [sqflite_common_ffi] for encrypted SQLCipher-backed unit tests.
void configureSqliteTestFfi() {
  if (_sqliteTestFfiConfigured) {
    return;
  }
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _sqliteTestFfiConfigured = true;
}
