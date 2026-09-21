import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/live_audio/domain/models/vault_file_metadata.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_pipeline_log.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/local_audio_vault_reader.dart';
import 'package:archiveme_mobile/features/live_audio/live_audio_constants.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

typedef VaultDirectoryResolver = Future<Directory> Function();

/// Append-only encrypted PCM16 LE vault for offline live-voice fallback.
class LocalAudioVault {
  LocalAudioVault({
    PrivateDataEncryptionKeyStore? keyStore,
    AesGcm? algorithm,
    VaultDirectoryResolver? resolveCacheDirectory,
  }) : _keyStore =
           keyStore ??
           SecurePrivateDataEncryptionKeyStore(store: SecureStorageService()),
       _algorithm = algorithm ?? AesGcm.with256bits(),
       _resolveCacheDirectory = resolveCacheDirectory ?? _defaultVaultDirectory;

  static const _magic = [0x41, 0x56, 0x4d, 0x45]; // AVME
  static const _formatVersion = 1;

  final PrivateDataEncryptionKeyStore _keyStore;
  final AesGcm _algorithm;
  final VaultDirectoryResolver _resolveCacheDirectory;

  File? _activeFile;
  RandomAccessFile? _sink;
  SecretKey? _secretKey;
  List<int>? _uploadableRecoverySecretBytes;
  Future<void> _writeChain = Future<void>.value();
  var _isVaultingActive = false;
  var _frameCount = 0;

  bool get isActive => _isVaultingActive;
  int get frameCount => _frameCount;
  File? get activeFile => _activeFile;
  List<int>? get uploadableRecoverySecretBytes =>
      _uploadableRecoverySecretBytes == null
      ? null
      : List<int>.from(_uploadableRecoverySecretBytes!);

  /// Initializes an encrypted emergency local PCM dump for [sessionId].
  Future<void> initializeVault(
    String sessionId, {
    List<int>? recoverySecretKeyBytes,
  }) async {
    if (recoverySecretKeyBytes != null && recoverySecretKeyBytes.length == 32) {
      _secretKey = SecretKey(recoverySecretKeyBytes);
      _uploadableRecoverySecretBytes = List<int>.from(recoverySecretKeyBytes);
    } else {
      _uploadableRecoverySecretBytes = null;
      await _ensureKey();
    }

    final cacheDir = await _resolveCacheDirectory();
    final vaultPath = '${cacheDir.path}/audio_vault_$sessionId.vault.enc';

    _activeFile = File(vaultPath);
    if (await _activeFile!.exists()) {
      await _activeFile!.delete();
    }

    _sink = await _activeFile!.open(mode: FileMode.write);
    await _writeHeader();
    _writeChain = Future<void>.value();
    _frameCount = 0;
    _isVaultingActive = true;

    LiveAudioPipelineLog.offlineVaultInitialized(
      sessionId: sessionId,
      pathSuffix: _activeFile!.uri.pathSegments.last,
    );
  }

  /// Appends a PCM16 frame from the processing pipeline loop.
  void appendFrame(Int16List pcmFrame) {
    if (!_isVaultingActive || _sink == null) {
      return;
    }

    final byteData = pcmFrame.buffer.asUint8List(
      pcmFrame.offsetInBytes,
      pcmFrame.lengthInBytes,
    );
    _enqueueFrame(byteData);
  }

  /// Appends raw PCM16 LE bytes from the capture callback path.
  void appendPcm16LeBytes(List<int> pcmBytes) {
    if (!_isVaultingActive || _sink == null) {
      return;
    }

    final bytes = pcmBytes is Uint8List
        ? pcmBytes
        : Uint8List.fromList(pcmBytes);
    _enqueueFrame(bytes);
  }

  /// Safely closes the vault and returns the encrypted file handle.
  Future<File?> closeVault() async {
    if (!_isVaultingActive) {
      return _activeFile;
    }

    _isVaultingActive = false;
    await _writeChain;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    final file = _activeFile;
    LiveAudioPipelineLog.offlineVaultClosed(
      frameCount: _frameCount,
      pathSuffix: file?.uri.pathSegments.last,
    );
    return file;
  }

  void _enqueueFrame(Uint8List pcmBytes) {
    _writeChain = _writeChain.then((_) => _appendEncryptedFrame(pcmBytes));
  }

