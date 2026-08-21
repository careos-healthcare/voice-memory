import 'dart:async';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/capture/vad/onnx_vad_inference.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_segment_writer.dart';
import 'package:archiveme_mobile/features/capture/vad/webrtc_vad_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Real-time VAD stream that segments microphone input into thought chunks.
class VadStreamingService {
  VadStreamingService({
    VadStreamConfig config = const VadStreamConfig(),
    VadInference? inference,
    VadSegmentWriter? segmentWriter,
  }) : _config = config,
       _inference =
           inference ??
           HybridVadInference(
             sampleRateHz: config.sampleRateHz,
             aggressiveness: config.aggressiveness,
           ),
       _segmentWriter = segmentWriter;

  final VadStreamConfig _config;
  final VadInference _inference;
  final VadSegmentWriter? _segmentWriter;

  final StreamController<VadSegmentEvent> _segmentsController =
      StreamController<VadSegmentEvent>.broadcast();

  StreamSubscription<Uint8List>? _pcmSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Future<void> _pcmProcessingChain = Future<void>.value();

  VadStreamState _state = VadStreamState.idle;
  var _speechFrameCount = 0;
  var _silenceFrameCount = 0;
  var _segmentFrameCount = 0;
  var _segmentStartedAt = DateTime.now().toUtc();
  var _preSpeechBufferBytes = 0;
  final List<Uint8List> _preSpeechChunks = [];

  Stream<VadSegmentEvent> get segments => _segmentsController.stream;

  VadStreamState get state => _state;

  List<VoiceThoughtSegment> get completedSegments => List.unmodifiable(
    _completed,
  );

  final List<VoiceThoughtSegment> _completed = [];

  static Future<VadStreamingService> create({
    required String outputDirectory,
    VadStreamConfig config = const VadStreamConfig(),
    bool tryOnnx = true,
  }) async {
    final onnx = tryOnnx ? await OnnxVadInference.tryCreateFromAsset() : null;
    return VadStreamingService(
      config: config,
      inference: HybridVadInference(
        sampleRateHz: config.sampleRateHz,
        onnx: onnx,
        aggressiveness: config.aggressiveness,
      ),
      segmentWriter: VadSegmentWriter(
        outputDirectory: outputDirectory,
        sampleRateHz: config.sampleRateHz,
      ),
    );
  }

  Future<void> startPcmStream(Stream<Uint8List> pcmStream) async {
    await stop();
    _resetCounters();
    _state = VadStreamState.listening;
    await _segmentWriter?.beginSegment();

    _pcmSubscription = pcmStream.listen(
      (chunk) {
        _pcmProcessingChain =
            _pcmProcessingChain.then((_) => _handlePcmChunk(chunk));
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.debug('VAD pcm stream error: $error');
      },
    );
  }

  Future<void> startAmplitudeStream(
    AudioRecorder recorder, {
    Duration interval = const Duration(milliseconds: 50),
  }) async {
    await stop();
    _resetCounters();
    _state = VadStreamState.listening;
    await _segmentWriter?.beginSegment();

    _amplitudeSubscription = recorder
        .onAmplitudeChanged(interval)
        .listen(
          (sample) => unawaited(
            _handleAmplitudeDb(sample.current),
          ),
        );
  }

  Future<List<VoiceThoughtSegment>> stop({
    VadSegmentCloseReason reason = VadSegmentCloseReason.manualStop,
  }) async {
    await _pcmProcessingChain;
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    final closing = await _closeActiveSegment(reason);
    if (closing != null) {
      _emitSegment(closing, reason);
    }

    _state = VadStreamState.idle;
    return List<VoiceThoughtSegment>.from(_completed);
  }

  Future<void> dispose() async {
    await stop();
    await _segmentWriter?.dispose();
    await _segmentsController.close();
  }

  Future<void> _handlePcmChunk(Uint8List chunk) async {
    if (_state == VadStreamState.idle) return;

    final frameBytes = _config.frameSampleCount * 2;
    for (var offset = 0; offset + frameBytes <= chunk.length; offset += frameBytes) {
      final frame = Uint8List.sublistView(chunk, offset, offset + frameBytes);
      final speech = await _classifyPcmFrame(frame);
      await _advanceState(isSpeech: speech, pcmFrame: frame);
    }
  }

  Future<void> _handleAmplitudeDb(double db) async {
    if (_state == VadStreamState.idle) return;
    final speech = WebRtcVadEngine.isSpeechFromDb(
      db,
      aggressiveness: _config.aggressiveness,
    );
    await _advanceState(isSpeech: speech);
  }

