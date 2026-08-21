import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_types.dart';

/// Pluggable inference backend for [LocalLlmService].
abstract interface class LocalLlmBackend {
  Future<void> load(LocalLlmConfig config);

  Stream<LocalLlmTokenEvent> streamCompletion(LocalLlmCompletionRequest request);

  Future<void> dispose();

  bool get isLoaded;
}
