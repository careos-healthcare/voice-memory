import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../semantic_extraction_result.dart';
import 'llama_native_backend.dart';

typedef LlamaInferenceBackendFactory = LlamaInferenceBackend Function();

LlamaInferenceBackend createLlamaNativeBackend() => LlamaNativeBackend();

enum LlamaInferenceSessionState { idle, warmingUp, ready, failed, disposed }

final class LlamaInferenceResponse {
  const LlamaInferenceResponse({
    required this.requestId,
    required this.rawGeneratedJson,
    required this.result,
  });

  final int requestId;
  final String rawGeneratedJson;
  final SemanticExtractionResult result;
}

final class LlamaInferenceSession {
  LlamaInferenceSession({this.backendFactory = createLlamaNativeBackend});

  static const int minContextSize = 256;
  static const int maxContextSize = 8192;
  static const int maxOutputTokens = 1024;
  static const int maxInputCharacters = 32768;
  static const Duration maxInferenceTimeout = Duration(minutes: 5);
  static const String _inferenceDriver = 'llama.cpp';

  final LlamaInferenceBackendFactory backendFactory;
  final ReceivePort _receivePort = ReceivePort();
  final Map<int, _PendingRequest<Object?>> _pending = {};
  final Map<int, String> _requestTexts = {};
  final Set<int> _rawRequestIds = {};
  Isolate? _isolate;
  SendPort? _workerPort;
  StreamSubscription<Object?>? _subscription;
  Completer<void>? _workerStarted;
  int _nextRequestId = 1;
  LlamaInferenceSessionState _state = LlamaInferenceSessionState.idle;

  LlamaInferenceSessionState get status => _state;
  LlamaInferenceSessionState get state => status;
  bool get isReady => _state == LlamaInferenceSessionState.ready;

  Future<void> warmUp({
    required String modelPath,
    int contextSize = 2048,
    int threads = 4,
    int gpuLayers = 0,
  }) async {
    _ensureNotDisposed();
    if (_state == LlamaInferenceSessionState.ready) return;
    if (_state == LlamaInferenceSessionState.warmingUp) {
      throw StateError('Llama inference warm-up is already in progress.');
    }
    _validateWarmUpOptions(contextSize, threads, gpuLayers);
    _state = LlamaInferenceSessionState.warmingUp;

    try {
      await _startWorker();
      final requestId = _nextRequestId++;
      final future = _register<void>(
        requestId,
        const Duration(minutes: 5),
        operation: 'warm-up',
      );
      _workerPort!.send([
        'warmUp',
        requestId,
        modelPath,
        contextSize,
        threads,
        gpuLayers,
      ]);
      await future;
      _state = LlamaInferenceSessionState.ready;
    } on Object {
      _state = LlamaInferenceSessionState.failed;
      rethrow;
    }
  }

  Future<SemanticExtractionResult> infer(
    String text, {
    int maxTokens = 256,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final response = await inferDetailed(
      text,
      maxTokens: maxTokens,
      timeout: timeout,
    );
    return response.result;
  }

  Future<void> loadAdapter(String adapterPath, {double scale = 1}) async {
    _ensureNotDisposed();
    if (!isReady) {
      throw StateError('Llama inference session is not ready.');
    }
    final requestId = _nextRequestId++;
    final future = _register<void>(
      requestId,
      const Duration(seconds: 30),
      operation: 'adapter load',
    );
    _workerPort!.send(['loadAdapter', requestId, adapterPath, scale]);
    await future;
  }

  Future<void> unloadAdapter() async {
    _ensureNotDisposed();
    if (!isReady) return;
    final requestId = _nextRequestId++;
    final future = _register<void>(
      requestId,
      const Duration(seconds: 15),
      operation: 'adapter unload',
    );
    _workerPort!.send(['unloadAdapter', requestId]);
    await future;
  }

  Future<LlamaInferenceResponse> inferDetailed(
    String text, {
    int maxTokens = 256,
    Duration timeout = const Duration(seconds: 30),
  }) {
    _ensureNotDisposed();
    if (!isReady) {
      throw StateError('Llama inference session is not ready.');
    }
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be empty');
    }
    if (normalizedText.length > maxInputCharacters) {
      throw RangeError.range(
        normalizedText.length,
        1,
        maxInputCharacters,
        'text.length',
      );
    }
    if (maxTokens < 1 || maxTokens > maxOutputTokens) {
      throw RangeError.range(maxTokens, 1, maxOutputTokens, 'maxTokens');
    }
    if (timeout <= Duration.zero || timeout > maxInferenceTimeout) {
      throw RangeError(
        'timeout must be between 1ms and '
        '${maxInferenceTimeout.inMilliseconds}ms',
      );
    }

    final requestId = _nextRequestId++;
    final future = _register<LlamaInferenceResponse>(
      requestId,
      timeout,
      operation: 'inference',
    );
    _requestTexts[requestId] = normalizedText;
    _workerPort!.send([
      'infer',
      requestId,
      _strictExtractionPrompt(normalizedText),
      maxTokens,
      timeout.inMilliseconds,
    ]);
    return future;
  }

