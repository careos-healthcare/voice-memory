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

/// Registers the bundled faces plus Roboto, which theme metadata, duration
/// stamps, and trust footers use. Without Roboto, those lines paint as
/// fallback blocks.
Future<void> _loadBundledFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  await inter.load();
  final newsreader = FontLoader('Newsreader')
    ..addFont(rootBundle.load('assets/fonts/Newsreader-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Newsreader-Italic.ttf'));
  await newsreader.load();
  await _loadSdkFamily('Roboto', const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
  ]);
  await _loadMaterialIcons();
}

Future<void> _loadSdkFamily(String family, List<String> fileNames) async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) return;
  final loader = FontLoader(family);
  var added = false;
  for (final name in fileNames) {
    final file = File('$root/bin/cache/artifacts/material_fonts/$name');
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    added = true;
  }
  if (added) await loader.load();
}

Future<void> _loadMaterialIcons() async {
  await _loadSdkFamily('MaterialIcons', const ['MaterialIcons-Regular.otf']);
}