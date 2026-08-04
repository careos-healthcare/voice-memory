import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../live_audio_constants.dart';
import 'vault_cipher.dart';
import 'vault_key_provider.dart';

/// Reads encrypted offline vault files for local fallback recovery.
class LocalAudioVaultReader {
  LocalAudioVaultReader({
    VaultKeyProvider? vaultKeyProvider,
    VaultCipher? cipher,
  }) : _vaultKeyProvider = vaultKeyProvider ?? VaultKeyProvider(),
       _cipher = cipher ?? VaultCipher();

  static const _magic = [0x41, 0x56, 0x4d, 0x45];
  static const _formatVersion = 1;

  final VaultKeyProvider _vaultKeyProvider;
  final VaultCipher _cipher;

  Future<Uint8List> decryptVaultFile(
    File vaultFile, {
    List<int>? recoverySecretKeyBytes,
  }) async {
    final bytes = await vaultFile.readAsBytes();
    final secretKey = recoverySecretKeyBytes != null
        ? SecretKey(recoverySecretKeyBytes)
        : await _vaultKeyProvider.getOrCreateMasterKey();
    return _decryptBytes(bytes, secretKey);
  }

  /// Decrypts every complete frame in [vaultFile], ignoring a truncated tail.
  ///
  /// Used when the OS terminates the app mid-frame write so prior frames can
  /// still be recovered without failing the whole vault read.
  Future<List<Uint8List>> readValidFrames(
    File vaultFile, {
    List<int>? recoverySecretKeyBytes,
  }) async {
    final bytes = await vaultFile.readAsBytes();
    final secretKey = recoverySecretKeyBytes != null
        ? SecretKey(recoverySecretKeyBytes)
        : await _vaultKeyProvider.getOrCreateMasterKey();
    return _readValidFrames(bytes, secretKey);
  }

  Future<Uint8List> _decryptBytes(Uint8List bytes, SecretKey secretKey) async {
    if (bytes.length < 10 || !_matchesMagic(bytes)) {
      throw FormatException('Invalid vault file.');
    }
    if (bytes[4] != _formatVersion) {
      throw FormatException('Unsupported vault version ${bytes[4]}.');
    }

    var offset = 10;
    final pcm = BytesBuilder(copy: false);
    while (offset < bytes.length) {
      final frameEnd = VaultCipher.vaultFrameRecordLength(bytes, offset);
      if (frameEnd == null) {
        throw FormatException('Corrupt encrypted vault frame.');
      }

      final frame = await _cipher.decryptVaultFrameRecord(
        encryptedRecordBytes: bytes.sublist(offset, frameEnd),
        secretKey: secretKey,
      );
      pcm.add(frame);
      offset = frameEnd;
    }

    final pcmBytes = pcm.toBytes();
    if (pcmBytes.isEmpty) {
      throw FormatException('Vault contains no audio frames.');
    }
    return Uint8List.fromList(pcmBytes);
  }

  Future<List<Uint8List>> _readValidFrames(
    Uint8List bytes,
    SecretKey secretKey,
  ) async {
    if (bytes.length < 10 || !_matchesMagic(bytes)) {
      throw FormatException('Invalid vault file.');
    }
    if (bytes[4] != _formatVersion) {
      throw FormatException('Unsupported vault version ${bytes[4]}.');
    }

    var offset = 10;
    final frames = <Uint8List>[];
    while (offset < bytes.length) {
      final frameEnd = VaultCipher.vaultFrameRecordLength(bytes, offset);
      if (frameEnd == null) {
        break;
      }

      final frame = await _cipher.decryptVaultFrameRecord(
        encryptedRecordBytes: bytes.sublist(offset, frameEnd),
        secretKey: secretKey,
      );
      frames.add(frame);
      offset = frameEnd;
    }

    return frames;
  }

  bool _matchesMagic(Uint8List bytes) {
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  static List<int>? decodeRecoverySecret(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final bytes = base64Url.decode(encoded);
      return bytes.length == 32 ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  static int estimateDurationSeconds({
    required int frameCount,
    int frameDurationMs = liveInputFrameDurationMs,
  }) {
    if (frameCount <= 0) return 1;
    return ((frameCount * frameDurationMs) / 1000).ceil().clamp(1, 999999);
  }
}
