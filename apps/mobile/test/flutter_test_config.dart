import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage/sqlite/support/configure_sqlite_test_ffi.dart';
import 'support/release_suite_static_state_reset.dart';

/// `AppServices.resetForTest` starts `ConnectivityAwareNetworkSource`,
/// which throws `MissingPluginException` without this channel stub.
void _stubConnectivityPlusChannel() {
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'check') return ['wifi'];
        return null;
      });
}

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  _stubConnectivityPlusChannel();
  configureSqliteTestFfi();

  setUp(() async {
    _stubConnectivityPlusChannel();
    await AppSqliteDatabase.resetForTest();
    SecureSqliteLockService.instance
      ..resetForTest()
      ..session.unlock(SqliteDatabaseInitializer.testEncryptionPassword);
    await ReleaseSuiteStaticStateReset.resetCachedState();
  });
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
