import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

/// Best-effort duration probe for watch `.m4a` inbox files.
abstract final class WatchAudioDurationEstimator {
  WatchAudioDurationEstimator._();

  static Future<int> estimateSeconds(File file) async {
    if (!file.existsSync()) return 1;

    final player = AudioPlayer();
    try {
      await player.setSourceDeviceFile(file.path);
      final duration = await player.getDuration();
      final ms = duration?.inMilliseconds ?? 0;
      if (ms > 0) {
        return (ms / 1000).ceil().clamp(1, 999999);
      }
    } catch (_, stackTrace) { // ignore: silent_catch_audit — duration probe fallback heuristic
    } finally {
      await player.dispose();
    }

    try {
      final bytes = await file.length();
      // Rough AAC bitrate fallback (~32 kbps).
      return (bytes / 4000).ceil().clamp(1, 999999);
    } catch (_, stackTrace) { // ignore: silent_catch_audit — file length probe fallback
      return 1;
    }
  }
}