  Future<bool> _classifyPcmFrame(Uint8List frame) async {
    final floats = Float32List(frame.length ~/ 2);
    for (var i = 0; i < floats.length; i++) {
      final lo = frame[i * 2];
      final hi = frame[i * 2 + 1];
      var sample = (hi << 8) | lo;
      if (sample > 32767) sample -= 65536;
      floats[i] = sample / 32768.0;
    }
    final result = await _inference.classifyFrame(floats);
    return result ?? WebRtcVadEngine.isSpeechBytes(
      frame,
      sampleRateHz: _config.sampleRateHz,
      aggressiveness: _config.aggressiveness,
    );
  }

  Future<void> _advanceState({
    required bool isSpeech,
    Uint8List? pcmFrame,
  }) async {
    if (isSpeech) {
      if (_state == VadStreamState.listening) {
        _state = VadStreamState.speech;
        _segmentStartedAt = DateTime.now().toUtc();
        _flushPreSpeechBuffer();
      } else if (_state == VadStreamState.hangover) {
        _state = VadStreamState.speech;
      }
      _speechFrameCount += 1;
      _silenceFrameCount = 0;
      _segmentFrameCount += 1;
      if (pcmFrame != null) {
        _segmentWriter?.appendPcm(pcmFrame);
      }
    } else {
      if (_state == VadStreamState.speech) {
        _state = VadStreamState.hangover;
        _silenceFrameCount = 1;
      } else if (_state == VadStreamState.hangover) {
        _silenceFrameCount += 1;
      } else if (pcmFrame != null && _state == VadStreamState.listening) {
        _bufferPreSpeech(pcmFrame);
      }

      if (_state == VadStreamState.hangover &&
          _silenceMs >= _config.silenceHangoverMs &&
          _speechMs >= _config.minSpeechMs) {
        await _finalizeSegment(VadSegmentCloseReason.silenceBoundary);
      }
    }

    if (_segmentMs >= _config.maxSegmentMs && _speechFrameCount > 0) {
      await _finalizeSegment(VadSegmentCloseReason.maxDuration);
    }
  }

  void _bufferPreSpeech(Uint8List frame) {
    _preSpeechChunks.add(Uint8List.fromList(frame));
    _preSpeechBufferBytes += frame.length;
    final maxBytes = (_config.preSpeechPaddingMs / _config.frameDurationMs).ceil() *
        frame.length;
    while (_preSpeechBufferBytes > maxBytes && _preSpeechChunks.isNotEmpty) {
      final removed = _preSpeechChunks.removeAt(0);
      _preSpeechBufferBytes -= removed.length;
    }
  }

  void _flushPreSpeechBuffer() {
    for (final chunk in _preSpeechChunks) {
      _segmentWriter?.appendPcm(chunk);
    }
    _preSpeechChunks.clear();
    _preSpeechBufferBytes = 0;
  }

  Future<void> _finalizeSegment(VadSegmentCloseReason reason) async {
    final segment = await _closeActiveSegment(reason);
    if (segment != null) {
      _emitSegment(segment, reason);
    }
    _resetSegmentCounters();
    _state = VadStreamState.listening;
    await _segmentWriter?.beginSegment();
  }

  Future<VoiceThoughtSegment?> _closeActiveSegment(
    VadSegmentCloseReason reason,
  ) async {
    return _segmentWriter?.finalizeSegment(reason: reason);
  }

  void _emitSegment(VoiceThoughtSegment segment, VadSegmentCloseReason reason) {
    _completed.add(segment);
    if (!_segmentsController.isClosed) {
      _segmentsController.add(
        VadSegmentEvent(segment: segment, closedBecause: reason),
      );
    }
  }

  void _resetCounters() {
    _speechFrameCount = 0;
    _silenceFrameCount = 0;
    _segmentFrameCount = 0;
    _preSpeechChunks.clear();
    _preSpeechBufferBytes = 0;
  }

  void _resetSegmentCounters() {
    _speechFrameCount = 0;
    _silenceFrameCount = 0;
    _segmentFrameCount = 0;
  }

  int get _speechMs => _speechFrameCount * _config.frameDurationMs;
  int get _silenceMs => _silenceFrameCount * _config.frameDurationMs;
  int get _segmentMs => _segmentFrameCount * _config.frameDurationMs;
}
