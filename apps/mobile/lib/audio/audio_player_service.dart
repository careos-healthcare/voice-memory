import 'package:audioplayers/audioplayers.dart';

/// Plays a saved recording from its file path.
class AudioPlayerService {
  AudioPlayerService({
    Future<void> Function(String audioUrl)? playFile,
    Future<void> Function(Duration position)? seekTo,
  }) : _playFile = playFile,
       _seekTo = seekTo;

  final Future<void> Function(String audioUrl)? _playFile;
  final Future<void> Function(Duration position)? _seekTo;
  AudioPlayer? _player;

  Future<void> play(String audioUrl, {Duration? startAt}) async {
    final path = audioUrl.trim();
    if (path.isEmpty) return;
    final injected = _playFile;
    if (injected != null) {
      await injected(path);
      if (startAt != null) await seek(startAt);
      return;
    }
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.play(DeviceFileSource(path));
    if (startAt != null) await seek(startAt);
  }

  Future<void> seek(Duration position) async {
    final injected = _seekTo;
    if (injected != null) {
      await injected(position);
      return;
    }
    await _player?.seek(position);
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
