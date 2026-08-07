import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/live_audio/infrastructure/live_audio_pipeline_log.dart';
import '../features/live_audio/infrastructure/pcm_wav_utils.dart';
import '../features/live_audio/live_audio_constants.dart';
import '../core/di/app_provider_container.dart';
import 'pcm_chunk_queue_driver.dart';
import 'playback_types.dart';

export 'playback_types.dart';

typedef AudioPlayerFactory = AudioPlayer Function();

typedef PcmChunkWrapper =
    Uint8List Function(
      List<int> pcmBytes, {
      required int sampleRateHz,
      int numChannels,
    });

/// Injectable configuration for [playbackServiceProvider].
class PlaybackServiceConfig {
  const PlaybackServiceConfig({
    this.testMode = false,
    this.playerFactory = AudioPlayer.new,
    this.livePcmSampleRateHz = liveOutputSampleRateHz,
    this.livePcmNumChannels = liveOutputNumChannels,
    this.wrapPcmChunk = wrapPcm16LeInWav,
  });

  final bool testMode;
  final AudioPlayerFactory playerFactory;
  final int livePcmSampleRateHz;
  final int livePcmNumChannels;
  final PcmChunkWrapper wrapPcmChunk;
}

final playbackServiceConfigProvider = Provider<PlaybackServiceConfig>(
  (ref) => const PlaybackServiceConfig(),
);

/// Shared Riverpod container for playback — set by [PlaybackService.create].
ProviderContainer get playbackProviderContainer => appProviderContainer;

void bindPlaybackProviderContainer(ProviderContainer container) {
  bindAppProviderContainer(container);
}

/// Unified playback boundary for captured files and live PCM output.
class PlaybackService extends Notifier<PlaybackState> {
  static PlaybackService create({
    bool testMode = false,
    AudioPlayerFactory? playerFactory,
    int livePcmSampleRateHz = liveOutputSampleRateHz,
    int livePcmNumChannels = liveOutputNumChannels,
    PcmChunkWrapper? wrapPcmChunk,
  }) {
    final container = ProviderContainer(
      overrides: [
        playbackServiceConfigProvider.overrideWithValue(
          PlaybackServiceConfig(
            testMode: testMode,
            playerFactory: playerFactory ?? AudioPlayer.new,
            livePcmSampleRateHz: livePcmSampleRateHz,
            livePcmNumChannels: livePcmNumChannels,
            wrapPcmChunk: wrapPcmChunk ?? wrapPcm16LeInWav,
          ),
        ),
      ],
    );
    bindPlaybackProviderContainer(container);
    return container.read(playbackServiceProvider.notifier);
  }

  late final PlaybackServiceConfig _config;
  late final PcmChunkQueueDriver _pcmQueue;
  late final bool _testMode;
  final _audioOutputController = StreamController<List<int>>.broadcast();
  final _queueDepthController = StreamController<int>.broadcast();
  AudioPlayer? _player;
  var _pcmDrainInFlight = false;
  var _disposed = false;

  @override
  PlaybackState build() {
    _config = ref.read(playbackServiceConfigProvider);
    _testMode = _config.testMode;
    _pcmQueue = PcmChunkQueueDriver();
    ref.onDispose(_tearDown);
    return const PlaybackState();
  }

  PcmChunkQueueDriver get pcmQueue => _pcmQueue;

  Stream<List<int>> get audioOutputStream => _audioOutputController.stream;

  Stream<int> get queueDepthStream => _queueDepthController.stream;

  int get activeQueueDepth => state.activeQueueDepth;

  Future<void> prepareLiveSession() async {
    if (_disposed) return;
    if (!_testMode) {
      await _ensurePlayer();
    }
    state = state.copyWith(
      phase: PlaybackPhase.preparing,
      sourceKind: PlaybackSourceKind.livePcm,
      clearError: true,
      clearFilePath: true,
      queueDepth: 0,
      activeQueueDepth: 0,
      position: Duration.zero,
    );
    state = state.copyWith(phase: PlaybackPhase.idle);
  }

  void feedLivePcm(List<int> pcmBytes) {
    if (_disposed || pcmBytes.isEmpty) return;
    if (!_audioOutputController.isClosed) {
      _audioOutputController.add(List<int>.from(pcmBytes));
    }
    _pcmQueue.enqueue(pcmBytes);
    _syncQueueState(
      phase: PlaybackPhase.playing,
      sourceKind: PlaybackSourceKind.livePcm,
    );
    if (_testMode) return;
    unawaited(_drainPcmQueue());
  }

