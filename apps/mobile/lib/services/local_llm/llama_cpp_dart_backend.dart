import 'dart:async';

import 'package:archiveme_mobile/services/local_llm/local_llm_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';
import 'package:archiveme_mobile/services/local_llm/stub_local_llm_backend.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_worker_service.dart';

/// Routes llama.cpp inference through [LocalLlmWorkerService] so the UI isolate
/// only forwards SendPort messages to the managed llama.cpp worker.
final class LlamaCppDartBackend implements LocalLlmBackend {
  LlamaCppDartBackend({LocalLlmWorkerService? worker})
      : _worker = worker ?? LocalLlmWorkerService.instance {
    _worker.addModelUnloadedListener(_handleModelUnloaded);
  }

  final LocalLlmWorkerService _worker;

  var _loaded = false;

  void _handleModelUnloaded() {
    _loaded = false;
  }

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load(LocalLlmConfig config) async {
    config.validateModelPath();
    await _worker.loadModel(config);
    _loaded = true;
  }

  @override
  Stream<LocalLlmTokenEvent> streamCompletion(
    LocalLlmCompletionRequest request,
  ) {
    if (!_loaded) {
      throw StateError('LlamaCppDartBackend.load must be called first.');
    }
    return _worker.streamCompletion(request);
  }

  @override
  Future<void> dispose() async {
    _loaded = false;
    await _worker.disposeModel();
  }
}

/// Selects native llama.cpp worker backend or in-process stub for tests.
LocalLlmBackend createLocalLlmBackend() {
  if (localLlmNativeRuntimeSupported()) {
    return LlamaCppDartBackend();
  }
  return StubLocalLlmBackend();
}
