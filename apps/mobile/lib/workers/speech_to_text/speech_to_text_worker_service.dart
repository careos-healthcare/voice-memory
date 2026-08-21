import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/reflections/data/onnx_whisper_transcription.dart';
import 'package:archiveme_mobile/features/reflections/data/whisper_audio_processor.dart';
import 'package:archiveme_mobile/storage/sqlite/isolate_safe_sqlite_database_initializer.dart';
import 'package:archiveme_mobile/workers/isolate_worker_client.dart';
import 'package:flutter/services.dart';

/// Operations handled by [SpeechToTextWorkerService].
abstract final class SpeechToTextWorkerOperations {
  SpeechToTextWorkerOperations._();

  static const transcribeFile = 'transcribeFile';
  static const shutdown = 'shutdown';
}

/// Persistent worker isolate for Whisper mel extraction + ONNX STT.
class SpeechToTextWorkerService implements PersistentIsolateWorkerClient {
  SpeechToTextWorkerService._();

  static final SpeechToTextWorkerService instance =
      SpeechToTextWorkerService._();

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  SendPort? workerPort;
  @override
  ReceivePort? responsePort;
  @override
  StreamSubscription<dynamic>? responseSubscription;
  @override
  Isolate? isolate;
  @override
  Future<void>? starting;
  @override
  int nextRequestId = 1;
  @override
  final pending = <int, Completer<Object?>>{};
  @override
  final streamPending = <int, StreamController<Object?>>{};

  bool get isRunning => workerPort != null || _testRuntime != null;

  _SpeechToTextWorkerRuntime? _testRuntime;

  @override
  Future<void> ensureStarted() {
    if (_isFlutterTest) {
      _testRuntime ??= _SpeechToTextWorkerRuntime();
      return Future<void>.value();
    }
    if (workerPort != null) {
      return Future<void>.value();
    }
    return starting ??= spawnWorker(
      entryPoint: speechToTextWorkerIsolateEntry,
      startup: IsolateWorkerStartup(
        handshakePort: ReceivePort().sendPort,
        clientResponsePort: ReceivePort().sendPort,
        initializeTestFfi: _isFlutterTest,
        rootIsolateToken: _isFlutterTest ? null : RootIsolateToken.instance,
      ),
    );
  }

  @override
  Future<void> spawnWorker({
    required void Function(IsolateWorkerStartup startup) entryPoint,
    required IsolateWorkerStartup startup,
  }) {
    final handshakePort = ReceivePort();
    final responsePort = ReceivePort();
    final resolvedStartup = IsolateWorkerStartup(
      handshakePort: handshakePort.sendPort,
      clientResponsePort: responsePort.sendPort,
      initializeTestFfi: startup.initializeTestFfi,
      rootIsolateToken: startup.rootIsolateToken,
    );
    return spawnWorkerImpl(
      entryPoint: entryPoint,
      startup: resolvedStartup,
    );
  }

  /// Transcribes [audioFilePath] off the UI thread (mel + ONNX in worker).
  Future<WhisperTranscriptionResult?> transcribeAudioFile(
    String audioFilePath,
  ) async {
    if (audioFilePath.trim().isEmpty) return null;

    try {
      await ensureStarted();
      if (_isFlutterTest && _testRuntime != null) {
        final result = await _testRuntime!.handle(
          IsolateWorkerRequest(
            requestId: 0,
            operation: SpeechToTextWorkerOperations.transcribeFile,
            payload: {'audioFilePath': audioFilePath},
          ),
        );
        return _decodeResult(result);
      }
      final result = await dispatchImpl<Map<String, dynamic>>(
        operation: SpeechToTextWorkerOperations.transcribeFile,
        payload: {'audioFilePath': audioFilePath},
      );
      return _decodeResult(result);
    } on Object {
      return null;
    }
  }

  WhisperTranscriptionResult? _decodeResult(Map<String, dynamic>? result) {
    if (result == null) return null;
    final transcript = result['transcript'] as String? ?? '';
    if (transcript.trim().isEmpty) return null;
    return WhisperTranscriptionResult(
      transcript: transcript,
      confidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
      usedOnnx: result['usedOnnx'] as bool? ?? false,
    );
  }

  @override
  Future<T> dispatch<T>({
    required String operation,
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(minutes: 2),
  }) {
    return dispatchImpl<T>(
      operation: operation,
      payload: payload,
      timeout: timeout,
    );
  }

  @override
  Stream<Object?> dispatchStream({
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return dispatchStreamImpl(operation: operation, payload: payload);
  }

  @override
  void handleWorkerResponse(Object? message) {
    handleWorkerResponseImpl(message);
  }

  @override
  Future<void> disposeWorker({required String shutdownOperation}) {
    return disposeWorkerImpl(shutdownOperation: shutdownOperation);
  }

  Future<void> dispose() {
    _testRuntime = null;
    return disposeWorker(
      shutdownOperation: SpeechToTextWorkerOperations.shutdown,
    );
  }

  @override
  Future<void> closeClientState() => dispose();
}

/// Top-level entry for the speech-to-text worker isolate.
Future<void> speechToTextWorkerIsolateEntry(IsolateWorkerStartup startup) async {
  IsolateSafeSqliteDatabaseInitializer.ensureWorkerRuntime(
    initializeTestFfi: startup.initializeTestFfi,
    rootIsolateToken: startup.rootIsolateToken,
  );

  final runtime = _SpeechToTextWorkerRuntime();
  final serverPort = ReceivePort();
  startup.handshakePort.send(serverPort.sendPort);

  await for (final message in serverPort) {
    if (message is! Map) continue;

    final request = IsolateWorkerRequest.fromJson(
      message.map((key, value) => MapEntry(key.toString(), value)),
    );

    if (request.operation == SpeechToTextWorkerOperations.shutdown) {
      serverPort.close();
      break;
    }

    try {
      final result = await runtime.handle(request);
      startup.clientResponsePort.send(
        IsolateWorkerResponse(
          requestId: request.requestId,
          result: result,
        ).toJson(),
      );
    } on Object catch (error, stackTrace) {
      startup.clientResponsePort.send(
        IsolateWorkerResponse(
          requestId: request.requestId,
          error: '$error',
        ).toJson(),
      );
    }
  }
}

final class _SpeechToTextWorkerRuntime {
  OnnxWhisperSpeechToText? _whisper;

  Future<Map<String, dynamic>?> handle(IsolateWorkerRequest request) async {
    switch (request.operation) {
      case SpeechToTextWorkerOperations.transcribeFile:
        return _transcribeFile(request.payload);
      default:
        throw UnsupportedError('Unknown STT operation: ${request.operation}');
    }
  }

  Future<Map<String, dynamic>?> _transcribeFile(
    Map<String, dynamic> payload,
  ) async {
    final path = payload['audioFilePath'] as String? ?? '';
    if (path.isEmpty) return null;

    final mel = WhisperAudioProcessor.buildMelFeaturesFromFile(File(path));
    if (mel == null) return null;

    _whisper ??= await OnnxWhisperSpeechToText.tryCreate();
    final whisper = _whisper;
    if (whisper == null) return null;

    try {
      final result = await whisper.transcribeWavFile(mel);
      if (result == null) return null;

      return {
        'transcript': result.transcript,
        'confidence': result.confidence,
        'usedOnnx': result.usedOnnx,
      };
    } finally {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }
}