  /// Runs a bounded local text completion without semantic JSON parsing.
  ///
  /// This is reserved for audited, capability-gated local features such as
  /// Catalyst Council summaries. It uses the same native worker and limits as
  /// semantic extraction and never introduces a network transport.
  Future<String> inferRaw(
    String prompt, {
    int maxTokens = 256,
    Duration timeout = const Duration(seconds: 30),
  }) {
    _ensureNotDisposed();
    if (!isReady) throw StateError('Llama inference session is not ready.');
    final normalized = prompt.trim();
    if (normalized.isEmpty || normalized.length > maxInputCharacters) {
      throw ArgumentError.value(prompt, 'prompt', 'invalid prompt length');
    }
    if (maxTokens < 1 || maxTokens > maxOutputTokens) {
      throw RangeError.range(maxTokens, 1, maxOutputTokens, 'maxTokens');
    }
    if (timeout <= Duration.zero || timeout > maxInferenceTimeout) {
      throw RangeError('Invalid inference timeout.');
    }
    final requestId = _nextRequestId++;
    final future = _register<String>(
      requestId,
      timeout,
      operation: 'raw inference',
    );
    _rawRequestIds.add(requestId);
    _workerPort!.send([
      'infer',
      requestId,
      normalized,
      maxTokens,
      timeout.inMilliseconds,
    ]);
    return future;
  }

  void cancel(int requestId) {
    final request = _pending.remove(requestId);
    _requestTexts.remove(requestId);
    _rawRequestIds.remove(requestId);
    if (request == null) return;
    request.timer.cancel();
    request.completer.completeError(
      const LlamaInferenceCancelledException('Inference was cancelled.'),
    );
    _workerPort?.send(['cancel', requestId]);
  }

