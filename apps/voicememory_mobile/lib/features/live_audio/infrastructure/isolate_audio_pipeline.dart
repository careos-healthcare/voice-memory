import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../live_audio_constants.dart';
import 'live_audio_pipeline_log.dart';

class PipelineConfig {
  const PipelineConfig({
    required this.inputSampleRate,
    this.targetSampleRate = liveInputSampleRateHz,
    this.frameDurationMs = 20,
    this.maxRingBufferSize = 50,
  });

  final int inputSampleRate;
  final int targetSampleRate;
  final int frameDurationMs;
  final int maxRingBufferSize;

  int get targetSamplesPerFrame =>
      (targetSampleRate * frameDurationMs) ~/ 1000;
}

/// Commands sent from the main thread to the background isolate.
enum PipelineCommand { init, process, stop }

class IsolatePipelineMessage {
  const IsolatePipelineMessage({
    required this.command,
    this.config,
    this.payload,
  });

  final PipelineCommand command;
  final PipelineConfig? config;
  final Int16List? payload;
}

class AudioPipelineProcessResult {
  const AudioPipelineProcessResult({
    required this.frames,
    this.droppedOldestFrame = false,
  });

  final List<Int16List> frames;
  final bool droppedOldestFrame;
}

/// Pure PCM resample + frame assembly logic — unit-testable without an isolate.
class AudioPipelineProcessor {
  AudioPipelineProcessor(this.config);

  final PipelineConfig config;
  List<int> _sampleAccumulator = <int>[];

  AudioPipelineProcessResult processRawBuffer(Int16List rawBuffer) {
    final resampled = resampleLinearInt16(
      rawBuffer,
      config.inputSampleRate,
      config.targetSampleRate,
    );

    _sampleAccumulator.addAll(resampled);
    final sizeTarget = config.targetSamplesPerFrame;
    final frames = <Int16List>[];
    var droppedOldestFrame = false;

    while (_sampleAccumulator.length >= sizeTarget) {
      frames.add(
        Int16List.fromList(_sampleAccumulator.sublist(0, sizeTarget)),
      );
      _sampleAccumulator = _sampleAccumulator.sublist(sizeTarget);

      if (frames.length > config.maxRingBufferSize) {
        frames.removeAt(0);
        droppedOldestFrame = true;
      }
    }

    return AudioPipelineProcessResult(
      frames: frames,
      droppedOldestFrame: droppedOldestFrame,
    );
  }
}

/// Linear PCM16 resampling for hardware buffers that arrive off-rate.
@visibleForTesting
Int16List resampleLinearInt16(Int16List input, int fromRate, int toRate) {
  if (fromRate == toRate) {
    return input;
  }

  final ratio = fromRate / toRate;
  final outputLength = (input.length / ratio).floor();
  final output = Int16List(outputLength);

  for (var i = 0; i < outputLength; i++) {
    final srcIndex = i * ratio;
    final index = srcIndex.floor();
    final fraction = srcIndex - index;

    if (index + 1 < input.length) {
      output[i] =
          ((1 - fraction) * input[index] + fraction * input[index + 1])
              .round();
    } else {
      output[i] = input[index];
    }
  }

  return output;
}

typedef IsolateSpawnFn = Future<Isolate?> Function(
  void Function(SendPort) entryPoint,
  SendPort message,
);

/// Off-main-thread resampling and fixed-duration PCM framing for live capture.
class IsolateAudioPipeline {
  IsolateAudioPipeline(
    this.config, {
    IsolateSpawnFn? spawnIsolate,
  }) : _spawnIsolate = spawnIsolate ?? _defaultSpawnIsolate;

  final PipelineConfig config;
  final IsolateSpawnFn _spawnIsolate;

  Isolate? _isolate;
  SendPort? _toIsolatePort;
  ReceivePort? _fromIsolatePort;
  StreamSubscription<Object?>? _fromIsolateSubscription;
  StreamController<Int16List>? _outputController;
  Completer<void>? _readyCompleter;

  var _isAlive = false;

  Stream<Int16List> get processedAudioStream =>
      _outputController?.stream ?? const Stream<Int16List>.empty();

  bool get isRunning => _isAlive;

  Future<void> start() async {
    if (_isAlive) {
      return;
    }

    _readyCompleter = Completer<void>();
    _outputController = StreamController<Int16List>.broadcast();
    _fromIsolatePort = ReceivePort();

    _fromIsolateSubscription = _fromIsolatePort!.listen(_handleIsolateMessage);

    _isolate = await _spawnIsolate(
      _isolateWorkerEntryPoint,
      _fromIsolatePort!.sendPort,
    );

    await _readyCompleter!.future;
    _isAlive = true;
  }

  void _handleIsolateMessage(Object? message) {
    if (message is SendPort) {
      _toIsolatePort = message;
      _toIsolatePort!.send(
        IsolatePipelineMessage(
          command: PipelineCommand.init,
          config: config,
        ),
      );
      final readyCompleter = _readyCompleter;
      if (readyCompleter != null && !readyCompleter.isCompleted) {
        readyCompleter.complete();
      }
      return;
    }

    if (message is Int16List) {
      final controller = _outputController;
      if (controller != null && !controller.isClosed) {
        controller.add(message);
      }
      return;
    }

    if (message == _droppedPacketSignal) {
      LiveAudioPipelineLog.pipelineFrameDropped();
    }
  }

  /// Pushes raw hardware PCM16 buffers to the worker without main-thread resampling.
  void pushRawHardwareBuffer(Int16List rawBuffer) {
    if (!_isAlive || _toIsolatePort == null) {
      return;
    }

    _toIsolatePort!.send(
      IsolatePipelineMessage(
        command: PipelineCommand.process,
        payload: rawBuffer,
      ),
    );
  }

  Future<void> dispose() async {
    if (!_isAlive && _isolate == null) {
      return;
    }

    _isAlive = false;
    _toIsolatePort?.send(
      const IsolatePipelineMessage(command: PipelineCommand.stop),
    );

    await _fromIsolateSubscription?.cancel();
    _fromIsolateSubscription = null;

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;

    _fromIsolatePort?.close();
    _fromIsolatePort = null;
    _toIsolatePort = null;

    await _outputController?.close();
    _outputController = null;
  }

  static Future<Isolate?> _defaultSpawnIsolate(
    void Function(SendPort) entryPoint,
    SendPort message,
  ) {
    return Isolate.spawn(
      entryPoint,
      message,
      debugName: 'AudioPipelineIsolate',
    );
  }

  static const Object _droppedPacketSignal = 'DROPPED_PACKET';

  /// Isolate execution boundary — no access to main-thread context memory.
  static void _isolateWorkerEntryPoint(SendPort mainSendPort) {
    final isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);

    AudioPipelineProcessor? processor;

    isolateReceivePort.listen((message) {
      if (message is! IsolatePipelineMessage) {
        return;
      }

      switch (message.command) {
        case PipelineCommand.init:
          final activeConfig = message.config;
          if (activeConfig == null) {
            return;
          }
          processor = AudioPipelineProcessor(activeConfig);
          break;

        case PipelineCommand.process:
          final activeProcessor = processor;
          final payload = message.payload;
          if (activeProcessor == null || payload == null) {
            return;
          }

          final result = activeProcessor.processRawBuffer(payload);
          if (result.droppedOldestFrame) {
            mainSendPort.send(_droppedPacketSignal);
          }

          for (final frame in result.frames) {
            mainSendPort.send(frame);
          }
          break;

        case PipelineCommand.stop:
          isolateReceivePort.close();
          break;
      }
    });
  }
}
