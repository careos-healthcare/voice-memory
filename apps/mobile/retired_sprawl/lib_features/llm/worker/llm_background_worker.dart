import 'dart:async';

import 'package:archiveme_mobile/features/llm/domain/llm_feed_card_state.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_knowledge_graph_extractor.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_service.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_service.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_worker_service.dart';

typedef ResolveLocalLlm = Future<LocalLlmService?> Function();

/// Runs local GGUF inference in a dedicated background isolate via llama.cpp FFI.
///
/// [LocalLlmWorkerService] owns the [Isolate.spawn] handshake and pipes token
/// events back to the UI isolate through SendPort/ReceivePort IPC.
class LlmBackgroundWorker {
  LlmBackgroundWorker({
    LocalLlmWorkerService? workerService,
    LocalLlmService? llmService,
  }) : _workerService = workerService ?? LocalLlmWorkerService.instance,
       _llmService = llmService ?? LocalLlmService();

  final LocalLlmWorkerService _workerService;
  final LocalLlmService _llmService;

  bool get isLoaded => _llmService.isLoaded;

  Future<void> ensureStarted() => _workerService.ensureStarted();

  /// Attaches an externally loaded [LocalLlmService] (e.g. from [AppServices]).
  LlmBackgroundWorker attachLoadedService(LocalLlmService service) {
    return LlmBackgroundWorker(
      workerService: _workerService,
      llmService: service,
    );
  }

  Stream<LlmStreamToken> streamKnowledgeGraphExtraction({
    required String captureId,
    required String entryId,
    required String transcript,
    List<String> existingThemes = const [],
    int? maxTokens,
  }) {
    final controller = StreamController<LlmStreamToken>();
    unawaited(
      _runStream(
        controller: controller,
        captureId: captureId,
        entryId: entryId,
        transcript: transcript,
        existingThemes: existingThemes,
        maxTokens: maxTokens,
      ),
    );
    return controller.stream;
  }

  Future<void> _runStream({
    required StreamController<LlmStreamToken> controller,
    required String captureId,
    required String entryId,
    required String transcript,
    required List<String> existingThemes,
    int? maxTokens,
  }) async {
    if (!_llmService.isLoaded) {
      controller.addError(StateError('Local LLM is not loaded.'));
      await controller.close();
      return;
    }

    final prompt = LocalLlmKnowledgeGraphExtractor.buildPrompt(
      entryId: entryId,
      transcript: transcript,
      existingThemes: existingThemes,
    );

    final buffer = StringBuffer();
    try {
      await for (final token in _llmService.streamCompletion(
        LocalLlmCompletionRequest(
          prompt: prompt,
          temperature: 0.2,
          maxTokens: maxTokens,
          systemPrompt:
              'You are a structured extraction engine. Output valid JSON only.',
        ),
      )) {
        buffer.write(token);
        if (controller.isClosed) break;
        controller.add(
          LlmStreamToken(
            captureId: captureId,
            token: token,
            accumulatedText: buffer.toString(),
          ),
        );
      }

      if (!controller.isClosed) {
        controller.add(
          LlmStreamToken(
            captureId: captureId,
            token: '',
            isFinal: true,
            accumulatedText: buffer.toString(),
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      if (!controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    } finally {
      await controller.close();
    }
  }
}