  Future<void> dispose() async {
    if (_state == LlamaInferenceSessionState.disposed) return;
    _state = LlamaInferenceSessionState.disposed;
    for (final pending in _pending.values) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          StateError('Llama inference session was disposed.'),
        );
      }
    }
    _pending.clear();
    _requestTexts.clear();
    _rawRequestIds.clear();

    final worker = _workerPort;
    if (worker != null) {
      final requestId = _nextRequestId++;
      final done = _register<void>(
        requestId,
        const Duration(seconds: 5),
        operation: 'dispose',
        allowDisposed: true,
      );
      worker.send(['dispose', requestId]);
      try {
        await done;
      } on Object {
        // The isolate is killed below even if native cleanup reports a failure.
      }
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _workerPort = null;
    await _subscription?.cancel();
    _subscription = null;
    _receivePort.close();
  }

  Future<void> _startWorker() {
    final existing = _workerStarted;
    if (existing != null) return existing.future;
    final started = Completer<void>();
    _workerStarted = started;
    _subscription = _receivePort.listen(_handleWorkerMessage);
    Isolate.spawn<_WorkerBootstrap>(
          _llamaWorkerMain,
          _WorkerBootstrap(_receivePort.sendPort, backendFactory),
          errorsAreFatal: true,
          onError: _receivePort.sendPort,
          onExit: _receivePort.sendPort,
        )
        .then((isolate) {
          _isolate = isolate;
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!started.isCompleted) started.completeError(error, stackTrace);
        });
    return started.future;
  }

  void _handleWorkerMessage(Object? message) {
    if (message is SendPort) {
      _workerPort = message;
      final started = _workerStarted;
      if (started != null && !started.isCompleted) started.complete();
      return;
    }
    if (message is! List<Object?> || message.length < 3) return;
    final requestId = message[0];
    final succeeded = message[1];
    if (requestId is! int || succeeded is! bool) return;
    final pending = _pending.remove(requestId);
    final requestText = _requestTexts.remove(requestId);
    final raw = _rawRequestIds.remove(requestId);
    if (pending == null) return;
    pending.timer.cancel();
    if (succeeded) {
      final payload = message[2];
      if (payload is String) {
        if (raw) {
          pending.completer.complete(payload);
          return;
        }
        try {
          pending.completer.complete(
            LlamaInferenceResponse(
              requestId: requestId,
              rawGeneratedJson: payload,
              result: _parseSemanticResult(payload, requestText ?? ''),
            ),
          );
        } on Object catch (error, stackTrace) {
          pending.completer.completeError(error, stackTrace);
        }
      } else {
        pending.completer.complete(null);
      }
      return;
    }

    final kind = message.length > 3 ? message[3] : 'error';
    final detail = message[2]?.toString() ?? 'Llama worker failed.';
    pending.completer.completeError(switch (kind) {
      'timeout' => TimeoutException(detail),
      'unavailable' => LlamaRuntimeUnavailableException(detail),
      'cancelled' => LlamaInferenceCancelledException(detail),
      _ => LlamaWorkerException(detail),
    });
  }

  Future<T> _register<T>(
    int requestId,
    Duration timeout, {
    required String operation,
    bool allowDisposed = false,
  }) {
    if (!allowDisposed) _ensureNotDisposed();
    final completer = Completer<Object?>();
    final timer = Timer(timeout, () {
      final pending = _pending.remove(requestId);
      _requestTexts.remove(requestId);
      if (pending == null || pending.completer.isCompleted) return;
      pending.completer.completeError(
        TimeoutException('Llama $operation timed out after $timeout.'),
      );
      _workerPort?.send(['cancel', requestId]);
    });
    _pending[requestId] = _PendingRequest<Object?>(completer, timer);
    return completer.future.then((value) => value as T);
  }

  void _ensureNotDisposed() {
    if (_state == LlamaInferenceSessionState.disposed) {
      throw StateError('Llama inference session is disposed.');
    }
  }

  static void _validateWarmUpOptions(
    int contextSize,
    int threads,
    int gpuLayers,
  ) {
    if (contextSize < minContextSize || contextSize > maxContextSize) {
      throw RangeError.range(
        contextSize,
        minContextSize,
        maxContextSize,
        'contextSize',
      );
    }
    if (threads < 1 || threads > 8) {
      throw RangeError.range(threads, 1, 8, 'threads');
    }
    if (gpuLayers < -1 || gpuLayers > 256) {
      throw RangeError.range(gpuLayers, -1, 256, 'gpuLayers');
    }
  }

  static String _strictExtractionPrompt(String text) =>
      '''
You extract structured autobiographical memory facts.
Return exactly one JSON object and no markdown, commentary, or code fences.
Use this exact schema:
{"entities":[{"type":"person|place|event|goal|fear|habit|belief|project|emotion|decision|outcome","label":"string","confidence":0.0,"sentiment":0.0,"excerpt":"verbatim input excerpt","startUtf16":0,"endUtf16":1}],"relations":[{"type":"triggeredBy|influences|evolvedInto|decidedOn|resultedIn|feltAbout|partOf|supportsBelief|contradictsBelief","sourceType":"person|place|event|goal|fear|habit|belief|project|emotion|decision|outcome","sourceLabel":"existing entity label","targetType":"person|place|event|goal|fear|habit|belief|project|emotion|decision|outcome","targetLabel":"different existing entity label","weight":0.0,"excerpt":"verbatim input excerpt","startUtf16":0,"endUtf16":1}],"sentiment":0.0,"confidence":0.0}
All confidence and weight values must be between 0 and 1. Sentiment must be between -1 and 1.
Offsets are zero-based UTF-16 code-unit offsets into INPUT and must exactly slice excerpt. Use empty arrays when no entity or relation is supported. Never invent evidence.
INPUT:
${jsonEncode(text)}
''';

  static SemanticExtractionResult _parseSemanticResult(
    String output,
    String input,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(output.trim());
    } on FormatException catch (error) {
      throw LlamaInvalidOutputException(
        'Model output was not valid JSON.',
        error,
      );
    }
    if (decoded is! Map) {
      throw const LlamaInvalidOutputException(
        'Model output must be one JSON object.',
      );
    }
    final json = Map<String, dynamic>.from(decoded);
    _validateSemanticJson(json, input);
    final result = SemanticExtractionResult.fromJson({
      ...json,
      'inferenceDriver': _inferenceDriver,
      'usedFallback': false,
    });
    if (!result.isValid) {
      throw const LlamaInvalidOutputException(
        'Model output did not contain a valid semantic extraction.',
      );
    }
    return result;
  }

  static void _validateSemanticJson(Map<String, dynamic> json, String input) {
    if (json['entities'] is! List ||
        json['relations'] is! List ||
        json['sentiment'] is! num ||
        json['confidence'] is! num) {
      throw const LlamaInvalidOutputException(
        'Model output is missing required semantic fields.',
      );
    }
    final confidence = json['confidence'] as num;
    final sentiment = json['sentiment'] as num;
    if (confidence <= 0 || confidence > 1 || sentiment < -1 || sentiment > 1) {
      throw const LlamaInvalidOutputException(
        'Model output has out-of-range summary scores.',
      );
    }
    final entityKeys = <String>{};
    for (final entity in json['entities'] as List) {
      if (entity is! Map) {
        throw const LlamaInvalidOutputException('Invalid semantic entity.');
      }
      final value = Map<String, dynamic>.from(entity);
      if (!_entityTypes.contains(value['type']) ||
          value['label'] is! String ||
          (value['label'] as String).trim().isEmpty ||
          value['excerpt'] is! String ||
          (value['excerpt'] as String).trim().isEmpty ||
          value['confidence'] is! num ||
          value['sentiment'] is! num ||
          !_hasExactCitation(value, input) ||
          !_isUnit(value['confidence'] as num) ||
          !_isSentiment(value['sentiment'] as num)) {
        throw const LlamaInvalidOutputException('Invalid semantic entity.');
      }
      entityKeys.add(
        '${value['type']}\u0000${(value['label'] as String).trim()}',
      );
    }
    for (final relation in json['relations'] as List) {
      if (relation is! Map) {
        throw const LlamaInvalidOutputException('Invalid semantic relation.');
      }
      final value = Map<String, dynamic>.from(relation);
      if (!_relationTypes.contains(value['type']) ||
          !_entityTypes.contains(value['sourceType']) ||
          !_entityTypes.contains(value['targetType']) ||
          value['sourceLabel'] is! String ||
          value['targetLabel'] is! String ||
          (value['sourceLabel'] as String).trim().isEmpty ||
          (value['targetLabel'] as String).trim().isEmpty ||
          (value['sourceLabel'] as String).trim() ==
              (value['targetLabel'] as String).trim() ||
          value['excerpt'] is! String ||
          (value['excerpt'] as String).trim().isEmpty ||
          value['weight'] is! num ||
          !_hasExactCitation(value, input) ||
          !_isUnit(value['weight'] as num)) {
        throw const LlamaInvalidOutputException('Invalid semantic relation.');
      }
      final sourceKey =
          '${value['sourceType']}\u0000${(value['sourceLabel'] as String).trim()}';
      final targetKey =
          '${value['targetType']}\u0000${(value['targetLabel'] as String).trim()}';
      if (!entityKeys.contains(sourceKey) || !entityKeys.contains(targetKey)) {
        throw const LlamaInvalidOutputException(
          'Semantic relation references an unknown entity.',
        );
      }
    }
  }

  static const Set<String> _entityTypes = {
    'person',
    'place',
    'event',
    'goal',
    'fear',
    'habit',
    'belief',
    'project',
    'emotion',
    'decision',
    'outcome',
  };
  static const Set<String> _relationTypes = {
    'triggeredBy',
    'influences',
    'evolvedInto',
    'decidedOn',
    'resultedIn',
    'feltAbout',
    'partOf',
    'supportsBelief',
    'contradictsBelief',
  };

  static bool _hasExactCitation(Map<String, dynamic> value, String input) {
    final start = value['startUtf16'];
    final end = value['endUtf16'];
    final excerpt = value['excerpt'];
    return start is int &&
        end is int &&
        excerpt is String &&
        start >= 0 &&
        end > start &&
        end <= input.length &&
        input.substring(start, end) == excerpt;
  }

  static bool _isUnit(num value) => value >= 0 && value <= 1;
  static bool _isSentiment(num value) => value >= -1 && value <= 1;
}

