import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_key_provider.dart';

void main() {
  group('VaultKeyProvider', () {
    test('testing factory returns stable in-memory master key', () async {
      final provider = VaultKeyProvider.testing(
        keyBytes: List<int>.generate(VaultKeyProvider.keyByteLength, (i) => i),
      );

      final first = await provider.getOrCreateMasterKey();
      final second = await provider.getOrCreateMasterKey();

      expect(first, same(second));
      expect(
        await first.extractBytes(),
        hasLength(VaultKeyProvider.keyByteLength),
      );
    });

    test('testing factory rejects invalid key length', () {
      expect(
        () => VaultKeyProvider.testing(keyBytes: [1, 2, 3]),
        throwsArgumentError,
      );
    });

    test('initialKey bypasses secure storage reads', () async {
      final seeded = SecretKey(
        List<int>.filled(VaultKeyProvider.keyByteLength, 9),
      );
      final provider = VaultKeyProvider(initialKey: seeded);

      final resolved = await provider.getOrCreateMasterKey();
      expect(await resolved.extractBytes(), await seeded.extractBytes());
    });

    test('clearCache forces a new read path on next access', () async {
      final provider = VaultKeyProvider.testing();
      final first = await provider.getOrCreateMasterKey();

      provider.clearCache();

      final second = await provider.getOrCreateMasterKey();
      expect(await second.extractBytes(), await first.extractBytes());
    });

    test('install can roll back persisted and cached key', () async {
      final original = List<int>.filled(VaultKeyProvider.keyByteLength, 3);
      final store = _MemoryVaultKeyStore(_hex(original));
      final provider = VaultKeyProvider(keyStore: store);
      expect(
        await (await provider.getOrCreateMasterKey()).extractBytes(),
        original,
      );

      final replacement = await provider.installMasterKey(
        Uint8List.fromList(List<int>.filled(VaultKeyProvider.keyByteLength, 9)),
      );
      expect(
        await (await provider.getOrCreateMasterKey()).extractBytes(),
        everyElement(9),
      );

      await provider.rollbackMasterKey(replacement);
      expect(
        await (await provider.getOrCreateMasterKey()).extractBytes(),
        original,
      );
      expect(() => provider.rollbackMasterKey(replacement), throwsStateError);
    });
  });
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

final class _MemoryVaultKeyStore implements VaultKeyStore {
  _MemoryVaultKeyStore(this.value);
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
