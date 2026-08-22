import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';

/// Shared SQLCipher password for all local database unit/integration tests.
String get testSqliteEncryptionPassword =>
    SqliteDatabaseInitializer.testEncryptionPassword;

/// Opens an encrypted [AppSqliteDatabase] for tests using [testSqliteEncryptionPassword].
Future<AppSqliteDatabase> openTestAppSqliteDatabase({
  String filePath = ':memory:',
}) {
  return AppSqliteDatabase.open(
    filePath: filePath,
    password: testSqliteEncryptionPassword,
  );
}
