import 'package:archiveme_mobile/features/sync/services/crypto_vault.dart';
import 'package:archiveme_mobile/features/sync/services/device_pairing_service.dart';
import 'package:archiveme_mobile/features/sync/views/recovery_key_backup_view.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    CryptoVault.debugKdf = Argon2id(
      parallelism: 1,
      memory: 32,
      iterations: 1,
      hashLength: 32,
    );
  });

  tearDown(() => CryptoVault.debugKdf = null);

  test(
    'a 24-word phrase derives the same master key for the same salt',
    () async {
      final phrase = CryptoVault.generateRecoveryPhrase();
      expect(CryptoVault.verifyRecoveryPhrase(phrase), isTrue);
      expect(phrase.split(' '), hasLength(24));

      final words = phrase.split(' ');
      words[words.length - 1] = words.last == 'abandon' ? 'ability' : 'abandon';
      expect(CryptoVault.verifyRecoveryPhrase(words.join(' ')), isFalse);

      final salt = CryptoVault.randomSalt();
      final first = await CryptoVault.deriveMasterKey(
        passphrase: phrase,
        salt: salt,
      );
      final second = await CryptoVault.deriveMasterKey(
        passphrase: phrase,
        salt: salt,
      );
      expect(first.bytes, second.bytes);
      expect(first.bytes, hasLength(32));
    },
  );

  test('a pairing code moves the master key until it expires', () async {
    final memory = <String, String>{};
    final service = DevicePairingService(
      write: (key, value) async => memory[key] = value,
      read: (key) async => memory[key],
    );
    final now = DateTime.utc(2026, 9, 26, 8);
    final code = await service.createPairingCode(
      masterKey: List<int>.generate(32, (index) => index),
      salt: List<int>.filled(16, 7),
      now: now,
    );

    expect(
      iosOptionsForMasterKey(
        MasterKeyKeychainScope.thisDeviceOnly,
      ).accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
    expect(
      iosOptionsForMasterKey(
        MasterKeyKeychainScope.thisDeviceOnly,
      ).synchronizable,
      isFalse,
    );
    expect(
      iosOptionsForMasterKey(MasterKeyKeychainScope.iCloud).synchronizable,
      isTrue,
    );
    expect(
      iosOptionsForMasterKey(MasterKeyKeychainScope.iCloud).accessibility,
      KeychainAccessibility.first_unlock,
    );

    final opened = await service.acceptPairingCode(code.payload, now: now);
    expect(opened.masterKey, List<int>.generate(32, (index) => index));
    expect((await service.readMasterKey())?.salt, List<int>.filled(16, 7));

    expect(
      () => service.openPairingCode(
        code.payload,
        now: now.add(const Duration(minutes: 6)),
      ),
      throwsA(isA<PairingExpired>()),
    );
  });

  testWidgets(
    'recovery setup continues only after the 24 words are typed back',
    (
      tester,
    ) async {
      final phrase = CryptoVault.generateRecoveryPhrase();
      await tester.pumpWidget(
        MaterialApp(home: RecoveryKeyBackupView(phrase: phrase)),
      );

    expect(find.text('1. ${phrase.split(' ').first}'), findsOneWidget);
    expect(find.byKey(const Key('recovery_verify_continue')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('recovery_wrote_them_down')),
      200,
    );
    await tester.tap(find.byKey(const Key('recovery_wrote_them_down')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('recovery_verify_continue')),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('recovery_verify_input')),
        'not the saved words',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('recovery_verify_continue')),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('recovery_verify_input')),
        phrase,
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('recovery_verify_continue')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
}
