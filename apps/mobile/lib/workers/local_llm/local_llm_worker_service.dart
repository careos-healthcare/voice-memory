import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_model_contract.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';
import 'package:archiveme_mobile/storage/sqlite/isolate_safe_sqlite_database_initializer.dart';
import 'package:archiveme_mobile/workers/isolate_worker_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Operations handled by [LocalLlmWorkerService].
abstract final class LocalLlmWorkerOperations {
  LocalLlmWorkerOperations._();

  static const loadModel = 'loadModel';
  static const streamCompletion = 'streamCompletion';
  static const disposeModel = 'disposeModel';
  static const unloadModelForBackground = 'unloadModelForBackground';
  static const shutdown = 'shutdown';
}

/// Dedicated llama.cpp worker isolate with explicit SendPort/ReceivePort IPC.
///
/// The worker owns a [LlamaParent] managed isolate so GGUF inference never
/// blocks the UI thread. Model paths are supplied by the UI isolate over IPC;
/// this worker never materializes bundled Flutter GGUF assets.
class LocalLlmWorkerService implements PersistentIsolateWorkerClient {
  LocalLlmWorkerService._();

  static final LocalLlmWorkerService instance = LocalLlmWorkerService._();

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

  bool get isRunning => workerPort != null;

  /// Clears cached load state in UI-isolate backends after a background unload.
  final ObserverList<VoidCallback> _modelUnloadedListeners = ObserverList();

  void addModelUnloadedListener(VoidCallback listener) {
    _modelUnloadedListeners.add(listener);
  }

  void removeModelUnloadedListener(VoidCallback listener) {
    _modelUnloadedListeners.remove(listener);
  }

  void _notifyModelUnloaded() {
    for (final listener in List<VoidCallback>.from(_modelUnloadedListeners)) {
      listener();
    }
  }

