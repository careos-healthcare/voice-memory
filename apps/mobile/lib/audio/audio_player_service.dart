import 'package:audioplayers/audioplayers.dart';

/// Plays a saved recording from its file path.
class AudioPlayerService {
  AudioPlayerService({Future<void> Function(String audioUrl)? playFile})
    : _playFile = playFile;

  final Future<void> Function(String audioUrl)? _playFile;
  AudioPlayer? _player;

  Future<void> play(String audioUrl) async {
    final path = audioUrl.trim();
    if (path.isEmpty) return;
    final injected = _playFile;
    if (injected != null) {
      await injected(path);
      return;
    }
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.play(DeviceFileSource(path));
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
