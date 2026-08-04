import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../../features/voice_capture/voice_capture_quality.dart';
import '../../storage/app_storage_paths.dart';
import '../../models/journal_entry.dart';
import '../../models/reflection.dart';
import '../../models/sync_status.dart';
import '../../storage/journal_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import 'sensitive_temporary_audio_store.dart';

abstract interface class AudioVaultKeyStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

final class SecureAudioVaultKeyStore implements AudioVaultKeyStore {
  SecureAudioVaultKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  // SecureStorageService prefixes its keys with `vm_flutter_`. Reading the
  // same platform-secure master key directly keeps audio encryption available
  // independently of biometric session state and preserves vault backups.
  static const keyAlias = 'vm_flutter_private_journal_encryption_key_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: keyAlias);

  @override
  Future<void> write(String value) =>
      _storage.write(key: keyAlias, value: value);

  @override
  Future<void> delete() => _storage.delete(key: keyAlias);
}

final class InMemoryAudioVaultKeyStore implements AudioVaultKeyStore {
  InMemoryAudioVaultKeyStore([this.value]);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String next) async => value = next;

  @override
  Future<void> delete() async => value = null;
}

final class PrivateDataAudioVaultKeyStore implements AudioVaultKeyStore {
  PrivateDataAudioVaultKeyStore({PrivateDataEncryptionKeyStore? keyStore})
    : _keyStore = keyStore ?? SecurePrivateDataEncryptionKeyStore();

  final PrivateDataEncryptionKeyStore _keyStore;

  @override
  Future<String?> read() async {
    final bytes = await _keyStore.readKeyBytes();
    return bytes == null ? null : base64Encode(bytes);
  }

  @override
  Future<void> write(String value) =>
      _keyStore.writeKeyBytes(base64Decode(value));

  @override
  Future<void> delete() => _keyStore.deleteKey();
}

final class AudioVaultException implements Exception {
  const AudioVaultException(this.message);
  final String message;

  @override
  String toString() => 'AudioVaultException: $message';
}

final class AudioVaultKeyUnavailable extends AudioVaultException {
  const AudioVaultKeyUnavailable()
    : super('The audio vault key is missing or invalid.');
}

final class AudioVaultLease {
  AudioVaultLease._(this.file, this._release);

  final File file;
  final Future<void> Function(File file) _release;
  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _release(file);
  }
}

final class AudioVaultObject {
  const AudioVaultObject({required this.reference, required this.file});

  final String reference;
  final File file;
}

final class AudioVaultRecoveryResult {
  const AudioVaultRecoveryResult({
    this.recovered = const [],
    this.purged = const [],
  });

  final List<String> recovered;
  final List<String> purged;
}

typedef AudioVaultDirectoryResolver = Future<Directory> Function();

/// Authenticated, chunked AES-256-GCM storage for retained voice recordings.
///
/// Plaintext exists only in the recorder temp file and narrowly scoped
/// decrypted leases. Overwrite-before-delete is best effort on flash and
/// copy-on-write file systems; minimizing plaintext lifetime is the primary
/// protection.
final class AudioVaultService {
  AudioVaultService({
    AudioVaultKeyStore? keyStore,
    AudioVaultDirectoryResolver? vaultDirectory,
    AudioVaultDirectoryResolver? temporaryDirectory,
    SensitiveTemporaryAudioStore? temporaryAudioStore,
    Random? random,
    bool destroyKeyOnWipe = true,
  }) : _keyStore = keyStore ?? SecureAudioVaultKeyStore(),
       _vaultDirectory = vaultDirectory ?? _defaultVaultDirectory,
       // Public named parameters cannot expose private field names.
       // ignore: prefer_initializing_formals
       _temporaryDirectory = temporaryDirectory,
       _temporaryAudioStore =
           temporaryAudioStore ?? SensitiveTemporaryAudioStore.production,
       _random = random ?? Random.secure(),
       // Public named parameters cannot expose a private field name.
       // ignore: prefer_initializing_formals
       _destroyKeyOnWipe = destroyKeyOnWipe;

  static const int chunkBytes = 1024 * 1024;
  static const int maximumAudioBytes = 512 * 1024 * 1024;
  static const int _version = 1;
  static const int _nonceBytes = 12;
  static const int _macBytes = 16;
  static const List<int> _magic = [0x41, 0x4d, 0x41, 0x56]; // AMAV
  static const String referencePrefix = 'av1:';
  static const Set<String> supportedExtensions = {
    'aac',
    'm4a',
    'mp4',
    'wav',
    'caf',
    'ogg',
  };

