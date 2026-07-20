import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';

import '../live_audio_constants.dart';
import 'live_audio_pipeline_log.dart';
import 'pcm_wav_utils.dart';

typedef LivePcmPlayerFactory = AudioPlayer Function();

/// Plays Gemini Live output PCM and exposes chunks to downstream listeners.
class LivePcm24PlaybackEngine {
  LivePcm24PlaybackEngine({LivePcmPlayerFactory? playerFactory})
      : _playerFactory = playerFactory ?? AudioPlayer.new;

  final LivePcmPlayerFactory _playerFactory;
  final _audioOutputController = StreamController<List<int>>.broadcast();
  final _queueDepthController = StreamController<int>.broadcast();
  final Queue<List<int>> _pendingChunks = Queue<List<int>>();
  AudioPlayer? _player;
  var _playing = false;
  var _disposed = false;
  var _flushGeneration = 0;

  Stream<List<int>> get audioOutputStream => _audioOutputController.stream;

  Stream<int> get queueDepthStream => _queueDepthController.stream;

  int get queueDepth => _pendingChunks.length;

  /// Pending chunks plus the chunk currently playing.
  int get activeQueueDepth => _pendingChunks.length + (_playing ? 1 : 0);

  Future<void> prepare() async {
    if (_disposed) return;
    await _player?.dispose();
    _player = _playerFactory();
    await _player!.setReleaseMode(ReleaseMode.stop);
  }

  void feed(List<int> pcmBytes) {
    if (_disposed || pcmBytes.isEmpty) return;
    if (!_audioOutputController.isClosed) {
      _audioOutputController.add(List<int>.from(pcmBytes));
    }
    _pendingChunks.add(List<int>.from(pcmBytes));
    _emitQueueDepth();
    unawaited(_drainQueue());
  }

  Future<void> stop() async {
    await flush();
  }

  /// Immediately drops queued output audio — used for server barge-in events.
  Future<void> flush() async {
    _flushGeneration++;
    _pendingChunks.clear();
    _playing = false;
    _emitQueueDepth();
    try {
      await _player?.stop();
    } catch (error) {
      LiveAudioPipelineLog.failure('pcm24_playback_flush', error);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pendingChunks.clear();
    await _player?.dispose();
    _player = null;
    await _audioOutputController.close();
    await _queueDepthController.close();
  }

  void _emitQueueDepth() {
    if (_queueDepthController.isClosed) return;
    _queueDepthController.add(activeQueueDepth);
  }

  Future<void> _drainQueue() async {
    if (_playing || _disposed || _player == null) return;
    final generation = _flushGeneration;
    _playing = true;
    _emitQueueDepth();
    try {
      while (_pendingChunks.isNotEmpty &&
          !_disposed &&
          generation == _flushGeneration) {
        final chunk = _pendingChunks.removeFirst();
        _emitQueueDepth();
        final wav = wrapPcm16LeInWav(
          chunk,
          sampleRateHz: liveOutputSampleRateHz,
          numChannels: liveOutputNumChannels,
        );
        await _player!.play(
          BytesSource(wav),
          mode: PlayerMode.lowLatency,
        );
        await _player!.onPlayerComplete.first;
        if (generation != _flushGeneration) break;
      }
    } catch (error) {
      LiveAudioPipelineLog.failure('pcm24_playback', error);
    } finally {
      _playing = false;
      _emitQueueDepth();
      if (_pendingChunks.isNotEmpty &&
          !_disposed &&
          generation == _flushGeneration) {
        unawaited(_drainQueue());
      }
    }
  }
}
