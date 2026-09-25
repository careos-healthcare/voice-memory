import 'dart:io';
import 'dart:typed_data';

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
  await _loadBundledFonts();
  configureSqliteTestFfi();

  setUp(() async {
    // AppServices.resetForTest / capture pipeline start ConnectivityAwareNetwork
    // Source, which calls the connectivity_plus channel and throws
    // MissingPluginException in the headless test binding. Provide a default
    // "online" stub for the whole suite; individual tests may override it.
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

/// Registers the same Inter and Newsreader files the app bundles, so golden
/// text is real type instead of fallback boxes.
Future<void> _loadBundledFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  await inter.load();
  final newsreader = FontLoader('Newsreader')
    ..addFont(rootBundle.load('assets/fonts/Newsreader-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Newsreader-Italic.ttf'));
  await newsreader.load();
  await _loadMaterialIcons();
}

/// Icon font used by mic, play, and trust-footer glyphs. Inter is the UI face
/// for TrustStatusFooter and the voice/typed source label.
Future<void> _loadMaterialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) return;
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}