  Future<void> flushLivePcm() async {
    _pcmQueue.flush();
    _syncQueueState(
      queueDepth: 0,
      activeQueueDepth: 0,
      phase: state.phase == PlaybackPhase.playing
          ? PlaybackPhase.idle
          : state.phase,
    );
    if (_testMode) return;
    try {
      await _player?.stop();
    } catch (error) {
      LiveAudioPipelineLog.failure('pcm24_playback_flush', error);
    }
  }

  Future<void> playFile(String path) async {
    if (_disposed || _testMode) return;
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      throw PlaybackException('Missing playback file path.');
    }
    final file = File(trimmed);
    if (!file.existsSync()) {
      throw PlaybackException('Playback file missing: $trimmed');
    }

    await flushLivePcm();
    await _ensurePlayer(replace: true);
    state = state.copyWith(
      phase: PlaybackPhase.preparing,
      sourceKind: PlaybackSourceKind.file,
      filePath: trimmed,
      clearError: true,
      queueDepth: 0,
      activeQueueDepth: 0,
      position: Duration.zero,
    );
    try {
      await _player!.play(DeviceFileSource(trimmed));
      state = state.copyWith(phase: PlaybackPhase.playing);
    } catch (error) {
      state = state.copyWith(
        phase: PlaybackPhase.error,
        error: '$error',
      );
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    _pcmQueue.flush();
    _syncQueueState(queueDepth: 0, activeQueueDepth: 0);
    if (!_testMode) {
      try {
        await _player?.stop();
      } catch (error) {
        LiveAudioPipelineLog.failure('playback_stop', error);
      }
    }
    state = const PlaybackState();
  }

  void dispose() {
    unawaited(disposeAsync());
  }

  Future<void> disposeAsync() async {
    if (_disposed) return;
    _disposed = true;
    _pcmQueue.dispose();
    if (!_testMode) {
      await _player?.dispose();
    }
    _player = null;
    await _audioOutputController.close();
    await _queueDepthController.close();
  }

  Future<void> _ensurePlayer({bool replace = false}) async {
    if (_disposed || _testMode) return;
    if (_player != null && !replace) return;
    await _player?.dispose();
    _player = _config.playerFactory();
    await _player!.setReleaseMode(ReleaseMode.stop);
  }

  void _syncQueueState({
    PlaybackPhase? phase,
    PlaybackSourceKind? sourceKind,
    int? queueDepth,
    int? activeQueueDepth,
  }) {
    state = state.copyWith(
      phase: phase ?? state.phase,
      sourceKind: sourceKind ?? state.sourceKind,
      queueDepth: queueDepth ?? _pcmQueue.queueDepth,
      activeQueueDepth: activeQueueDepth ?? _pcmQueue.activeQueueDepth,
    );
    if (!_queueDepthController.isClosed) {
      _queueDepthController.add(state.activeQueueDepth);
    }
  }

  Future<void> _drainPcmQueue() async {
    if (_pcmDrainInFlight || _disposed || _testMode) return;
    await _ensurePlayer();
    final player = _player;
    if (player == null) return;

    final generation = _pcmQueue.flushGeneration;
    _pcmDrainInFlight = true;
    _pcmQueue.setPlaying(true);
    _syncQueueState(phase: PlaybackPhase.playing);

    try {
      while (!_disposed && _pcmQueue.isGenerationCurrent(generation)) {
        final chunk = _pcmQueue.dequeue(generation);
        if (chunk == null) break;
        _syncQueueState();
        final wav = _config.wrapPcmChunk(
          chunk,
          sampleRateHz: _config.livePcmSampleRateHz,
          numChannels: _config.livePcmNumChannels,
        );
        await player.play(BytesSource(wav), mode: PlayerMode.lowLatency);
        await player.onPlayerComplete.first;
        if (!_pcmQueue.isGenerationCurrent(generation)) break;
      }
    } catch (error) {
      LiveAudioPipelineLog.failure('pcm24_playback', error);
      state = state.copyWith(
        phase: PlaybackPhase.error,
        error: '$error',
      );
    } finally {
      _pcmQueue.setPlaying(false);
      _pcmDrainInFlight = false;
      _syncQueueState(
        activeQueueDepth: _pcmQueue.activeQueueDepth,
        queueDepth: _pcmQueue.queueDepth,
        phase: _pcmQueue.queueDepth == 0 && !_pcmDrainInFlight
            ? PlaybackPhase.idle
            : PlaybackPhase.playing,
      );
      if (_pcmQueue.queueDepth > 0 &&
          _pcmQueue.isGenerationCurrent(generation) &&
          !_disposed) {
        unawaited(_drainPcmQueue());
      }
    }
  }

  void _tearDown() {
    dispose();
  }
}

final playbackServiceProvider =
    NotifierProvider<PlaybackService, PlaybackState>(PlaybackService.new);

final playbackQueueDepthProvider = Provider<int>(
  (ref) => ref.watch(playbackServiceProvider).activeQueueDepth,
);
