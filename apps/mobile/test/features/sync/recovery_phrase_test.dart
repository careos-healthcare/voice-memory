import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/features/sync/recovery_export_screen.dart';
import 'package:archiveme_mobile/features/sync/secure_key_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStoragePlatform previous;
  late Map<String, String> memory;

  setUp(() {
    previous = FlutterSecureStoragePlatform.instance;
    memory = <String, String>{};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      memory,
    );
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance = previous;
  });

  SecureKeyManager keys() =>
      SecureKeyManager(secureStorage: const FlutterSecureStorage());

  test(
    'a 12-word phrase derives the same 256-bit key on another device',
    () async {
      final source = keys();
      final phrase = source.createRecoveryPhrase();
      expect(phrase.split(' '), hasLength(12));
      await source.confirmRecoveryPhrase(phrase);
      final stored = await source.readKeyBytes();

      final restored = keys();
      final again = await restored.restoreFromPhrase(phrase);
      expect(again, stored);
      expect(again, hasLength(SecureKeyManager.keyByteLength));
      expect(
        base64Decode(memory[SecureKeyManager.defaultStorageKey]!),
        stored,
      );
      expect(await restored.hasVerifiedRecoveryPhrase(), isTrue);
    },
  );

  test('backup stays off until the shown phrase is entered', () async {
    final manager = keys();
    const shown =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final checks = SecureKeyManager.selectWordIndexes(
      shown,
      random: Random(1),
    );
    final words = shown.split(' ');
    expect(
      await manager.enableCloudBackup(
        hasPremium: true,
        shownPhrase: shown,
        confirmedWords: {for (final index in checks) index: 'wrong'},
      ),
      isFalse,
    );
    expect(await manager.hasVerifiedRecoveryPhrase(), isFalse);
    expect(
      await manager.enableCloudBackup(
        hasPremium: false,
        shownPhrase: shown,
        confirmedWords: {for (final index in checks) index: words[index]},
      ),
      isFalse,
    );
    expect(
      await manager.enableCloudBackup(
        hasPremium: true,
        shownPhrase: shown,
        confirmedWords: {for (final index in checks) index: words[index]},
      ),
      isTrue,
    );
  });

  testWidgets('the export screen requires the phrase before backup', (
    tester,
  ) async {
    final manager = keys();
    var enabled = false;
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryExportScreen(
          keys: manager,
          hasPremium: true,
          onEnabled: () => enabled = true,
        ),
      ),
    );
    expect(find.byKey(const Key('recovery_word_11')), findsOneWidget);

    final checks = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.key)
        .whereType<ValueKey<String>>()
        .toList();
    expect(checks, hasLength(3));
    await tester.enterText(find.byKey(checks.first), 'wrong');
    final submit = find.byKey(const Key('recovery_phrase_submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
    expect(find.byKey(const Key('recovery_phrase_error')), findsOneWidget);

    final words = tester
        .widgetList<Chip>(find.byType(Chip))
        .map((chip) => (chip.label as Text).data!.split(' ').last)
        .toList();
    for (final key in checks) {
      final index = int.parse(key.value.split('_').last);
      final field = find.byKey(key);
      await tester.ensureVisible(field);
      await tester.enterText(field, words[index]);
    }
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(await manager.hasVerifiedRecoveryPhrase(), isTrue);
  });
}