  final AudioVaultKeyStore _keyStore;
  final AudioVaultDirectoryResolver _vaultDirectory;
  final AudioVaultDirectoryResolver? _temporaryDirectory;
  final SensitiveTemporaryAudioStore _temporaryAudioStore;
  final Random _random;
  final bool _destroyKeyOnWipe;
  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _cachedKey;

  bool isVaultPath(String path) => path.toLowerCase().endsWith('.enc');

  bool isVaultReference(String value) => value.startsWith(referencePrefix);

  Future<AudioVaultObject> sealCapture(String entryId, File sourceFile) async {
    final objectId = _hex(_randomBytes(24));
    final encrypted = await _sealFile(
      sourceFile,
      objectId: objectId,
      entryId: entryId,
    );
    return AudioVaultObject(
      reference: '$referencePrefix${p.basename(encrypted.path)}',
      file: encrypted,
    );
  }

  Future<File> sealRecording(File plaintext, {required String vaultId}) async {
    final sealed = await sealCapture(vaultId, plaintext);
    await secureDeletePlaintext(plaintext);
    return sealed.file;
  }

  Future<File> _sealFile(
    File plaintext, {
    required String objectId,
    required String entryId,
  }) async {
    if (!await plaintext.exists()) {
      throw const AudioVaultException('Plaintext recording does not exist.');
    }
    final length = await plaintext.length();
    if (length <= 0 || length > maximumAudioBytes) {
      throw const AudioVaultException('Plaintext recording size is invalid.');
    }
    final extension = _extensionOf(plaintext.path);
    if (!supportedExtensions.contains(extension)) {
      throw const AudioVaultException('Unsupported recording format.');
    }

    final directory = await _ensureDirectory(await _vaultDirectory());
    final key = await _getOrCreateKey(directory);
    final target = File(p.join(directory.path, '$objectId.$extension.enc'));
    final partial = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.partial',
    );
    final header = _buildHeader(
      extension: extension,
      originalLength: length,
      chunkCount: (length / chunkBytes).ceil(),
      entryId: entryId,
    );

