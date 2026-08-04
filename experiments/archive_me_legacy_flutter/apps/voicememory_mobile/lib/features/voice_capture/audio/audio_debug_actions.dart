import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'audio_capture_diagnostics.dart';
import 'audio_diag_log.dart';
import '../../../services/app_services.dart';
import '../../../services/privacy/audio_vault_service.dart';

/// Debug-only playback and share helpers for investigating capture files.
abstract class AudioDebugActions {
  AudioDebugActions._();

  static AudioPlayer? _player;
  static AudioVaultLease? _lease;

  static Future<void> playRecording(String? path) async {
    if (!kDebugMode) return;
    final trimmed = path?.trim() ?? '';
    if (trimmed.isEmpty) {
      AudioDiagLog.playbackFailed(reason: 'missing_path');
      return;
    }
    final vault = AppServices.isInitialized
        ? AppServices.instance.journalAudioVault
        : null;
    final isVaultAudio =
        trimmed.startsWith(AudioVaultService.referencePrefix) ||
        trimmed.endsWith('.enc');
    final file = isVaultAudio && vault != null
        ? await vault.resolveReference(trimmed)
        : File(trimmed);
    if (!await file.exists()) {
      AudioDiagLog.playbackFailed(reason: 'file_missing');
      return;
    }

    try {
      await _player?.stop();
      await _player?.dispose();
      await _releaseLease();
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      AudioDiagLog.playbackStarted();
      var playablePath = trimmed;
      if (isVaultAudio) {
        if (vault == null) throw StateError('Audio vault unavailable.');
        _lease = await vault.openDecryptedLease(trimmed);
        playablePath = _lease!.file.path;
        _player!.onPlayerComplete.first.then((_) => _releaseLease());
      }
      await _player!.play(DeviceFileSource(playablePath));
    } catch (e) {
      await _releaseLease();
      AudioDiagLog.playbackFailed(reason: e.toString());
    }
  }

  static Future<void> shareRecording(String? path) async {
    if (!kDebugMode) return;
    final trimmed = path?.trim() ?? '';
    if (trimmed.isEmpty) {
      AudioDiagLog.share(path: trimmed, exists: false, bytes: 0);
      return;
    }
    final vault = AppServices.isInitialized
        ? AppServices.instance.journalAudioVault
        : null;
    final isVaultAudio =
        trimmed.startsWith(AudioVaultService.referencePrefix) ||
        trimmed.endsWith('.enc');
    final file = isVaultAudio && vault != null
        ? await vault.resolveReference(trimmed)
        : File(trimmed);
    final exists = await file.exists();
    final bytes = exists ? await file.length() : 0;
    AudioDiagLog.share(path: trimmed, exists: exists, bytes: bytes);
    if (!exists) return;

    if (isVaultAudio && vault != null) {
      await vault.withDecryptedFile(trimmed, (plaintext) async {
        await _shareFile(plaintext);
      });
      return;
    }
    if (isVaultAudio) {
      AudioDiagLog.share(path: trimmed, exists: true, bytes: bytes);
      return;
    }
    await _shareFile(file);
  }

  static Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    await _releaseLease();
  }

  static Future<void> _shareFile(File file) => Share.shareXFiles([
    XFile(
      file.path,
      mimeType: AudioCaptureDiagnostics.guessMimeFromPath(file.path),
      name: file.uri.pathSegments.last,
    ),
  ], subject: 'ArchiveMe capture debug');

  static Future<void> _releaseLease() async {
    final lease = _lease;
    _lease = null;
    await lease?.close();
  }
}
