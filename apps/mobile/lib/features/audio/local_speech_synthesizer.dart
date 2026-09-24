import 'dart:async';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/llm/llm_router.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One synthesized sentence waiting to be played.
class SpeechPcmBuffer {
  const SpeechPcmBuffer({
    required this.pcm,
    required this.sampleRateHz,
    required this.sentence,
  });

  /// Short silence used when a sherpa voice model is not loaded.
  factory SpeechPcmBuffer.fallback(String sentence) {
    final samples = sentence.trim().length.clamp(1, 32);
    return SpeechPcmBuffer(
      pcm: Uint8List(samples * 2),
      sampleRateHz: 16000,
      sentence: sentence.trim(),
    );
  }

  final Uint8List pcm;
  final int sampleRateHz;
  final String sentence;
}

/// Playback state for the local speech queue.
class LocalSpeechState {
  const LocalSpeechState({
    this.speaking = false,
    this.interrupted = false,
    this.queuedCount = 0,
    this.playedSentences = const [],
  });

  final bool speaking;
  final bool interrupted;
  final int queuedCount;
  final List<String> playedSentences;

  LocalSpeechState copyWith({
    bool? speaking,
    bool? interrupted,
    int? queuedCount,
    List<String>? playedSentences,
  }) {
    return LocalSpeechState(
      speaking: speaking ?? this.speaking,
      interrupted: interrupted ?? this.interrupted,
      queuedCount: queuedCount ?? this.queuedCount,
      playedSentences: playedSentences ?? this.playedSentences,
    );
  }
}

/// Turns growing text into sentences that can be spoken immediately.
List<String> takeCompleteSentences(StringBuffer buffer) {
  final text = buffer.toString();
  final ready = <String>[];
  final pattern = RegExp(r'(?:[^.!?]|\.(?=\d))+[.!?](?=\s)');
  var end = 0;
  for (final match in pattern.allMatches(text)) {
    final sentence = match.group(0)!.trim();
    if (sentence.isNotEmpty) ready.add(sentence);
    end = match.end;
  }
  if (end > 0) {
    buffer
      ..clear()
      ..write(text.substring(end));
  }
  return ready;
}

/// Sherpa-onnx offline TTS when a model is loaded, otherwise a short buffer.
class LocalSpeechBindings {
  const LocalSpeechBindings({this.backend, this.synthesizeSentence});

  final OfflineTtsBackend? backend;
  final Future<SpeechPcmBuffer> Function(String sentence)? synthesizeSentence;

  Future<SpeechPcmBuffer> synthesize(String sentence) async {
    final custom = synthesizeSentence;
    if (custom != null) return custom(sentence);
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) return SpeechPcmBuffer.fallback(sentence);
    final model = backend;
    if (model == null || !model.isLoaded) {
      return SpeechPcmBuffer.fallback(trimmed);
    }
    final bytes = <int>[];
    var sampleRateHz = model.sampleRateHz;
    await for (final chunk in model.synthesize(
      OfflineTtsSpeakRequest(text: trimmed),
    )) {
      bytes.addAll(chunk.pcmBytes);
      if (chunk.sampleRateHz > 0) sampleRateHz = chunk.sampleRateHz;
    }
    if (bytes.isEmpty) return SpeechPcmBuffer.fallback(trimmed);
    return SpeechPcmBuffer(
      pcm: Uint8List.fromList(bytes),
      sampleRateHz: sampleRateHz == 0 ? 16000 : sampleRateHz,
      sentence: trimmed,
    );
  }
}

/// Plays one queued buffer. Returning completes that buffer.
typedef SpeechBufferPlayer = Future<void> Function(SpeechPcmBuffer buffer);

final localSpeechBindingsProvider = Provider<LocalSpeechBindings>(
  (ref) => const LocalSpeechBindings(),
);

final speechBufferPlayerProvider = Provider<SpeechBufferPlayer>(
  (ref) => (buffer) async {},
);

/// Streams local speech from [LlmRouter] tokens and queued PCM buffers.
class LocalSpeechSynthesizer extends Notifier<LocalSpeechState> {
  final StringBuffer _pending = StringBuffer();
  final List<SpeechPcmBuffer> _queue = [];
  var _generation = 0;
  var _draining = false;
  var _inFlight = 0;
  var _streamOpen = false;
  Completer<void>? _playGate;
  Completer<void>? _idle;

  @override
  LocalSpeechState build() => const LocalSpeechState();

