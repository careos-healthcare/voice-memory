import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android adapter uses private no-backup storage', () {
    final source = File(
      'android/app/src/main/kotlin/com/voicememory/mobile/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('archive_me/sensitive_temporary_audio_store'));
    expect(
      source,
      contains('File(noBackupFilesDir, "sensitive_temporary_audio")'),
    );
    expect(source, contains('directory.canonicalPath'));
  });

  test('iOS adapter excludes protected Application Support from backup', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('archive_me/sensitive_temporary_audio_store'));
    expect(source, contains('.applicationSupportDirectory'));
    expect(source, contains('values.isExcludedFromBackup = true'));
    expect(source, contains('FileProtectionType.completeUnlessOpen'));
  });

  test('Dart adapter exposes only protected directory method', () {
    final source = File(
      'lib/services/privacy/sensitive_temporary_audio_store.dart',
    ).readAsStringSync();

    expect(source, contains("invokeMethod<String>('protectedDirectory')"));
    expect(source, isNot(contains('getTemporaryDirectory')));
  });
}
