import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/features/sync/services/account_sync_key.dart';
import 'package:archiveme_mobile/features/sync/services/device_pairing_service.dart';
import 'package:archiveme_mobile/features/sync/views/recovery_key_backup_view.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AccountSyncKey.debugKdf = Argon2id(
      parallelism: 1,
      memory: 32,
      iterations: 1,
      hashLength: 32,
    );
  });

  tearDown(() => AccountSyncKey.debugKdf = null);

  test(
    'a 24-word phrase derives the same master key for the same salt',
    () async {
      final phrase = AccountSyncKey.recoveryPhrase();
      expect(AccountSyncKey.verifyRecoveryPhrase(phrase), isTrue);
      expect(phrase.split(' '), hasLength(24));

      final words = phrase.split(' ');
      words[words.length - 1] = words.last == 'abandon' ? 'ability' : 'abandon';
      expect(AccountSyncKey.verifyRecoveryPhrase(words.join(' ')), isFalse);

      final account = AccountSyncKey.generate(Random(1));
      final salt = List<int>.filled(16, 3);
      final first = await AccountSyncKey.wrapWithSecret(
        accountKey: account,
        secret: phrase,
        salt: salt,
      );
      final second = await AccountSyncKey.unwrap(
        wrapped: first,
        secret: phrase,
      );
      expect(second, account);
      expect(first.innerNonce, isNot(first.nonce));
      expect(first.kdf.parallelism, 1);
    },
  );

  test('a second device unwraps with the salt published for the account', () async {
    final phrase = 'correct horse battery staple';
    final account = AccountSyncKey.generate(Random(2));
    final bundle = await AccountSyncKey.wrap(
      accountKey: account,
      passphrase: phrase,
      recoveryPhrase: phrase,
    );
    Map<String, Object>? published;
    await AccountSyncKeyImport.publish(bundle, post: (body) async {
      published = body;
    });
    final wrapped = published!['wrappedByPassphrase']! as Map<String, Object>;
    final imported = await AccountSyncKeyImport.importExisting(
      passphrase: phrase,
      persist: false,
      fetchParams: () async => {
        'salt': wrapped['salt'],
        'kdf': published!['kdfParams'],
        'createdAt': published!['createdAt'],
        'wrappedByPassphrase': wrapped,
        'wrappedByRecovery': published!['wrappedByRecovery'],
      },
    );
    expect(imported.accountKey, account);
    expect(imported.bundle.wrappedByPassphrase.salt, bundle.wrappedByPassphrase.salt);

    final divergent = await AccountSyncKey.wrapWithSecret(
      accountKey: AccountSyncKey.generate(Random(3)),
      secret: phrase,
      salt: List<int>.filled(16, 9),
    );
    expect(divergent.salt, isNot(bundle.wrappedByPassphrase.salt));
    expect(
      () => AccountSyncKeyImport.importExisting(
        passphrase: phrase,
        persist: false,
        fetchParams: () async => null,
      ),
      throwsA(isA<AccountKeyUnlockFailed>()),
    );
  });

  test('a pairing code carries a public key and the relay returns the account key', () async {
    final memory = <String, String>{};
    final relay = <String, Map<String, Object>>{};
    final newbie = DevicePairingService(
      write: (key, value) async => memory[key] = value,
      read: (key) async => memory[key],
      postTransfer: (body) async => relay[body['id'] as String] = body,
      fetchTransfer: (id) async => relay[id],
    );
    final existing = DevicePairingService(
      postTransfer: (body) async => relay[body['id'] as String] = body,
    );
    final now = DateTime.utc(2026, 9, 26, 8);
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
    final masterKey = List<int>.generate(32, (index) => index);
    final offer = await newbie.createPairingOffer(now: now);
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(offer.payload.substring('tp-pair:'.length))),
    ) as Map;

    expect(decoded['v'], 2);
    expect(decoded.containsKey('wrap'), isFalse);
    expect(decoded.containsKey('masterKey'), isFalse);
    expect(offer.payload.contains(base64Encode(masterKey)), isFalse);

    await existing.sendAccountKey(
      scannedPayload: offer.payload,
      accountKey: masterKey,
      salt: List<int>.filled(16, 7),
      now: now,
    );
    final posted = relay[offer.id]!;
    expect(posted.containsKey('wrap'), isFalse);
    expect(posted.containsKey('masterKey'), isFalse);
    expect(posted['ciphertext'], isNot(base64Encode(masterKey)));

    final opened = await newbie.finishPairing(offer: offer, now: now);
    expect(opened.masterKey, masterKey);
    expect((await newbie.readMasterKey())?.salt, List<int>.filled(16, 7));

    expect(
      () => newbie.finishPairing(
        offer: offer,
        now: now.add(const Duration(minutes: 6)),
      ),
      throwsA(isA<PairingExpired>()),
    );

    final tampered = Map<String, Object>.from(posted);
    final cipher = base64Decode(tampered['ciphertext'] as String);
    cipher[0] ^= 0x01;
    tampered['ciphertext'] = base64Encode(cipher);
    relay[offer.id] = tampered;
    final fresh = DevicePairingService(
      write: (key, value) async => memory['tamper'] = value,
      read: (key) async => memory[key],
      fetchTransfer: (id) async => relay[id],
    );
    final again = await fresh.createPairingOffer(now: now);
    relay[again.id] = tampered;
    expect(
      () => fresh.finishPairing(offer: again, now: now),
      throwsA(isA<PairingNotAuthentic>()),
    );
  });

  testWidgets(
    'recovery setup continues only after the 24 words are typed back',
    (
      tester,
    ) async {
      final phrase = AccountSyncKey.recoveryPhrase();
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
