import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_session.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage/sqlite/support/configure_sqlite_test_ffi.dart';
import 'support/release_suite_static_state_reset.dart';

/// `connectivity_plus` platform channel — unimplemented under `flutter test`.
const _connectivityChannel = MethodChannel(
  'dev.fluttercommunity.plus/connectivity',
);

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureSqliteTestFfi();

  setUp(() async {
    // AppServices.resetForTest starts ConnectivityAwareNetworkSource, which
    // calls the connectivity_plus channel and throws MissingPluginException in
    // the headless test binding. Provide a default "online" stub for the whole
    // suite; individual tests may override this handler as needed.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_connectivityChannel, (call) async {
      if (call.method == 'check') return <String>['wifi'];
      return null;
    });

    await AppSqliteDatabase.resetForTest();
    SecureSqliteLockService.instance
      ..resetForTest()
      ..session
          .unlock(SqliteDatabaseInitializer.testEncryptionPassword);
    await ReleaseSuiteStaticStateReset.resetCachedState();
  });
  await testMain();
}