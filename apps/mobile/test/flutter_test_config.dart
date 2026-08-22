import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_session.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage/sqlite/support/configure_sqlite_test_ffi.dart';
import 'support/release_suite_static_state_reset.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureSqliteTestFfi();

  setUp(() async {
    await AppSqliteDatabase.resetForTest();
    SecureSqliteLockService.instance
      ..resetForTest()
      ..session
          .unlock(SqliteDatabaseInitializer.testEncryptionPassword);
    await ReleaseSuiteStaticStateReset.resetCachedState();
  });
  await testMain();
}