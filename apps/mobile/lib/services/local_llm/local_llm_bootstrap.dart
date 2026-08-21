import 'package:archiveme_mobile/services/local_llm/llama_cpp_dart_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_asset_resolver.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_backend.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_model_contract.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_service.dart';
import 'package:archiveme_mobile/services/local_llm/model_download_service.dart';
import 'package:archiveme_mobile/services/local_llm/stub_local_llm_backend.dart';

/// Creates a ready-to-use [LocalLlmService] from a downloaded or sideloaded GGUF.
abstract final class LocalLlmBootstrap {
  LocalLlmBootstrap._();

  /// Mobile production config shared by every on-device LLM consumer.
  ///
  /// Prompts are pre-formatted by callers (e.g. ChatML for audio structuring);
  /// the worker loads with [useChatMlFormat] disabled so prompts are not wrapped twice.
  static LocalLlmConfig productionConfig({
    required String modelPath,
    String? libraryPath,
    bool requirePreferredQuantization = true,
  }) {
    return LocalLlmConfig.mobile(
      modelPath: modelPath,
      libraryPath: libraryPath,
      requirePreferredQuantization: requirePreferredQuantization,
      useChatMlFormat: false,
      maxTokens: LocalLlmModelContract.sharedProductionMaxTokens,
    );
  }

  static Future<LocalLlmService?> tryCreate({
    ModelDownloadService? modelDownloadService,
    String? documentsBasePath,
    String? modelPathOverride,
    String? libraryPath,
    LocalLlmBackend? backend,
    bool requirePreferredQuantization = true,
  }) async {
    final resolved = await LocalLlmAssetResolver.resolve(
      modelDownloadService: modelDownloadService,
      documentsBasePath: documentsBasePath,
      modelPathOverride: modelPathOverride,
    );
    if (resolved == null) {
      return null;
    }

    final service = LocalLlmService(backend: backend);
    await service.loadModel(
      productionConfig(
        modelPath: resolved.modelPath,
        libraryPath: libraryPath,
        requirePreferredQuantization: requirePreferredQuantization,
      ),
    );
    return service;
  }

  /// Test/dev helper when no GGUF bundle is present.
  static Future<LocalLlmService> createStub() async {
    const stubPath = '/tmp/stub-model-q4_k_m.gguf';
    final service = LocalLlmService(backend: StubLocalLlmBackend());
    await service.loadModel(
      productionConfig(
        modelPath: stubPath,
        requirePreferredQuantization: false,
      ),
    );
    return service;
  }

  static bool get nativeRuntimeSupported => localLlmNativeRuntimeSupported();
}
