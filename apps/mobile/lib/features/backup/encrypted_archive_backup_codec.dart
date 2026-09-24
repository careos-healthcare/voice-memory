import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

/// Argon2id parameters stored in the archive header so restore uses the
/// same cost the file was sealed with.
class ArchiveBackupKdfProfile {
  const ArchiveBackupKdfProfile({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
  });

  /// OWASP-style interactive cost. Used for real backups.
  static const production = ArchiveBackupKdfProfile(
    memoryKib: 19456,
    iterations: 2,
    parallelism: 1,
  );

  /// Cheap parameters for unit tests. Never written by the app service.
  static const test = ArchiveBackupKdfProfile(
    memoryKib: 32,
    iterations: 2,
    parallelism: 1,
  );

  final int memoryKib;
  final int iterations;
  final int parallelism;
}

class EncryptedArchiveBackupException implements Exception {
  EncryptedArchiveBackupException(this.code);

  final String code;

  @override
  String toString() => 'EncryptedArchiveBackupException($code)';
}

/// Seals the SQLCipher database and audio files into one encrypted archive.
///
/// The file on disk is ciphertext. The recovery passphrase and the derived
/// key exist only in memory during seal and open.
abstract final class EncryptedArchiveBackupCodec {
  EncryptedArchiveBackupCodec._();

  static const magic = [0x56, 0x4d, 0x41, 0x42]; // VMAB
  static const formatVersion = 1;
  static const _saltLength = 16;

  static Future<Uint8List> seal({
    required File databaseFile,
    required Directory audioDirectory,
    required String passphrase,
    ArchiveBackupKdfProfile profile = ArchiveBackupKdfProfile.production,
  }) async {
    _requirePassphrase(passphrase);
    if (!databaseFile.existsSync()) {
      throw EncryptedArchiveBackupException('DATABASE_NOT_FOUND');
    }
    final zip = _pack(
      databaseBytes: await databaseFile.readAsBytes(),
      audioDirectory: audioDirectory,
    );
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(
      passphrase: passphrase,
      salt: salt,
      profile: profile,
    );
    final box = await AesGcm.with256bits().encrypt(
      zip,
      secretKey: SecretKey(key),
    );
    return _encode(
      profile: profile,
      salt: salt,
      nonce: box.nonce,
      mac: box.mac.bytes,
      cipherText: box.cipherText,
    );
  }