  /// Speaks [text], starting playback at the first finished sentence.
  Future<void> speakText(String text) {
    return speakTokenStream(LlmRouter.wordTokens(text));
  }

  /// Speaks tokens from [router] without waiting for later sentences.
  Future<void> speakRouted(
    LlmRouter router, {
    required LlmWorkload workload,
    required String prompt,
  }) {
    return speakTokenStream(
      router.streamTokens(workload: workload, prompt: prompt),
    );
  }

  /// Appends [token] to the current utterance, or starts one.
  Future<void> pushToken(String token) async {
    if (_generation == 0 || state.interrupted) {
      _begin();
    }
    await _writeToken(token, _generation);
  }

  /// Speaks any unfinished tail after the token stream ends.
  Future<void> finishUtterance() {
    _streamOpen = false;
    return _flush(_generation);
  }

  Future<void> speakTokenStream(Stream<String> tokens) async {
    final generation = _begin();
    final idle = Completer<void>();
    _idle = idle;
    try {
      await for (final token in tokens) {
        if (generation != _generation) return;
        await _writeToken(token, generation);
      }
      if (generation != _generation) return;
      await _flush(generation);
    } finally {
      if (generation == _generation) {
        _streamOpen = false;
        _maybeIdle(generation);
      }
    }
    if (generation == _generation) await idle.future;
  }

  /// Drops queued audio and stops the buffer that is playing now.
  void interrupt() {
    _releasePlayGate();
    _generation += 1;
    _pending.clear();
    _queue.clear();
    _draining = false;
    _streamOpen = false;
    _finishIdle();
    state = const LocalSpeechState(interrupted: true);
  }

  int _begin() {
    _releasePlayGate();
    _generation += 1;
    _pending.clear();
    _queue.clear();
    _draining = false;
    _inFlight = 0;
    _streamOpen = true;
    state = const LocalSpeechState(speaking: true);
    return _generation;
  }

  Future<void> _writeToken(String token, int generation) async {
    _pending.write(token);
    for (final sentence in takeCompleteSentences(_pending)) {
      if (generation != _generation) return;
      await _enqueue(sentence, generation);
    }
  }

  Future<void> _flush(int generation) async {
    if (generation != _generation) return;
    final rest = _pending.toString().trim();
    _pending.clear();
    if (rest.isNotEmpty) await _enqueue(rest, generation);
    _maybeIdle(generation);
  }

  Future<void> _enqueue(String sentence, int generation) async {
    _inFlight += 1;
    try {
      final buffer = await ref
          .read(localSpeechBindingsProvider)
          .synthesize(sentence);
      if (generation != _generation) return;
      _queue.add(buffer);
      state = state.copyWith(
        speaking: true,
        interrupted: false,
        queuedCount: _queue.length,
      );
      _kick(generation);
    } finally {
      if (generation == _generation) _inFlight -= 1;
    }
  }

  void _kick(int generation) {
    if (_draining) return;
    _draining = true;
    unawaited(_drain(generation));
  }

  Future<void> _drain(int generation) async {
    while (generation == _generation && _queue.isNotEmpty) {
      final buffer = _queue.removeAt(0);
      state = state.copyWith(queuedCount: _queue.length, speaking: true);
      final gate = Completer<void>();
      _playGate = gate;
      final playback = ref
          .read(speechBufferPlayerProvider)(buffer)
          .then<void>((_) {}, onError: (Object _, StackTrace _) {});
      await Future.any<void>([playback, gate.future]);
      if (generation != _generation) return;
      _playGate = null;
      state = state.copyWith(
        playedSentences: [...state.playedSentences, buffer.sentence],
      );
    }
    _draining = false;
    _maybeIdle(generation);
  }

  void _maybeIdle(int generation) {
    if (generation != _generation ||
        _streamOpen ||
        _draining ||
        _inFlight > 0 ||
        _queue.isNotEmpty) {
      return;
    }
    if (_pending.toString().trim().isNotEmpty) return;
    state = state.copyWith(speaking: false, queuedCount: 0);
    _finishIdle();
  }

  void _finishIdle() {
    final idle = _idle;
    _idle = null;
    if (idle != null && !idle.isCompleted) idle.complete();
  }

  void _releasePlayGate() {
    final gate = _playGate;
    _playGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

final localSpeechSynthesizerProvider =
    NotifierProvider<LocalSpeechSynthesizer, LocalSpeechState>(
      LocalSpeechSynthesizer.new,
    );
