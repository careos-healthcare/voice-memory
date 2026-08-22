import 'dart:io';

import 'package:archiveme_mobile/features/voice_capture/audio/audio_capture_diagnostics.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/audio_diag_log.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Debug-only playback and share helpers for investigating capture files.
abstract class AudioDebugActions {
  AudioDebugActions._();

  static AudioPlayer? _player;

  static Future<void> playRecording(String? path) async {
    if (!kDebugMode) return;
    final trimmed = path?.trim() ?? '';
    if (trimmed.isEmpty) {
      AudioDiagLog.playbackFailed(reason: 'missing_path');
      return;
    }
    final file = File(trimmed);
    if (!file.existsSync()) {
      AudioDiagLog.playbackFailed(reason: 'file_missing');
      return;
    }

    try {
      await _player?.stop();
      await _player?.dispose();
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      AudioDiagLog.playbackStarted();
      await _player!.play(DeviceFileSource(trimmed));
    } catch (e, stackTrace) {
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
    final file = File(trimmed);
    final exists = file.existsSync();
    final bytes = exists ? file.lengthSync() : 0;
    AudioDiagLog.share(path: trimmed, exists: exists, bytes: bytes);
    if (!exists) return;

    await Share.shareXFiles([
      XFile(
        trimmed,
        mimeType: AudioCaptureDiagnostics.guessMimeFromPath(trimmed),
        name: file.uri.pathSegments.last,
      ),
    ], subject: 'ArchiveMe capture debug');
  }

  static Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}