  /// Decrypts [sealed] fully before any file is written.
  static Future<void> restore({
    required Uint8List sealed,
    required String passphrase,
    required File databaseFile,
    required Directory audioDirectory,
  }) async {
    final opened = await open(sealed: sealed, passphrase: passphrase);
    await databaseFile.parent.create(recursive: true);
    await audioDirectory.create(recursive: true);
    final tempDb = File('${databaseFile.path}.restore-tmp');
    await tempDb.writeAsBytes(opened.databaseBytes, flush: true);
    if (databaseFile.existsSync()) {
      await databaseFile.delete();
    }
    await tempDb.rename(databaseFile.path);
    for (final entry in opened.audioFiles.entries) {
      final target = File('${audioDirectory.path}/${entry.key}');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.value, flush: true);
    }
  }

  static Future<({Uint8List databaseBytes, Map<String, Uint8List> audioFiles})>
  open({
    required Uint8List sealed,
    required String passphrase,
  }) async {
    _requirePassphrase(passphrase);
    final parsed = _decode(sealed);
    final key = await _deriveKey(
      passphrase: passphrase,
      salt: parsed.salt,
      profile: parsed.profile,
    );
    List<int> zipBytes;
    try {
      zipBytes = await AesGcm.with256bits().decrypt(
        SecretBox(
          parsed.cipherText,
          nonce: parsed.nonce,
          mac: Mac(parsed.mac),
        ),
        secretKey: SecretKey(key),
      );
    } on SecretBoxAuthenticationError {
      throw EncryptedArchiveBackupException('WRONG_PASSPHRASE');
    }
    return _unpack(Uint8List.fromList(zipBytes));
  }

  static void _requirePassphrase(String passphrase) {
    if (passphrase.trim().length < 8) {
      throw EncryptedArchiveBackupException('PASSPHRASE_TOO_SHORT');
    }
  }

  static Future<List<int>> _deriveKey({
    required String passphrase,
    required List<int> salt,
    required ArchiveBackupKdfProfile profile,
  }) async {
    final algorithm = Argon2id(
      parallelism: profile.parallelism,
      memory: profile.memoryKib,
      iterations: profile.iterations,
      hashLength: 32,
    );
    final secret = await algorithm.deriveKeyFromPassword(
      password: passphrase.trim(),
      nonce: salt,
    );
    return secret.extractBytes();
  }

  static Uint8List _pack({
    required Uint8List databaseBytes,
    required Directory audioDirectory,
  }) {
    final archive = Archive()
      ..addFile(
        ArchiveFile('archive.db', databaseBytes.length, databaseBytes),
      );
    if (audioDirectory.existsSync()) {
      for (final entity in audioDirectory.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('.')) continue;
        final bytes = entity.readAsBytesSync();
        archive.addFile(ArchiveFile('audio/$name', bytes.length, bytes));
      }
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded.isEmpty) {
      throw EncryptedArchiveBackupException('PACK_FAILED');
    }
    return Uint8List.fromList(encoded);
  }

  static ({Uint8List databaseBytes, Map<String, Uint8List> audioFiles}) _unpack(
    Uint8List zipBytes,
  ) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } on Object {
      throw EncryptedArchiveBackupException('CORRUPT_ARCHIVE');
    }
    Uint8List? databaseBytes;
    final audio = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final bytes = Uint8List.fromList(file.content as List<int>);
      if (file.name == 'archive.db') {
        databaseBytes = bytes;
      } else if (file.name.startsWith('audio/')) {
        final name = file.name.substring('audio/'.length);
        if (name.isEmpty || name.contains('..') || name.contains('/')) {
          throw EncryptedArchiveBackupException('CORRUPT_ARCHIVE');
        }
        audio[name] = bytes;
      }
    }
    if (databaseBytes == null || databaseBytes.isEmpty) {
      throw EncryptedArchiveBackupException('CORRUPT_ARCHIVE');
    }
    return (databaseBytes: databaseBytes, audioFiles: audio);
  }

  static Uint8List _encode({
    required ArchiveBackupKdfProfile profile,
    required List<int> salt,
    required List<int> nonce,
    required List<int> mac,
    required List<int> cipherText,
  }) {
    final builder = BytesBuilder()
      ..add(magic)
      ..addByte(formatVersion)
      ..add(_u16(salt.length))
      ..add(salt)
      ..add(_u32(profile.memoryKib))
      ..add(_u32(profile.iterations))
      ..add(_u32(profile.parallelism))
      ..add(_u16(nonce.length))
      ..add(nonce)
      ..add(_u16(mac.length))
      ..add(mac)
      ..add(cipherText);
    return builder.toBytes();
  }

  static ({
    ArchiveBackupKdfProfile profile,
    List<int> salt,
    List<int> nonce,
    List<int> mac,
    List<int> cipherText,
  })
  _decode(Uint8List sealed) {
    final data = ByteData.sublistView(sealed);
    var offset = 0;
    void need(int count) {
      if (offset + count > sealed.length) {
        throw EncryptedArchiveBackupException('CORRUPT_ARCHIVE');
      }
    }

    need(6);
    for (var i = 0; i < magic.length; i++) {
      if (sealed[i] != magic[i]) {
        throw EncryptedArchiveBackupException('CORRUPT_ARCHIVE');
      }
    }
    offset = 4;
    if (sealed[offset] != formatVersion) {
      throw EncryptedArchiveBackupException('CORRUPT_ARCHIVE');
    }
    offset += 1;
    final saltLength = data.getUint16(offset);
    offset += 2;
    need(saltLength);
    final salt = sealed.sublist(offset, offset + saltLength);
    offset += saltLength;
    need(12);
    final memory = data.getUint32(offset);
    final iterations = data.getUint32(offset + 4);
    final parallelism = data.getUint32(offset + 8);
    offset += 12;
    final nonceLength = data.getUint16(offset);
    offset += 2;
    need(nonceLength);
    final nonce = sealed.sublist(offset, offset + nonceLength);
    offset += nonceLength;
    final macLength = data.getUint16(offset);
    offset += 2;
    need(macLength);
    final mac = sealed.sublist(offset, offset + macLength);
    offset += macLength;
    if (offset >= sealed.length) {
      throw EncryptedArchiveBackupException('CORRUPT_ARCHIVE');
    }
    return (
      profile: ArchiveBackupKdfProfile(
        memoryKib: memory,
        iterations: iterations,
        parallelism: parallelism,
      ),
      salt: salt,
      nonce: nonce,
      mac: mac,
      cipherText: sealed.sublist(offset),
    );
  }

  static List<int> _u16(int value) {
    final data = ByteData(2)..setUint16(0, value);
    return data.buffer.asUint8List();
  }

  static List<int> _u32(int value) {
    final data = ByteData(4)..setUint32(0, value);
    return data.buffer.asUint8List();
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
