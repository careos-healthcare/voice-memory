import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage/sqlite/support/configure_sqlite_test_ffi.dart';
import 'support/release_suite_static_state_reset.dart';

// Platform channels that are unimplemented under `flutter test` and throw
// MissingPluginException in the headless binding. We stub them for the whole
// suite so AppServices-backed and widget tests do not need to re-mock the same
// channels; individual tests may override any of these handlers as needed.
const _connectivityChannel = MethodChannel(
  'dev.fluttercommunity.plus/connectivity',
);
const _connectivityStatusChannel = EventChannel(
  'dev.fluttercommunity.plus/connectivity_status',
);
const _batteryChargingChannel = EventChannel(
  'dev.fluttercommunity.plus/charging',
);
const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureSqliteTestFfi();

  setUp(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // connectivity_plus.check() — AppServices.resetForTest starts
    // ConnectivityAwareNetworkSource, which calls this channel. Default online.
    messenger.setMockMethodCallHandler(_connectivityChannel, (call) async {
      if (call.method == 'check') return <String>['wifi'];
      return null;
    });

    // connectivity_plus.onConnectivityChanged — the event stream companion of
    // the method channel above. Emit a single "online" value on listen.
    messenger.setMockStreamHandler(
      _connectivityStatusChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) => sink.success(<String>['wifi']),
      ),
    );

    // battery_plus.onBatteryStateChanged — resource/thermal services subscribe
    // to charging state. Emit a benign "full" value on listen.
    messenger.setMockStreamHandler(
      _batteryChargingChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) => sink.success('full'),
      ),
    );

    // flutter_secure_storage — back it with an in-memory map, fresh per test so
    // secrets never leak across tests. Covers the read/write/delete surface used
    // by DeviceIdStore, encryption-key storage, and secure prefs.
    final secureStorage = <String, String>{};
    messenger.setMockMethodCallHandler(_secureStorageChannel, (call) async {
      final args =
          (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
      switch (call.method) {
        case 'read':
          return secureStorage[args['key'] as String?];
        case 'write':
          secureStorage[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          secureStorage.remove(args['key'] as String);
          return null;
        case 'deleteAll':
          secureStorage.clear();
          return null;
        case 'readAll':
          return Map<String, String>.from(secureStorage);
        case 'containsKey':
          return secureStorage.containsKey(args['key'] as String);
        default:
          return null;
      }
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