  @override
  Future<void> ensureStarted() {
    if (workerPort != null) {
      return Future<void>.value();
    }
    return starting ??= spawnWorker(
      entryPoint: localLlmWorkerIsolateEntry,
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

  Future<void> loadModel(LocalLlmConfig config) async {
    await ensureStarted();
    await dispatchImpl<void>(
      operation: LocalLlmWorkerOperations.loadModel,
      payload: _configPayload(config),
    );
  }

  Stream<LocalLlmTokenEvent> streamCompletion(
    LocalLlmCompletionRequest request,
  ) {
    final controller = StreamController<LocalLlmTokenEvent>();

    dispatchStreamImpl(
      operation: LocalLlmWorkerOperations.streamCompletion,
      payload: {
        'prompt': request.effectivePrompt,
        if (request.maxTokens != null) 'maxTokens': request.maxTokens,
        if (request.temperature != null) 'temperature': request.temperature,
        if (request.systemPrompt != null) 'systemPrompt': request.systemPrompt,
      },
    ).listen(
      (event) {
        if (controller.isClosed || event is! Map) return;
        final token = event['token'] as String? ?? '';
        final promptId = event['promptId'] as String? ?? '';
        final isFinal = event['isFinal'] as bool? ?? false;
        controller.add(
          LocalLlmTokenEvent(
            token: token,
            promptId: promptId,
            isFinal: isFinal,
          ),
        );
      },
      onError: controller.addError,
      onDone: controller.close,
      cancelOnError: false,
    );

    return controller.stream;
  }

  Future<void> disposeModel() async {
    if (workerPort == null) return;
    await dispatchImpl<void>(
      operation: LocalLlmWorkerOperations.disposeModel,
      payload: const {},
    );
    _notifyModelUnloaded();
  }

  /// Requests cooperative cancellation and waits until the worker isolate has
  /// returned from native llama.cpp code to the Dart event loop.
  Future<void> cancelGenerationAndAwaitAck({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (workerPort == null) {
      return;
    }

    await ensureStarted();

    final ack = await dispatchImpl<String>(
      operation: IsolateWorkerControlOperations.cancelGenerationRequest,
      payload: const {},
      timeout: timeout,
    );
    if (ack != IsolateWorkerControlSignals.cancelAcknowledged) {
      throw StateError(
        'Expected ${IsolateWorkerControlSignals.cancelAcknowledged}, got $ack',
      );
    }
  }

  /// Cancels in-flight generation, awaits worker acknowledgment, then unloads GGUF.
  Future<void> unloadModelForBackground({
    Duration cancelTimeout = const Duration(seconds: 10),
  }) async {
    _notifyModelUnloaded();

    if (_isFlutterTest || workerPort == null) {
      return;
    }

    await ensureStarted();

    try {
      await cancelGenerationAndAwaitAck(timeout: cancelTimeout);
    } on Object {
      // Best-effort cancel before unload — proceed even if generation was idle.
    }

    await dispatchImpl<void>(
      operation: LocalLlmWorkerOperations.unloadModelForBackground,
      payload: const {},
      timeout: const Duration(seconds: 15),
    );
  }

  Map<String, dynamic> _configPayload(LocalLlmConfig config) {
    return {
      'modelPath': config.modelPath,
      if (config.libraryPath != null) 'libraryPath': config.libraryPath,
      'contextSize': config.contextSize,
      'batchSize': config.batchSize,
      'microBatchSize': config.microBatchSize,
      'threadCount': config.threadCount,
      'gpuLayers': config.gpuLayers,
      'temperature': config.temperature,
      'topP': config.topP,
      'maxTokens': config.maxTokens,
      'useChatMlFormat': config.useChatMlFormat,
      'requirePreferredQuantization': config.requirePreferredQuantization,
    };
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

  Future<void> dispose() async {
    await disposeModel();
    await disposeWorker(shutdownOperation: LocalLlmWorkerOperations.shutdown);
  }

  @override
  Future<void> closeClientState() => dispose();
}

/// Mobile worker load caps to avoid thermal throttling and OOM during long sessions.
abstract final class LocalLlmWorkerLoadPolicy {
  LocalLlmWorkerLoadPolicy._();

  static const maxContextTokens = 1024;
  static const maxEfficiencyThreads = 2;

  /// Approximates efficiency-core budget: half of logical CPUs, capped at 2.
  @visibleForTesting
  static int efficiencyCoreThreadCount({int? processorCount}) {
    final cores = processorCount ?? Platform.numberOfProcessors;
    final halfCores = cores ~/ 2;
    return halfCores.clamp(1, maxEfficiencyThreads);
  }

  static LocalLlmConfig applyResourceCaps(LocalLlmConfig config) {
    final contextSize = config.contextSize.clamp(1, maxContextTokens);
    final batchSize = config.batchSize.clamp(1, contextSize);
    final microBatchSize = config.microBatchSize.clamp(1, batchSize);
    final maxTokens = config.maxTokens.clamp(1, contextSize - 1);

    return LocalLlmConfig(
      modelPath: config.modelPath,
      libraryPath: config.libraryPath,
      contextSize: contextSize,
      batchSize: batchSize,
      microBatchSize: microBatchSize,
      threadCount: efficiencyCoreThreadCount(),
      gpuLayers: config.gpuLayers,
      temperature: config.temperature,
      topP: config.topP,
      maxTokens: maxTokens,
      useChatMlFormat: config.useChatMlFormat,
      requirePreferredQuantization: config.requirePreferredQuantization,
      kvCacheQuantization: config.kvCacheQuantization,
    );
  }

  static LlamaLoad toWorkerLoadCommand(LocalLlmConfig config) {
    final capped = applyResourceCaps(config);
    capped.validateModelPath();

    final modelParams = capped.toModelParams()
      ..nGpuLayers = capped.gpuLayers
      ..useMemorymap = true
      ..useMemoryLock = false
      ..vocabOnly = false
      ..checkTensors = false;

    final threadCount = efficiencyCoreThreadCount();
    final contextParams = capped.toContextParams()
      ..nCtx = capped.contextSize.clamp(1, maxContextTokens)
      ..nThreads = threadCount
      ..nThreadsBatch = threadCount;

    final samplingParams = SamplerParams()
      ..temp = capped.temperature
      ..topP = capped.topP;

    return LlamaLoad(
      path: capped.modelPath,
      modelParams: modelParams,
      contextParams: contextParams,
      samplingParams: samplingParams,
      verbose: false,
    );
  }
}

/// Top-level entry for the llama.cpp worker isolate.
Future<void> localLlmWorkerIsolateEntry(IsolateWorkerStartup startup) async {
  IsolateSafeSqliteDatabaseInitializer.ensureWorkerRuntime(
    initializeTestFfi: startup.initializeTestFfi,
    rootIsolateToken: startup.rootIsolateToken,
  );

  final runtime = _LocalLlmWorkerRuntime(clientResponsePort: startup.clientResponsePort);
  final serverPort = ReceivePort();
  startup.handshakePort.send(serverPort.sendPort);

  await for (final message in serverPort) {
    if (message is! Map) continue;

    final request = IsolateWorkerRequest.fromJson(
      message.map((key, value) => MapEntry(key.toString(), value)),
    );

    if (request.operation == LocalLlmWorkerOperations.shutdown) {
      await runtime.disposeModel();
      serverPort.close();
      break;
    }

    if (request.operation == LocalLlmWorkerOperations.streamCompletion) {
      runtime.startStreamCompletion(request);
      continue;
    }

    try {
      await runtime.handle(request);
      if (request.requestId != 0) {
        startup.clientResponsePort.send(
          IsolateWorkerResponse(
            requestId: request.requestId,
            result: null,
          ).toJson(),
        );
      }
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

final class _LocalLlmWorkerRuntime {
  _LocalLlmWorkerRuntime({required this.clientResponsePort});

  final SendPort clientResponsePort;
  LlamaParent? _parent;
  PromptFormat? _formatter;
  Future<void>? _activeStreamCompletion;

  Future<void> handle(IsolateWorkerRequest request) async {
    switch (request.operation) {
      case LocalLlmWorkerOperations.loadModel:
        await _loadModel(request.payload);
        return;
      case LocalLlmWorkerOperations.disposeModel:
      case LocalLlmWorkerOperations.unloadModelForBackground:
        await disposeModel();
        return;
      case IsolateWorkerControlOperations.cancelGenerationRequest:
        await _cancelGeneration(request.requestId);
        return;
      default:
        throw UnsupportedError('Unknown LLM operation: ${request.operation}');
    }
  }

  void startStreamCompletion(IsolateWorkerRequest request) {
    _activeStreamCompletion = _streamCompletion(
      requestId: request.requestId,
      payload: request.payload,
    ).whenComplete(() {
      _activeStreamCompletion = null;
    });
  }

  Future<void> _cancelGeneration(int requestId) async {
    final parent = _parent;
    if (parent != null && parent.isGenerating) {
      await parent.stop();
    }

    final active = _activeStreamCompletion;
    if (active != null) {
      await active.catchError((_) {});
    }

    Llama.clearGenerationAbort();

    clientResponsePort.send(
      IsolateWorkerResponse(
        requestId: requestId,
        controlSignal: IsolateWorkerControlSignals.cancelAcknowledged,
      ).toJson(),
    );
  }

  Future<void> _loadModel(Map<String, dynamic> payload) async {
    await disposeModel();

    final config = LocalLlmConfig(
      modelPath: payload['modelPath'] as String? ?? '',
      libraryPath: payload['libraryPath'] as String?,
      contextSize:
          payload['contextSize'] as int? ??
          LocalLlmModelContract.defaultContextSize,
      batchSize: payload['batchSize'] as int? ?? 256,
      microBatchSize: payload['microBatchSize'] as int? ?? 128,
      threadCount: payload['threadCount'] as int? ?? 4,
      gpuLayers: payload['gpuLayers'] as int? ?? 0,
      temperature: (payload['temperature'] as num?)?.toDouble() ?? 0.2,
      topP: (payload['topP'] as num?)?.toDouble() ?? 0.9,
      maxTokens: payload['maxTokens'] as int? ?? 256,
      useChatMlFormat: payload['useChatMlFormat'] as bool? ?? true,
      requirePreferredQuantization:
          payload['requirePreferredQuantization'] as bool? ?? true,
    );

    config.validateModelPath();

    if (config.libraryPath != null) {
      Llama.libraryPath = config.libraryPath;
    }

    _formatter = config.useChatMlFormat ? ChatMLFormat() : null;
    _parent = LlamaParent(LocalLlmWorkerLoadPolicy.toWorkerLoadCommand(config), _formatter);
    await _parent!.init();
  }

  Future<void> _streamCompletion({
    required int requestId,
    required Map<String, dynamic> payload,
  }) async {
    final parent = _parent;
    if (parent == null) {
      throw StateError('LLM worker loadModel must be called first.');
    }

    final prompt = payload['prompt'] as String? ?? '';
    final promptId = await parent.sendPrompt(prompt);

    final tokenSub = parent.stream.listen(
      (token) {
        if (token.isEmpty) return;
        clientResponsePort.send(
          IsolateWorkerResponse(
            requestId: requestId,
            result: {
              'token': token,
              'promptId': promptId,
              'isFinal': false,
            },
            done: false,
          ).toJson(),
        );
      },
      onError: (Object error) {
        clientResponsePort.send(
          IsolateWorkerResponse(
            requestId: requestId,
            error: error.toString(),
          ).toJson(),
        );
      },
    );

    try {
      await for (final event in parent.completions) {
        if (event.promptId != promptId) continue;
        await tokenSub.cancel();
        if (!event.success) {
          clientResponsePort.send(
            IsolateWorkerResponse(
              requestId: requestId,
              error: event.errorDetails ?? 'Completion failed.',
            ).toJson(),
          );
          return;
        }

        clientResponsePort.send(
          IsolateWorkerResponse(
            requestId: requestId,
            result: {
              'token': '',
              'promptId': promptId,
              'isFinal': true,
            },
          ).toJson(),
        );
        return;
      }
    } finally {
      await tokenSub.cancel();
    }
  }

  Future<void> disposeModel() async {
    final parent = _parent;
    _parent = null;
    _formatter = null;
    if (parent != null) {
      if (parent.isGenerating) {
        await parent.stop();
      }
      final active = _activeStreamCompletion;
      if (active != null) {
        await active.catchError((_) {});
      }
      await parent.dispose();
    }
    Llama.clearGenerationAbort();
  }
}