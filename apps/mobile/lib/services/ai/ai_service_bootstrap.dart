import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/services/ai/ai_service.dart';

/// Bootstraps the on-device Gemma AI stack when native LiteRT is available.
abstract final class AiServiceBootstrap {
  AiServiceBootstrap._();

  static Future<AIService?> tryCreate({
    ResourceGuard? resourceGuard,
    String? huggingFaceToken,
  }) async {
    if (!AIService.supportsOfflineSpeech && !_supportsInferenceOnly) {
      return null;
    }

    try {
      final service = await AIService.create(resourceGuard: resourceGuard);
      await service.ensureModelsInstalled(huggingFaceToken: huggingFaceToken);
      return service;
    } on Object {
      return null;
    }
  }

  /// Desktop / non-speech platforms can still run `.litertlm` extraction.
  static bool get _supportsInferenceOnly => true;
}
