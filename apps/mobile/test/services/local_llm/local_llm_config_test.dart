import 'package:archiveme_mobile/services/local_llm/local_llm.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() {
  group('LocalLlmModelContract', () {
    test('accepts Q4_K_M filenames', () {
      expect(
        LocalLlmModelContract.isHeavilyQuantizedGguf(
          '/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
        ),
        isTrue,
      );
      expect(
        LocalLlmModelContract.matchesPreferredQuantization(
          '/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
        ),
        isTrue,
      );
    });

    test('rejects full-precision filenames', () {
      expect(
        () => LocalLlmModelContract.assertLoadableGguf(
          '/models/llama-f16.gguf',
        ),
        throwsA(isA<LocalLlmModelException>()),
      );
    });
  });

  group('LocalLlmBootstrap', () {
    test('productionConfig disables worker ChatML wrapping and raises token cap', () {
      final config = LocalLlmBootstrap.productionConfig(
        modelPath: '/tmp/mobile-q4_k_m.gguf',
        requirePreferredQuantization: false,
      );

      expect(config.useChatMlFormat, isFalse);
      expect(config.maxTokens, LocalLlmModelContract.sharedProductionMaxTokens);
    });
  });

  group('LocalLlmConfig mobile load command', () {
    test('builds capped ModelParams and ContextParams for llama.cpp', () {
      final config = LocalLlmConfig.mobile(
        modelPath: '/tmp/mobile-q4_k_m.gguf',
        contextSize: 2048,
        maxTokens: 256,
        requirePreferredQuantization: false,
      );

      final modelParams = config.toModelParams();
      expect(modelParams.nGpuLayers, 0);
      expect(modelParams.useMemorymap, isTrue);
      expect(modelParams.useMemoryLock, isFalse);

      final contextParams = config.toContextParams();
      expect(contextParams.nCtx, 2048);
      expect(contextParams.nBatch, lessThanOrEqualTo(2048));
      expect(contextParams.nUbatch, lessThanOrEqualTo(contextParams.nBatch));
      expect(contextParams.nThreads, LocalLlmModelContract.defaultThreadCount);
      expect(contextParams.nPredict, 256);
      expect(contextParams.typeK, LlamaKvCacheType.q8_0);
      expect(contextParams.typeV, LlamaKvCacheType.q8_0);
      expect(contextParams.offloadKqv, isFalse);
      expect(contextParams.opOffload, isFalse);
    });

    test('toLoadCommand wires llama.cpp load payload', () {
      final load = LocalLlmConfig.mobile(
        modelPath: '/tmp/mobile-q4_k_m.gguf',
        requirePreferredQuantization: false,
      ).toLoadCommand();

      expect(load.path, '/tmp/mobile-q4_k_m.gguf');
      expect(load.modelParams.nGpuLayers, 0);
      expect(load.contextParams.nCtx, LocalLlmModelContract.defaultContextSize);
      expect(load.samplingParams.temp, 0.2);
    });

    test('clamps context windows above mobile cap', () {
      final config = LocalLlmConfig.mobile(
        modelPath: '/tmp/mobile-q4_k_m.gguf',
        contextSize: 8192,
        requirePreferredQuantization: false,
      );

      expect(config.contextSize, LocalLlmModelContract.defaultMaxContextSize);
      expect(() => config.validateModelPath(), returnsNormally);
    });
  });
}