final class LlamaWorkerException implements Exception {
  const LlamaWorkerException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class LlamaInvalidOutputException implements Exception {
  const LlamaInvalidOutputException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class _PendingRequest<T> {
  const _PendingRequest(this.completer, this.timer);
  final Completer<T> completer;
  final Timer timer;
}

final class _WorkerBootstrap {
  const _WorkerBootstrap(this.parent, this.backendFactory);
  final SendPort parent;
  final LlamaInferenceBackendFactory backendFactory;
}

void _llamaWorkerMain(_WorkerBootstrap bootstrap) {
  final commands = ReceivePort();
  final backend = bootstrap.backendFactory();
  bootstrap.parent.send(commands.sendPort);
  commands.listen((Object? message) {
    if (message is! List<Object?> || message.length < 2) return;
    final operation = message[0];
    final requestId = message[1];
    if (operation is! String || requestId is! int) return;
    try {
      switch (operation) {
        case 'warmUp':
          backend.warmUp(
            modelPath: message[2]! as String,
            contextSize: message[3]! as int,
            threads: message[4]! as int,
            gpuLayers: message[5]! as int,
          );
          bootstrap.parent.send([requestId, true, null]);
        case 'infer':
          final output = backend.infer(
            prompt: message[2]! as String,
            maxTokens: message[3]! as int,
            timeout: Duration(milliseconds: message[4]! as int),
          );
          bootstrap.parent.send([requestId, true, output]);
        case 'loadAdapter':
          backend.loadAdapter(
            adapterPath: message[2]! as String,
            scale: message[3]! as double,
          );
          bootstrap.parent.send([requestId, true, null]);
        case 'unloadAdapter':
          backend.unloadAdapter();
          bootstrap.parent.send([requestId, true, null]);
        case 'cancel':
          backend.cancel();
        case 'dispose':
          backend.dispose();
          bootstrap.parent.send([requestId, true, null]);
          commands.close();
      }
    } on TimeoutException catch (error) {
      bootstrap.parent.send([requestId, false, error.toString(), 'timeout']);
    } on LlamaRuntimeUnavailableException catch (error) {
      bootstrap.parent.send([
        requestId,
        false,
        error.toString(),
        'unavailable',
      ]);
    } on LlamaInferenceCancelledException catch (error) {
      bootstrap.parent.send([requestId, false, error.toString(), 'cancelled']);
    } on Object catch (error) {
      bootstrap.parent.send([requestId, false, error.toString(), 'error']);
    }
  });
}
