import 'package:archiveme_mobile/services/local_llm/local_llm_config.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_worker_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalLlmWorkerLoadPolicy', () {
    test('efficiencyCoreThreadCount uses half of CPUs capped at 2', () {
      expect(LocalLlmWorkerLoadPolicy.efficiencyCoreThreadCount(processorCount: 8), 2);
      expect(LocalLlmWorkerLoadPolicy.efficiencyCoreThreadCount(processorCount: 4), 2);
      expect(LocalLlmWorkerLoadPolicy.efficiencyCoreThreadCount(processorCount: 3), 1);
      expect(LocalLlmWorkerLoadPolicy.efficiencyCoreThreadCount(processorCount: 1), 1);
    });

    test('toWorkerLoadCommand caps context and threads for mobile worker', () {
      final load = LocalLlmWorkerLoadPolicy.toWorkerLoadCommand(
        LocalLlmConfig.mobile(
          modelPath: '/tmp/mobile-q4_k_m.gguf',
          contextSize: 2048,
          maxTokens: 512,
          requirePreferredQuantization: false,
        ),
      );

      expect(load.contextParams.nCtx, lessThanOrEqualTo(1024));
      expect(load.contextParams.nThreads, lessThanOrEqualTo(2));
      expect(load.contextParams.nThreadsBatch, load.contextParams.nThreads);
      expect(load.modelParams.nGpuLayers, 0);
      expect(load.modelParams.useMemorymap, isTrue);
      expect(load.modelParams.useMemoryLock, isFalse);
    });
  });
}
