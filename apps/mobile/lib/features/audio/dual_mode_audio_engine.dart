import 'dart:typed_data';

import 'package:archiveme_mobile/features/audio/dual_mode_audio_timing.dart';
import 'package:archiveme_mobile/features/audio/sherpa_dual_mode_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:archiveme_mobile/features/audio/dual_mode_audio_timing.dart';

/// Capture style for one recording session.
enum DualAudioMode {
  /// Offline note: record, then transcribe the whole take with sherpa-onnx.
  passive,

  /// Live reflection: detect turns, reply, and keep the microphone open.
  interactive,
}

extension DualAudioModeLabel on DualAudioMode {
  String get label => switch (this) {
    DualAudioMode.passive => 'Passive Note',
    DualAudioMode.interactive => 'Interactive Reflection',
  };
}

/// One finished speech turn from the interactive loop.
class SpeechTurn {
  const SpeechTurn({required this.transcript, required this.reply});

  final String transcript;
  final String reply;
}

/// Snapshot the recording tile reads.
class DualModeAudioSnapshot {
  const DualModeAudioSnapshot({
    this.mode = DualAudioMode.passive,
    this.recording = false,
    this.playingResponse = false,
    this.partialTranscript = '',
    this.turns = const [],
    this.error,
  });

  final DualAudioMode mode;
  final bool recording;
  final bool playingResponse;
  final String partialTranscript;
  final List<SpeechTurn> turns;
  final String? error;

  String? get lastReply => turns.isEmpty ? null : turns.last.reply;