    RandomAccessFile? input;
    RandomAccessFile? output;
    try {
      input = await plaintext.open(mode: FileMode.read);
      output = await partial.open(mode: FileMode.write);
      await output.writeFrom(header);
      var index = 0;
      var remaining = length;
      while (remaining > 0) {
        final clear = await _readExact(input, min(chunkBytes, remaining));
        if (clear.isEmpty) {
          throw const AudioVaultException('Recording ended unexpectedly.');
        }
        final nonce = _randomBytes(_nonceBytes);
        try {
          final box = await _cipher.encrypt(
            clear,
            secretKey: key,
            nonce: nonce,
            aad: _chunkAad(header, index),
          );
          await output.writeFrom(nonce);
          await output.writeFrom(_uint32(box.cipherText.length));
          await output.writeFrom(box.cipherText);
          await output.writeFrom(box.mac.bytes);
        } finally {
          clear.fillRange(0, clear.length, 0);
        }
        remaining -= clear.length;
        index++;
      }
      await output.flush();
      await output.close();
      output = null;
      await input.close();
      input = null;
      final committed = await partial.rename(target.path);
      return committed;
    } on Object {
      await output?.close();
      await input?.close();
      if (await partial.exists()) {
        await secureDeletePlaintext(partial);
      }
      rethrow;
    }
  }

  Future<AudioVaultLease> openDecryptedLease(String vaultReference) async {
    final source = await resolveReference(vaultReference);
    final header = await _readHeader(source);
    final legacyDirectory = _temporaryDirectory;
    final lease = legacyDirectory == null
        ? await _temporaryAudioStore.create(
            ownerId: 'audio-vault-lease',
            extension: header.extension,
          )
        : File(
            p.join(
              (await _ensureDirectory(await legacyDirectory())).path,
              'vm_audio_lease_${_hex(_randomBytes(24))}.${header.extension}',
            ),
          );
    try {
      await _decryptToFile(source, lease, header);
      return AudioVaultLease._(
        lease,
        legacyDirectory == null
            ? (file) => _temporaryAudioStore.delete(
                file: file,
                ownerId: 'audio-vault-lease',
              )
            : secureDeletePlaintext,
      );
    } on Object {
      if (legacyDirectory == null) {
        await _temporaryAudioStore.delete(
          file: lease,
          ownerId: 'audio-vault-lease',
        );
      } else {
        await secureDeletePlaintext(lease);
      }
      rethrow;
    }
  }

  Future<T> withDecryptedFile<T>(
    String vaultReference,
    Future<T> Function(File plaintext) operation,
  ) async {
    final lease = await openDecryptedLease(vaultReference);
    try {
      return await operation(lease.file);
    } finally {
      await lease.close();
    }
  }

  Future<Uint8List> readPlaintextBytes(String vaultReference) async {
    return withDecryptedFile(vaultReference, (file) async {
      return Uint8List.fromList(await file.readAsBytes());
    });
  }

  Future<File> resolveReference(String vaultReference) async {
    if (!isVaultReference(vaultReference)) {
      return File(vaultReference);
    }
    final fileName = vaultReference.substring(referencePrefix.length);
    if (fileName.isEmpty ||
        p.basename(fileName) != fileName ||
        fileName.contains(Platform.pathSeparator) ||
        !isVaultPath(fileName)) {
      throw const AudioVaultException('Audio vault reference is invalid.');
    }
    final directory = await _ensureDirectory(await _vaultDirectory());
    return File(p.join(directory.path, fileName));
  }

  Future<bool> exists(String vaultReference) async =>
      (await resolveReference(vaultReference)).exists();

  Future<void> delete(String vaultReference) async {
    final file = await resolveReference(vaultReference);
    if (!await file.exists()) return;
    await file.delete();
  }

  Future<void> deleteVaultFile(String encryptedPath) => delete(encryptedPath);

  Future<void> destroyKey() async {
    _cachedKey = null;
    await _keyStore.delete();
  }

  Future<void> wipeVaultAndDestroyKey() async {
    final directory = await _vaultDirectory();
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File &&
            (isVaultPath(entity.path) || entity.path.endsWith('.partial'))) {
          await entity.delete();
        }
      }
    }
    if (_destroyKeyOnWipe) await destroyKey();
  }

  Future<AudioVaultObject> migrateLegacyPath(
    String entryId,
    String legacyPath,
  ) {
    return sealCapture(entryId, File(legacyPath));
  }

  Future<AudioVaultObject> adoptLegacyEncryptedPath(String legacyPath) async {
    final source = File(legacyPath);
    await _readHeader(source);
    final directory = await _ensureDirectory(await _vaultDirectory());
    if (p.equals(p.dirname(source.path), directory.path)) {
      return AudioVaultObject(
        reference: '$referencePrefix${p.basename(source.path)}',
        file: source,
      );
    }
    final extension = p.basename(source.path).split('.').reversed.skip(1).first;
    final target = File(
      p.join(directory.path, '${_hex(_randomBytes(24))}.$extension.enc'),
    );
    final partial = File('${target.path}.partial');
    try {
      await source.copy(partial.path);
      final committed = await partial.rename(target.path);
      return AudioVaultObject(
        reference: '$referencePrefix${p.basename(committed.path)}',
        file: committed,
      );
    } on Object {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<void> recoverInterruptedOperations() async {
    await purgeAbandonedPartials();
    await purgeWorkingFiles();
  }

  Future<void> purgeWorkingFiles({Directory? temporaryDirectory}) async {
    final resolver = _temporaryDirectory;
    if (temporaryDirectory == null && resolver == null) {
      await _temporaryAudioStore.purgePending();
      return;
    }
    final temp = temporaryDirectory ?? await resolver!();
    if (!await temp.exists()) return;
    await for (final entity in temp.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('vm_audio_lease_') ||
          (name.startsWith('vm_rec_') &&
              (name.contains('.working') || name.endsWith('.tmp')))) {
        await secureDeletePlaintext(entity);
      }
    }
  }

  Future<void> purgeUnreferencedObjects(Set<String> references) async {
    final referencedNames = references
        .where(isVaultReference)
        .map((reference) => reference.substring(referencePrefix.length))
        .toSet();
    final directory = await _vaultDirectory();
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is File &&
          isVaultPath(entity.path) &&
          !referencedNames.contains(p.basename(entity.path))) {
        await entity.delete();
      }
    }
  }

  Future<AudioVaultRecoveryResult> recoverOrphanRecordings({
    Directory? temporaryDirectory,
    Set<String> referencedPaths = const {},
    Future<void> Function(File source, String vaultReference)? commitRecovered,
  }) async {
    final resolver = _temporaryDirectory;
    if (temporaryDirectory == null && resolver == null) {
      return _recoverManagedOrphans(commitRecovered: commitRecovered);
    }
    final temp = temporaryDirectory ?? await resolver!();
    if (!await temp.exists()) return const AudioVaultRecoveryResult();
    final recovered = <String>[];
    final purged = <String>[];
    await for (final entity in temp.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('vm_audio_lease_') || name.endsWith('.partial')) {
        await secureDeletePlaintext(entity);
        purged.add(entity.path);
        continue;
      }
      if (!name.startsWith('vm_rec_') ||
          isVaultPath(entity.path) ||
          referencedPaths.contains(entity.path)) {
        continue;
      }
      final valid = await _isValidRecoveryCandidate(entity);
      if (!valid) {
        await secureDeletePlaintext(entity);
        purged.add(entity.path);
        continue;
      }
      try {
        final sealed = await sealCapture(
          'recovered_${DateTime.now().microsecondsSinceEpoch}',
          entity,
        );
        if (commitRecovered != null) {
          try {
            await commitRecovered(entity, sealed.reference);
            await secureDeletePlaintext(entity);
          } on Object {
            // Keep both objects until the journal can be checked on startup.
            // Unreferenced ciphertext is purged before the next recovery pass.
            rethrow;
          }
        }
        recovered.add(sealed.reference);
      } on Object {
        // Keep a valid source for the next startup if encryption is unavailable.
      }
    }
    return AudioVaultRecoveryResult(
      recovered: List.unmodifiable(recovered),
      purged: List.unmodifiable(purged),
    );
  }

  Future<AudioVaultRecoveryResult> _recoverManagedOrphans({
    Future<void> Function(File source, String vaultReference)? commitRecovered,
  }) async {
    final recovered = <String>[];
    final purged = <String>[];
    for (final ownerId in const ['voice-capture', 'legacy-recovery']) {
      final items = await _temporaryAudioStore.list(
        ownerId: ownerId,
        recoverableOnly: true,
      );
      for (final item in items) {
        if (!await _isValidRecoveryCandidate(item.file)) {
          await _temporaryAudioStore.delete(file: item.file, ownerId: ownerId);
          purged.add(item.id);
          continue;
        }
        AudioVaultObject? sealed;
        try {
          sealed = await sealCapture('local-recovery-${item.id}', item.file);
          if (commitRecovered != null) {
            await commitRecovered(item.file, sealed.reference);
          }
          await _temporaryAudioStore.markEncryptionComplete(
            file: item.file,
            ownerId: ownerId,
          );
          recovered.add(sealed.reference);
        } on Object {
          if (sealed != null) await delete(sealed.reference);
          // Keep bounded plaintext for another local-only recovery attempt.
        }
      }
    }
    return AudioVaultRecoveryResult(
      recovered: List.unmodifiable(recovered),
      purged: List.unmodifiable(purged),
    );
  }

  Future<void> purgeAbandonedPartials() async {
    final directory = await _vaultDirectory();
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.partial')) {
        await secureDeletePlaintext(entity);
      }
    }
  }

  Future<void> secureDeletePlaintext(File file) async {
    if (!await file.exists()) return;
    RandomAccessFile? handle;
    try {
      final length = await file.length();
      handle = await file.open(mode: FileMode.write);
      final zeros = Uint8List(min(chunkBytes, max(1, length)));
      var remaining = length;
      while (remaining > 0) {
        final count = min(zeros.length, remaining);
        await handle.writeFrom(zeros, 0, count);
        remaining -= count;
      }
      await handle.flush();
      await handle.truncate(0);
      await handle.close();
      handle = null;
    } on Object {
      await handle?.close();
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _decryptToFile(
    File source,
    File destination,
    _AudioVaultHeader header,
  ) async {
    final vaultDirectory = await _ensureDirectory(await _vaultDirectory());
    final key = await _readExistingKey(vaultDirectory);
    final input = await source.open(mode: FileMode.read);
    final output = await destination.open(mode: FileMode.write);
    var written = 0;
    try {
      await input.setPosition(header.bytes.length);
      for (var index = 0; index < header.chunkCount; index++) {
        final nonce = await _readExact(input, _nonceBytes);
        final lengthBytes = await _readExact(input, 4);
        final cipherLength = _readUint32(lengthBytes);
        if (cipherLength <= 0 || cipherLength > chunkBytes) {
          throw const AudioVaultException('Encrypted chunk length is invalid.');
        }
        final cipherText = await _readExact(input, cipherLength);
        final mac = await _readExact(input, _macBytes);
        final clear = await _cipher.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
          secretKey: key,
          aad: _chunkAad(header.bytes, index),
        );
        try {
          await output.writeFrom(clear);
          written += clear.length;
        } finally {
          clear.fillRange(0, clear.length, 0);
        }
      }
      if (written != header.originalLength ||
          await input.position() != await input.length()) {
        throw const AudioVaultException('Encrypted recording size mismatch.');
      }
      await output.flush();
    } finally {
      await output.close();
      await input.close();
    }
  }

  Future<_AudioVaultHeader> _readHeader(File source) async {
    if (!await source.exists()) {
      throw const AudioVaultException('Encrypted recording does not exist.');
    }
    final input = await source.open(mode: FileMode.read);
    try {
      final prefix = await input.read(5);
      if (prefix.length != 5 ||
          !_matches(prefix, _magic) ||
          prefix[4] != _version) {
        throw const AudioVaultException(
          'Encrypted recording header is invalid.',
        );
      }
      final extensionLengthBytes = await input.read(1);
      if (extensionLengthBytes.length != 1 ||
          extensionLengthBytes.single <= 0 ||
          extensionLengthBytes.single > 12) {
        throw const AudioVaultException(
          'Encrypted recording format is invalid.',
        );
      }
      final extensionBytes = await input.read(extensionLengthBytes.single);
      final lengthBytes = await input.read(8);
      final countBytes = await input.read(4);
      final vaultId = await input.read(16);
      if (extensionBytes.length != extensionLengthBytes.single ||
          lengthBytes.length != 8 ||
          countBytes.length != 4 ||
          vaultId.length != 16) {
        throw const AudioVaultException('Encrypted recording is truncated.');
      }
      final extension = utf8.decode(extensionBytes);
      final originalLength = _readUint64(lengthBytes);
      final chunkCount = _readUint32(countBytes);
      if (!supportedExtensions.contains(extension) ||
          originalLength <= 0 ||
          originalLength > maximumAudioBytes ||
          chunkCount != (originalLength / chunkBytes).ceil()) {
        throw const AudioVaultException(
          'Encrypted recording metadata is invalid.',
        );
      }
      return _AudioVaultHeader(
        extension: extension,
        originalLength: originalLength,
        chunkCount: chunkCount,
        bytes: Uint8List.fromList([
          ...prefix,
          ...extensionLengthBytes,
          ...extensionBytes,
          ...lengthBytes,
          ...countBytes,
          ...vaultId,
        ]),
      );
    } finally {
      await input.close();
    }
  }

  Future<SecretKey> _getOrCreateKey(Directory vaultDirectory) async {
    if (_cachedKey != null) return _cachedKey!;
    final encoded = await _keyStore.read();
    if (encoded != null && encoded.isNotEmpty) {
      return _cacheDecodedKey(encoded);
    }
    if (await _containsVaultFiles(vaultDirectory)) {
      throw const AudioVaultKeyUnavailable();
    }
    final key = await _cipher.newSecretKey();
    final bytes = Uint8List.fromList(await key.extractBytes());
    try {
      await _keyStore.write(base64Encode(bytes));
      _cachedKey = key;
      return key;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<SecretKey> _readExistingKey(Directory vaultDirectory) async {
    if (_cachedKey != null) return _cachedKey!;
    final encoded = await _keyStore.read();
    if (encoded == null || encoded.isEmpty) {
      throw const AudioVaultKeyUnavailable();
    }
    return _cacheDecodedKey(encoded);
  }

  SecretKey _cacheDecodedKey(String encoded) {
    try {
      final bytes = base64Decode(encoded);
      if (bytes.length != 32) throw const AudioVaultKeyUnavailable();
      _cachedKey = SecretKey(bytes);
      return _cachedKey!;
    } on FormatException {
      throw const AudioVaultKeyUnavailable();
    }
  }

  Uint8List _buildHeader({
    required String extension,
    required int originalLength,
    required int chunkCount,
    required String entryId,
  }) {
    final extensionBytes = utf8.encode(extension);
    return Uint8List.fromList([
      ..._magic,
      _version,
      extensionBytes.length,
      ...extensionBytes,
      ..._uint64(originalLength),
      ..._uint32(chunkCount),
      ..._entryBinding(entryId),
    ]);
  }

  static Uint8List _entryBinding(String entryId) {
    return Uint8List.fromList(
      hashes.sha256.convert(utf8.encode(entryId)).bytes.take(16).toList(),
    );
  }

  Future<bool> _isValidRecoveryCandidate(File file) async {
    try {
      final length = await file.length();
      final extension = _extensionOf(file.path);
      if (length < VoiceCaptureQuality.minAudioBytes ||
          length > maximumAudioBytes ||
          !supportedExtensions.contains(extension)) {
        return false;
      }
      final handle = await file.open(mode: FileMode.read);
      final prefix = await handle.read(16);
      await handle.close();
      return switch (extension) {
        'wav' =>
          prefix.length >= 12 &&
              ascii.decode(prefix.sublist(0, 4), allowInvalid: true) ==
                  'RIFF' &&
              ascii.decode(prefix.sublist(8, 12), allowInvalid: true) == 'WAVE',
        'm4a' || 'mp4' =>
          prefix.length >= 8 &&
              ascii.decode(prefix.sublist(4, 8), allowInvalid: true) == 'ftyp',
        'aac' =>
          prefix.length >= 2 && prefix[0] == 0xff && (prefix[1] & 0xf6) == 0xf0,
        'caf' =>
          prefix.length >= 4 &&
              ascii.decode(prefix.sublist(0, 4), allowInvalid: true) == 'caff',
        'ogg' =>
          prefix.length >= 4 &&
              ascii.decode(prefix.sublist(0, 4), allowInvalid: true) == 'OggS',
        _ => false,
      };
    } on Object {
      return false;
    }
  }

  Future<bool> _containsVaultFiles(Directory directory) async {
    if (!await directory.exists()) return false;
    await for (final entity in directory.list()) {
      if (entity is File && isVaultPath(entity.path)) return true;
    }
    return false;
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  static Future<Uint8List> _readExact(
    RandomAccessFile input,
    int length,
  ) async {
    final output = BytesBuilder(copy: false);
    var remaining = length;
    while (remaining > 0) {
      final part = await input.read(remaining);
      if (part.isEmpty) {
        throw const AudioVaultException('Recording ended unexpectedly.');
      }
      output.add(part);
      remaining -= part.length;
    }
    return output.toBytes();
  }

  Uint8List _chunkAad(Uint8List header, int index) =>
      Uint8List.fromList([...header, ..._uint32(index)]);

  static String _extensionOf(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  static Uint8List _uint32(int value) {
    final bytes = Uint8List(4);
    bytes.buffer.asByteData().setUint32(0, value, Endian.big);
    return bytes;
  }

  static Uint8List _uint64(int value) {
    final bytes = Uint8List(8);
    bytes.buffer.asByteData().setUint64(0, value, Endian.big);
    return bytes;
  }

  static int _readUint32(List<int> bytes) =>
      Uint8List.fromList(bytes).buffer.asByteData().getUint32(0, Endian.big);

  static int _readUint64(List<int> bytes) =>
      Uint8List.fromList(bytes).buffer.asByteData().getUint64(0, Endian.big);

  static bool _matches(List<int> bytes, List<int> expected) {
    if (bytes.length < expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (bytes[i] != expected[i]) return false;
    }
    return true;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  static Future<Directory> _ensureDirectory(Directory directory) async {
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<Directory> _defaultVaultDirectory() async {
    final support = await AppStoragePaths.applicationSupportDirectory();
    return Directory(p.join(support.path, 'encrypted_audio_vault'));
  }
}

final class _AudioVaultHeader {
  const _AudioVaultHeader({
    required this.extension,
    required this.originalLength,
    required this.chunkCount,
    required this.bytes,
  });

  final String extension;
  final int originalLength;
  final int chunkCount;
  final Uint8List bytes;
}

final class AudioVaultJournalMigrator {
  const AudioVaultJournalMigrator(this.vault);

  final AudioVaultService vault;

  Future<void> migrateAndRecover({
    required JournalStore journalStore,
    Directory? temporaryDirectory,
  }) async {
    await vault.recoverInterruptedOperations();
    final entries = await journalStore.loadAll();
    for (final entry in entries) {
      final existingReference = entry.localAudioVaultRef?.trim();
      final path = entry.localAudioPath?.trim();
      if (existingReference != null &&
          existingReference.isNotEmpty &&
          vault.isVaultReference(existingReference) &&
          await vault.exists(existingReference)) {
        if (path != null && path.isNotEmpty) {
          final legacy = File(path);
          try {
            await journalStore.save(
              entry.copyWith(clearLocalAudioPath: true),
              first25Source: 'audio_vault_reference_normalized',
            );
            final vaultFile = await vault.resolveReference(existingReference);
            if (await legacy.exists() &&
                !p.equals(legacy.path, vaultFile.path)) {
              if (vault.isVaultPath(path)) {
                await legacy.delete();
              } else {
                await vault.secureDeletePlaintext(legacy);
              }
            }
          } on Object catch (error) {
            developer.log(
              'Duplicate legacy audio cleanup deferred (${error.runtimeType}).',
              name: 'ArchiveMe.audioVault',
            );
          }
        }
        continue;
      }
      if (path == null || path.isEmpty) continue;
      final plaintext = File(path);
      if (!await plaintext.exists()) {
        // Keep the explicit legacy reference. A later restore may make it
        // recoverable; startup migration must not silently discard it.
        developer.log(
          'Legacy audio unavailable; migration deferred.',
          name: 'ArchiveMe.audioVault',
        );
        continue;
      }
      AudioVaultObject? sealed;
      try {
        sealed = vault.isVaultPath(path)
            ? await vault.adoptLegacyEncryptedPath(path)
            : await vault.migrateLegacyPath(entry.id, path);
        await journalStore.save(
          entry.copyWith(
            localAudioVaultRef: sealed.reference,
            clearLocalAudioPath: true,
          ),
          first25Source: 'audio_vault_legacy_migration',
        );
        if (!p.equals(plaintext.path, sealed.file.path)) {
          if (vault.isVaultPath(path)) {
            await plaintext.delete();
          } else {
            await vault.secureDeletePlaintext(plaintext);
          }
        }
      } on AudioVaultKeyUnavailable {
        rethrow;
      } on Object catch (error) {
        final persisted = await journalStore.getById(entry.id);
        if (sealed != null &&
            persisted?.localAudioVaultRef == sealed.reference) {
          if (!p.equals(plaintext.path, sealed.file.path)) {
            if (vault.isVaultPath(path)) {
              await plaintext.delete();
            } else {
              await vault.secureDeletePlaintext(plaintext);
            }
          }
        } else if (sealed != null) {
          await vault.delete(sealed.reference);
        }
        // Preserve the source unless the durable journal already committed.
        developer.log(
          'Legacy audio migration deferred (${error.runtimeType}).',
          name: 'ArchiveMe.audioVault',
        );
      }
    }
    final currentEntries = await journalStore.loadAll();
    final vaultReferences = currentEntries
        .map((entry) => entry.localAudioVaultRef?.trim())
        .whereType<String>()
        .where((reference) => reference.isNotEmpty)
        .toSet();
    await vault.purgeUnreferencedObjects(vaultReferences);
    final legacyPaths = currentEntries
        .map((entry) => entry.localAudioPath?.trim())
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet();
    await vault.recoverOrphanRecordings(
      temporaryDirectory: temporaryDirectory,
      referencedPaths: legacyPaths,
      commitRecovered: (source, reference) async {
        final token = p
            .basename(
              reference.substring(AudioVaultService.referencePrefix.length),
            )
            .split('.')
            .first;
        final recoveredId = 'recovered-audio-$token';
        final existing = await journalStore.getById(recoveredId);
        if (existing != null) return;
        final modifiedAt = (await source.stat()).modified.toUtc();
        try {
          await journalStore.save(
            JournalEntry(
              id: recoveredId,
              createdAt: modifiedAt,
              transcript: '[draft] Recovered recording — transcription pending',
              durationSeconds: 0,
              reflection: const Reflection(
                mood: 'neutral',
                emotionalIntensity: 0,
                recurringThemes: [],
                exactLanguagePattern: '',
                concreteObservation: '',
                repeatedSignal: '',
              ),
              syncStatus: SyncStatus.localOnly,
              localAudioVaultRef: reference,
            ),
            first25Source: 'audio_vault_orphan_recovery',
          );
        } on Object {
          final persisted = await journalStore.getById(recoveredId);
          if (persisted?.localAudioVaultRef == reference) return;
          rethrow;
        }
      },
    );
  }
}
