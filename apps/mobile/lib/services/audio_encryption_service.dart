import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts captured audio at rest with AES-256-GCM.
///
/// The 256-bit key is stored in [FlutterSecureStorage]. Each encrypted file
/// carries its own 12-byte GCM nonce in the `.enc` header — a fresh nonce is
/// generated per [encryptAudioFile] call (GCM requires unique nonces).
class AudioEncryptionService {
  AudioEncryptionService({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _keyStorageKey = 'vm_audio_encryption_aes_key_v1';
  static const _ivStorageKey = 'vm_audio_encryption_aes_iv_v1';
  static const keyByteLength = 32;
  static const ivByteLength = 12;
  static const _encExtension = '.enc';

  final FlutterSecureStorage _secureStorage;
  final Random _secureRandom = Random.secure();

  /// Returns the persisted 256-bit AES key, generating and storing one if absent.
  Future<Uint8List> getOrGenerateKey() async {
    final existing = await _readBytes(_keyStorageKey);
    if (existing != null && existing.length == keyByteLength) {
      return existing;
    }

    final keyBytes = _randomBytes(keyByteLength);
    await _writeBytes(_keyStorageKey, keyBytes);
    return keyBytes;
  }

  /// Returns the persisted 12-byte IV, generating and storing one if absent.
  ///
  /// Used for key-material bootstrap and diagnostics. [encryptAudioFile]
  /// always writes a unique per-file nonce into the `.enc` header.
  Future<Uint8List> getOrGenerateIv() async {
    final existing = await _readBytes(_ivStorageKey);
    if (existing != null && existing.length == ivByteLength) {
      return existing;
    }

    final ivBytes = _randomBytes(ivByteLength);
    await _writeBytes(_ivStorageKey, ivBytes);
    return ivBytes;
  }

  /// Reads [rawAudio], encrypts with AES-GCM, writes `<basename>.enc`, and
  /// securely deletes [rawAudio] after the encrypted file is flushed to disk.
  Future<File> encryptAudioFile(File rawAudio) async {
    if (!await rawAudio.exists()) {
      throw ArgumentError.value(rawAudio.path, 'rawAudio', 'file does not exist');
    }

    final plainBytes = await rawAudio.readAsBytes();
    final keyBytes = await getOrGenerateKey();
    final fileIv = _randomBytes(ivByteLength);

    final encrypter = Encrypter(
      AES(Key(keyBytes), mode: AESMode.gcm),
    );
    final encrypted = encrypter.encryptBytes(
      plainBytes,
      iv: IV(fileIv),
    );

    final outputPath = _encryptedPathFor(rawAudio.path);
    final outputFile = File(outputPath);
    final payload = Uint8List(fileIv.length + encrypted.bytes.length)
      ..setRange(0, fileIv.length, fileIv)
      ..setRange(fileIv.length, fileIv.length + encrypted.bytes.length, encrypted.bytes);

    await outputFile.parent.create(recursive: true);
    final tempFile = File('$outputPath.tmp');
    await tempFile.writeAsBytes(payload, flush: true);
    await tempFile.rename(outputFile.path);

    final written = await outputFile.readAsBytes();
    if (sha256.convert(written) != sha256.convert(payload)) {
      throw StateError(
        'Encrypted audio verification failed before deleting raw file.',
      );
    }

    await _secureDeleteFile(rawAudio);
    return outputFile;
  }

  /// Decrypts an `.enc` audio file and returns the plaintext byte stream.
  Future<Stream<List<int>>> decryptAudioFile(File encryptedAudio) async {
    if (!await encryptedAudio.exists()) {
      throw ArgumentError.value(
        encryptedAudio.path,
        'encryptedAudio',
        'file does not exist',
      );
    }

    final payload = await encryptedAudio.readAsBytes();
    if (payload.length <= ivByteLength) {
      throw const FormatException('Encrypted audio payload is too short.');
    }

    final fileIv = payload.sublist(0, ivByteLength);
    final cipherBytes = payload.sublist(ivByteLength);
    final keyBytes = await getOrGenerateKey();

    final encrypter = Encrypter(
      AES(Key(keyBytes), mode: AESMode.gcm),
    );

    final plainBytes = encrypter.decryptBytes(
      Encrypted(cipherBytes),
      iv: IV(fileIv),
    );

    return Stream<List<int>>.value(plainBytes);
  }

  String _encryptedPathFor(String rawPath) {
    if (rawPath.endsWith(_encExtension)) return rawPath;
    return '$rawPath$_encExtension';
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _secureRandom.nextInt(256)),
    );
  }

  Future<Uint8List?> _readBytes(String storageKey) async {
    final encoded = await _secureStorage.read(key: storageKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(encoded));
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeBytes(String storageKey, Uint8List bytes) async {
    await _secureStorage.write(
      key: storageKey,
      value: base64Encode(bytes),
    );
  }

  Future<void> _secureDeleteFile(File file) async {
    if (!await file.exists()) return;

    try {
      final length = await file.length();
      if (length > 0) {
        final raf = await file.open(mode: FileMode.writeOnly);
        try {
          const chunkSize = 4096;
          final zeroChunk = Uint8List(chunkSize);
          var remaining = length;
          while (remaining > 0) {
            final writeLength = remaining > chunkSize ? chunkSize : remaining;
            await raf.writeFrom(zeroChunk, 0, writeLength);
            remaining -= writeLength;
          }
          await raf.flush();
        } finally {
          await raf.close();
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Best-effort overwrite — still attempt deletion below.
    }

    await file.delete();
  }
}