  Future<void> _ensureKey() async {
    if (_keyStore is SecurePrivateDataEncryptionKeyStore) {
      await _keyStore.ensureKey();
    } else if (_keyStore is InMemoryPrivateDataEncryptionKeyStore) {
      await _keyStore.ensureKey();
    }

    final keyBytes = await _keyStore.readKeyBytes();
    if (keyBytes == null || keyBytes.isEmpty) {
      throw StateError('Missing encryption key for local audio vault.');
    }
    _secretKey = SecretKey(keyBytes);
  }

  Future<void> _writeHeader() async {
    final header = BytesBuilder(copy: false);
    header.add(_magic);
    header.add([_formatVersion]);
    header.add(_uint32(liveInputSampleRateHz));
    header.add([liveInputNumChannels]);
    await _sink!.writeFrom(header.toBytes());
  }

  Future<void> _appendEncryptedFrame(Uint8List pcmBytes) async {
    final sink = _sink;
    final secretKey = _secretKey;
    if (sink == null || secretKey == null) {
      return;
    }

    try {
      final secretBox = await _algorithm.encrypt(
        pcmBytes,
        secretKey: secretKey,
      );

      final record = BytesBuilder(copy: false);
      record.add(_uint32(secretBox.cipherText.length));
      record.add(secretBox.nonce);
      record.add(secretBox.mac.bytes);
      record.add(secretBox.cipherText);
      await sink.writeFrom(record.toBytes());
      _frameCount++;
    } catch (error, stackTrace) {
      LiveAudioPipelineLog.failure('offline_vault_append', error);
    }
  }

  static Uint8List _uint32(int value) {
    final bytes = Uint8List(4);
    bytes.buffer.asByteData().setUint32(0, value, Endian.little);
    return bytes;
  }

  static Future<Directory> _defaultVaultDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final vaultDir = Directory('${supportDir.path}/live_audio_vaults');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  static List<int>? decodeRecoverySecret(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final bytes = base64Url.decode(encoded);
      return bytes.length == 32 ? bytes : null;
    } catch (_, stackTrace) {
      return null;
    }
  }

  /// Scans the vault directory for encrypted files awaiting recovery upload.
  Future<List<File>> discoverPendingVaults() async {
    final dir = await _resolveCacheDirectory();
    if (!await dir.exists()) {
      return const [];
    }

    final pending = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.vault.enc')) {
        pending.add(entity);
      }
    }
    pending.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return pending;
  }

  /// Parses AVME header + frame index metadata from an on-disk vault file.
  Future<VaultFileMetadata> extractVaultMetadata(File vaultFile) async {
    final sessionId = _sessionIdFromVaultPath(vaultFile.path);
    if (sessionId == null) {
      throw FormatException('Invalid vault filename: ${vaultFile.path}');
    }

    final frameCount = await countEncryptedFrames(vaultFile);
    return VaultFileMetadata(
      sessionId: sessionId,
      frameCount: frameCount,
      durationSeconds: LocalAudioVaultReader.estimateDurationSeconds(
        frameCount: frameCount,
      ),
      serverRecoverable: !sessionId.startsWith('offline_'),
    );
  }

  static String? _sessionIdFromVaultPath(String path) {
    final name = path.split('/').last;
    const prefix = 'audio_vault_';
    const suffix = '.vault.enc';
    if (!name.startsWith(prefix) || !name.endsWith(suffix)) {
      return null;
    }
    return name.substring(prefix.length, name.length - suffix.length);
  }

  static Future<int> countEncryptedFrames(File vaultFile) async {
    final bytes = await vaultFile.readAsBytes();
    if (bytes.length < 10) {
      return 0;
    }

    var offset = 10;
    var frameCount = 0;
    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) {
        break;
      }
      final cipherLength = bytes.buffer.asByteData().getUint32(
        offset,
        Endian.little,
      );
      offset += 4;
      const nonceLength = 12;
      const macLength = 16;
      final frameEnd = offset + nonceLength + macLength + cipherLength;
      if (cipherLength <= 0 || frameEnd > bytes.length) {
        break;
      }
      offset = frameEnd;
      frameCount++;
    }
    return frameCount;
  }
}