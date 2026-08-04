import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'llama_native_bindings.dart';

typedef LlamaNativeApiLoader = LlamaNativeApi Function();

abstract interface class LlamaInferenceBackend {
  bool get isReady;

  void warmUp({
    required String modelPath,
    required int contextSize,
    required int threads,
    required int gpuLayers,
  });

  String infer({
    required String prompt,
    required int maxTokens,
    required Duration timeout,
  });

  void loadAdapter({required String adapterPath, required double scale});
  void unloadAdapter();
  void cancel();
  void dispose();
}

final class LlamaNativeBackend implements LlamaInferenceBackend {
  LlamaNativeBackend({LlamaNativeApiLoader? bindingsLoader})
    : _bindingsLoader = bindingsLoader ?? LlamaNativeBindings.open;

  final LlamaNativeApiLoader _bindingsLoader;
  LlamaNativeApi? _bindings;
  Pointer<Void>? _session;
  bool _disposed = false;

  @override
  bool get isReady => !_disposed && _session != null;

  @override
  void warmUp({
    required String modelPath,
    required int contextSize,
    required int threads,
    required int gpuLayers,
  }) {
    if (_disposed) {
      throw StateError('LlamaNativeBackend is disposed.');
    }
    if (_session != null) {
      throw StateError('LlamaNativeBackend is already initialized.');
    }
    if (!path.isAbsolute(modelPath) || !File(modelPath).existsSync()) {
      throw LlamaRuntimeUnavailableException(
        'GGUF model path does not exist or is not absolute.',
      );
    }

    try {
      final bindings = _bindingsLoader();
      final session = bindings.createSession(
        modelPath: modelPath,
        contextSize: contextSize,
        threads: threads,
        gpuLayers: gpuLayers,
      );
      _bindings = bindings;
      _session = session;
    } on Object catch (error) {
      throw LlamaRuntimeUnavailableException(
        'Native llama runtime could not initialize.',
        cause: error,
      );
    }
  }

  @override
  String infer({
    required String prompt,
    required int maxTokens,
    required Duration timeout,
  }) {
    final bindings = _bindings;
    final session = _session;
    if (_disposed || bindings == null || session == null) {
      throw StateError('LlamaNativeBackend is not ready.');
    }
    final result = bindings.complete(
      session,
      prompt: prompt,
      maxTokens: maxTokens,
      timeout: timeout,
    );
    if (result.status == LlamaNativeStatus.ok && result.output != null) {
      return result.output!;
    }
    if (result.status == LlamaNativeStatus.timedOut) {
      throw TimeoutException(result.error ?? 'Native inference timed out.');
    }
    if (result.status == LlamaNativeStatus.cancelled) {
      throw LlamaInferenceCancelledException(
        result.error ?? 'Native inference was cancelled.',
      );
    }
    throw LlamaNativeCallException(
      result.status,
      result.error ?? 'Native inference failed.',
    );
  }

  @override
  void loadAdapter({required String adapterPath, required double scale}) {
    final bindings = _bindings;
    final session = _session;
    if (_disposed || bindings == null || session == null) {
      throw StateError('LlamaNativeBackend is not ready.');
    }
    if (!path.isAbsolute(adapterPath) || !File(adapterPath).existsSync()) {
      throw LlamaRuntimeUnavailableException(
        'GGUF LoRA adapter path does not exist or is not absolute.',
      );
    }
    if (!scale.isFinite || scale < 0 || scale > 4) {
      throw RangeError.range(scale, 0, 4, 'scale');
    }
    bindings.loadAdapter(session, adapterPath: adapterPath, scale: scale);
  }

  @override
  void unloadAdapter() {
    final bindings = _bindings;
    final session = _session;
    if (_disposed || bindings == null || session == null) return;
    bindings.unloadAdapter(session);
  }

  @override
  void cancel() {
    final bindings = _bindings;
    final session = _session;
    if (!_disposed && bindings != null && session != null) {
      bindings.cancel(session);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final bindings = _bindings;
    final session = _session;
    _session = null;
    _bindings = null;
    if (bindings != null && session != null) {
      bindings.disposeSession(session);
    }
  }
}

final class LlamaRuntimeUnavailableException implements Exception {
  const LlamaRuntimeUnavailableException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message ($cause)';
}

final class LlamaInferenceCancelledException implements Exception {
  const LlamaInferenceCancelledException(this.message);
  final String message;

  @override
  String toString() => message;
}
