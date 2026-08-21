import 'package:archiveme_mobile/audio/playback_service.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_asset_resolver.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_backend.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_config.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_model_contract.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_service.dart';
import 'package:archiveme_mobile/services/offline_tts/sherpa_onnx_tts_backend.dart';
import 'package:archiveme_mobile/services/offline_tts/stub_offline_tts_backend.dart';

/// Creates a ready-to-use [OfflineTtsService] from bundled or sideloaded assets.
abstract final class OfflineTtsBootstrap {
  OfflineTtsBootstrap._();

  static Future<OfflineTtsService?> tryCreate({
    String? documentsBasePath,
    OfflineTtsBackend? backend,
    bool testMode = false,
  }) async {
    final paths = await OfflineTtsAssetResolver.resolve(
      documentsBasePath: documentsBasePath,
    );
    if (paths == null) {
      return null;
    }

    final service = OfflineTtsService(backend: backend);
    await service.loadModel(paths.toConfig());
    service.bindPlayback(
      OfflineTtsService.createPlayback(
        sampleRateHz: service.sampleRateHz == 0
            ? OfflineTtsModelContract.defaultSampleRateHz
            : service.sampleRateHz,
        testMode: testMode,
      ),
    );
    return service;
  }

  /// Test/dev helper when no ONNX bundle is present.
  static Future<OfflineTtsService> createStub({bool testMode = true}) async {
    final service = OfflineTtsService(backend: StubOfflineTtsBackend());
    await service.loadModel(
      const OfflineTtsConfig(
        vitsModelPath: '/tmp/stub-tts-model.onnx',
        tokensPath: '/tmp/stub-tts-tokens.txt',
      ),
    );
    service.bindPlayback(
      OfflineTtsService.createPlayback(
        sampleRateHz: 24000,
        testMode: testMode,
      ),
    );
    return service;
  }

  static bool get nativeRuntimeSupported => offlineTtsNativeRuntimeSupported();
}