  DualModeAudioSnapshot copyWith({
    DualAudioMode? mode,
    bool? recording,
    bool? playingResponse,
    String? partialTranscript,
    List<SpeechTurn>? turns,
    String? error,
    bool clearError = false,
  }) {
    return DualModeAudioSnapshot(
      mode: mode ?? this.mode,
      recording: recording ?? this.recording,
      playingResponse: playingResponse ?? this.playingResponse,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      turns: turns ?? this.turns,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Keeps recent audio and closes a turn after a pause longer than 1.2s.
class RollingSpeechBuffer {
  RollingSpeechBuffer({
    this.sampleRateHz = DualModeAudioTiming.sampleRateHz,
    this.pause = DualModeAudioTiming.pause,
    this.rollingWindow = DualModeAudioTiming.rollingWindow,
  });

  final int sampleRateHz;
  final Duration pause;
  final Duration rollingWindow;

  final List<double> rolling = [];
  final List<double> utterance = [];
  Duration trailingSilence = Duration.zero;
  bool heardSpeech = false;

  int get rollingSampleCount => rolling.length;

  Float32List? push({required Float32List frame, required bool speech}) {
    _append(rolling, frame, capped: true);
    final frameDuration = Duration(
      microseconds: frame.isEmpty
          ? 0
          : (frame.length * 1000000 / sampleRateHz).round(),
    );
    if (speech) {
      heardSpeech = true;
      trailingSilence = Duration.zero;
      _append(utterance, frame, capped: false);
      return null;
    }
    if (!heardSpeech) return null;
    _append(utterance, frame, capped: false);
    trailingSilence += frameDuration;
    if (trailingSilence <= pause) return null;
    final completed = Float32List.fromList(utterance);
    utterance.clear();
    heardSpeech = false;
    trailingSilence = Duration.zero;
    return completed;
  }

  void clear() {
    rolling.clear();
    utterance.clear();
    trailingSilence = Duration.zero;
    heardSpeech = false;
  }

  void _append(List<double> target, Float32List frame, {required bool capped}) {
    target.addAll(frame);
    if (!capped) return;
    final cap = sampleRateHz * rollingWindow.inSeconds;
    if (target.length > cap) {
      target.removeRange(0, target.length - cap);
    }
  }
}

/// Local seams for VAD, sherpa transcription, the assistant, and playback.
class DualModeAudioPorts {
  const DualModeAudioPorts({
    required this.isSpeech,
    required this.transcribe,
    required this.reply,
    required this.play,
  });

  /// Offline path. Sherpa models are used when their files are present.
  factory DualModeAudioPorts.offline({
    SherpaDualModeConfig config = const SherpaDualModeConfig(),
    Future<String> Function(String transcript)? reply,
    Future<void> Function(String text)? play,
  }) {
    final binding = bindSherpaDualMode(config);
    return DualModeAudioPorts(
      isSpeech: binding.isSpeech ?? WebRtcSpeechProbe.isSpeech,
      transcribe: binding.transcribe ?? _emptyTranscript,
      reply: reply ?? LocalReflectionAssistant.reply,
      play: play ?? _silentPlayback,
    );
  }

  final bool Function(Float32List samples) isSpeech;
  final Future<String> Function(Float32List samples) transcribe;
  final Future<String> Function(String transcript) reply;
  final Future<void> Function(String text) play;

  static Future<String> _emptyTranscript(Float32List samples) async => '';

  static Future<void> _silentPlayback(String text) async {}
}

/// Short on-device reply. Recording stays open while this text is spoken.
abstract final class LocalReflectionAssistant {
  static Future<String> reply(String transcript) async {
    final words = transcript.trim();
    if (words.isEmpty) return '';
    return 'Heard that. The recording is still open.';
  }
}

final dualModeAudioPortsProvider = Provider<DualModeAudioPorts>(
  (ref) => DualModeAudioPorts.offline(),
);

/// Passive notes and interactive reflection share one recording session.
class DualModeAudioEngine extends AsyncNotifier<DualModeAudioSnapshot> {
  final RollingSpeechBuffer _turns = RollingSpeechBuffer();
  final List<double> _passiveSamples = [];
  Future<void> _work = Future<void>.value();
  var _playing = false;
  Float32List? _queuedTurn;

  @override
  Future<DualModeAudioSnapshot> build() async {
    ref.onDispose(_resetBuffers);
    return const DualModeAudioSnapshot();
  }

  DualModeAudioPorts get _ports => ref.read(dualModeAudioPortsProvider);

  DualModeAudioSnapshot get _current =>
      state.value ?? const DualModeAudioSnapshot();

  Future<void> selectMode(DualAudioMode mode) async {
    if (_current.recording) await stop();
    state = AsyncData(
      _current.copyWith(mode: mode, clearError: true),
    );
  }

  Future<void> start() async {
    _resetBuffers();
    state = AsyncData(
      _current.copyWith(
        recording: true,
        playingResponse: false,
        partialTranscript: '',
        turns: const [],
        clearError: true,
      ),
    );
  }

  Future<void> pushSamples(Float32List samples) {
    final task = _work.then((_) => _pushSamples(samples));
    _work = task;
    return task;
  }

  Future<void> stop() async {
    await _work;
    final snapshot = _current;
    if (snapshot.mode == DualAudioMode.passive && _passiveSamples.isNotEmpty) {
      final transcript = await _ports.transcribe(
        Float32List.fromList(_passiveSamples),
      );
      final turns = transcript.trim().isEmpty
          ? snapshot.turns
          : [
              ...snapshot.turns,
              SpeechTurn(transcript: transcript.trim(), reply: ''),
            ];
      state = AsyncData(
        snapshot.copyWith(
          recording: false,
          playingResponse: false,
          partialTranscript: transcript.trim(),
          turns: turns,
        ),
      );
    } else {
      state = AsyncData(
        snapshot.copyWith(recording: false, playingResponse: false),
      );
    }
    _resetBuffers();
  }

  Future<void> _pushSamples(Float32List samples) async {
    final snapshot = _current;
    if (!snapshot.recording || samples.isEmpty) return;
    if (snapshot.mode == DualAudioMode.passive) {
      _passiveSamples.addAll(samples);
      return;
    }
    final completed = _turns.push(
      frame: samples,
      speech: _ports.isSpeech(samples),
    );
    if (completed == null) return;
    if (_playing) {
      _queuedTurn = completed;
      return;
    }
    await _reflect(completed);
  }

  Future<void> _reflect(Float32List samples) async {
    final transcript = (await _ports.transcribe(samples)).trim();
    if (transcript.isEmpty || !_current.recording) return;
    state = AsyncData(
      _current.copyWith(partialTranscript: transcript, clearError: true),
    );
    final reply = (await _ports.reply(transcript)).trim();
    if (reply.isEmpty || !_current.recording) return;
    _playing = true;
    state = AsyncData(
      _current.copyWith(
        recording: true,
        playingResponse: true,
        partialTranscript: transcript,
      ),
    );
    try {
      await _ports.play(reply);
      if (!_current.recording) return;
      state = AsyncData(
        _current.copyWith(
          recording: true,
          playingResponse: false,
          turns: [
            ..._current.turns,
            SpeechTurn(transcript: transcript, reply: reply),
          ],
        ),
      );
    } on Object {
      state = AsyncData(
        _current.copyWith(
          recording: true,
          playingResponse: false,
          error: 'Could not play that response.',
        ),
      );
    } finally {
      _playing = false;
    }
    final queued = _queuedTurn;
    _queuedTurn = null;
    if (queued != null && _current.recording) {
      await _reflect(queued);
    }
  }

  void _resetBuffers() {
    _turns.clear();
    _passiveSamples.clear();
    _queuedTurn = null;
    _playing = false;
  }
}

final dualModeAudioEngineProvider =
    AsyncNotifierProvider<DualModeAudioEngine, DualModeAudioSnapshot>(
      DualModeAudioEngine.new,
    );
