import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

import 'helpers/memory_secure_storage.dart';

void main() {
  late Directory tempDirectory;
  late File legacyFile;
  late MemorySecureStorage secureStorage;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('vm_secure_prefs_');
    legacyFile = File('${tempDirectory.path}/prefs.json');
    secureStorage = MemorySecureStorage();
  });

  tearDown(() {
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('migrates legacy preferences then deletes the plaintext file', () async {
    await legacyFile.writeAsString(
      '{"onboardingCompleted":true,"privateNote":"keep me private"}',
    );

    final prefs = await MobilePrefsStore.open(
      legacyFile.path,
      secureStorage: secureStorage,
    );

    expect(await prefs.onboardingCompleted, isTrue);
    expect(await prefs.readString('privateNote'), 'keep me private');
    expect(legacyFile.existsSync(), isFalse);
    expect(
      await secureStorage.read(MobilePrefsStore.storageKey),
      contains('keep me private'),
    );
  });

  test('persists updates only through secure storage', () async {
    final prefs = await MobilePrefsStore.open(
      legacyFile.path,
      secureStorage: secureStorage,
    );
    await prefs.writeString('privateNote', 'encrypted preference');

    final reopened = await MobilePrefsStore.open(
      legacyFile.path,
      secureStorage: secureStorage,
    );

    expect(await reopened.readString('privateNote'), 'encrypted preference');
    expect(legacyFile.existsSync(), isFalse);
  });
}
