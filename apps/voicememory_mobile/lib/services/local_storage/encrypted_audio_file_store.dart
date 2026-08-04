import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'encrypted_storage_engine.dart';

typedef AudioEncryptionKeyProvider = FutureOr<Uint8List> Function();

class EncryptedAudioFileStore {
  EncryptedAudioFileStore({
    required AudioEncryptionKeyProvider keyProvider,
    EncryptedStorageEngine? engine,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _keyProvider = keyProvider,
       _engine = engine ?? EncryptedStorageEngine();

  final AudioEncryptionKeyProvider _keyProvider;
  final EncryptedStorageEngine _engine;

  Future<void> seal(File source, File destination) async {
    final key = await _keyProvider();
    final bytes = await source.readAsBytes();
    final temporary = File(
      '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await _engine.writeFile(temporary, bytes, keyBytes: key);
      await temporary.rename(destination.path);
    } finally {
      key.fillRange(0, key.length, 0);
      bytes.fillRange(0, bytes.length, 0);
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<T> withDecryptedFile<T>(
    File encrypted,
    Future<T> Function(File plaintext) operation,
  ) async {
    final key = await _keyProvider();
    final withoutVault = encrypted.path.endsWith('.vault')
        ? encrypted.path.substring(0, encrypted.path.length - 6)
        : encrypted.path;
    final extensionIndex = withoutVault.lastIndexOf('.');
    final unique =
        '${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(Object())}';
    final plaintext = File(
      extensionIndex <= 0
          ? '$withoutVault.$unique.working'
          : '${withoutVault.substring(0, extensionIndex)}.$unique.working'
                '${withoutVault.substring(extensionIndex)}',
    );
    try {
      final bytes = await _engine.readFile(encrypted, keyBytes: key);
      try {
        await plaintext.writeAsBytes(bytes, flush: true);
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      return await operation(plaintext);
    } finally {
      key.fillRange(0, key.length, 0);
      await _secureDelete(plaintext);
    }
  }

  static Future<void> _secureDelete(File file) async {
    if (!await file.exists()) return;
    try {
      final length = await file.length();
      final handle = await file.open(mode: FileMode.write);
      try {
        final zeros = Uint8List(64 * 1024);
        var remaining = length;
        while (remaining > 0) {
          final count = remaining < zeros.length ? remaining : zeros.length;
          await handle.writeFrom(zeros, 0, count);
          remaining -= count;
        }
        await handle.flush();
      } finally {
        await handle.close();
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}
