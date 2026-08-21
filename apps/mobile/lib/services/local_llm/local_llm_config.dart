import 'package:archiveme_mobile/services/local_llm/local_llm_model_contract.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Runtime configuration for loading a local GGUF model via llama.cpp.
final class LocalLlmConfig {
  const LocalLlmConfig({
    required this.modelPath,
    this.libraryPath,
    this.contextSize = LocalLlmModelContract.defaultContextSize,
    this.batchSize = LocalLlmModelContract.defaultBatchSize,
    this.microBatchSize = LocalLlmModelContract.defaultMicroBatchSize,
    this.threadCount = LocalLlmModelContract.defaultThreadCount,
    this.gpuLayers = 0,
    this.temperature = 0.2,
    this.topP = 0.9,
    this.maxTokens = LocalLlmModelContract.defaultMaxTokens,
    this.useChatMlFormat = true,
    this.requirePreferredQuantization = true,
    this.kvCacheQuantization = LlamaKvCacheType.q8_0,
  })  : assert(contextSize > 0, 'contextSize must be positive'),
        assert(batchSize > 0, 'batchSize must be positive'),
        assert(microBatchSize > 0, 'microBatchSize must be positive'),
        assert(threadCount > 0, 'threadCount must be positive'),
        assert(maxTokens > 0, 'maxTokens must be positive');

  final String modelPath;
  final String? libraryPath;
  final int contextSize;
  final int batchSize;
  final int microBatchSize;
  final int threadCount;
  final int gpuLayers;
  final double temperature;
  final double topP;
  final int maxTokens;
  final bool useChatMlFormat;
  final bool requirePreferredQuantization;
  final LlamaKvCacheType kvCacheQuantization;

  /// Mobile-safe defaults targeting [LocalLlmModelContract.preferredQuantization].
  factory LocalLlmConfig.mobile({
    required String modelPath,
    String? libraryPath,
    int contextSize = LocalLlmModelContract.defaultContextSize,
    int maxTokens = LocalLlmModelContract.defaultMaxTokens,
    bool requirePreferredQuantization = true,
    bool useChatMlFormat = true,
  }) {
    return LocalLlmConfig(
      modelPath: modelPath,
      libraryPath: libraryPath,
      contextSize: contextSize.clamp(512, LocalLlmModelContract.defaultMaxContextSize),
      batchSize: LocalLlmModelContract.defaultBatchSize.clamp(1, contextSize),
      microBatchSize: LocalLlmModelContract.defaultMicroBatchSize
          .clamp(1, LocalLlmModelContract.defaultBatchSize),
      threadCount: LocalLlmModelContract.defaultThreadCount,
      gpuLayers: 0,
      maxTokens: maxTokens.clamp(1, contextSize ~/ 2),
      useChatMlFormat: useChatMlFormat,
      requirePreferredQuantization: requirePreferredQuantization,
      kvCacheQuantization: LlamaKvCacheType.q8_0,
    );
  }

  void validateModelPath() {
    LocalLlmModelContract.assertLoadableGguf(
      modelPath,
      requirePreferred: requirePreferredQuantization,
    );
    if (contextSize > LocalLlmModelContract.defaultMaxContextSize) {
      throw LocalLlmModelException(
        'contextSize $contextSize exceeds mobile cap '
        '${LocalLlmModelContract.defaultMaxContextSize}.',
      );
    }
    if (maxTokens >= contextSize) {
      throw LocalLlmModelException(
        'maxTokens ($maxTokens) must stay below contextSize ($contextSize).',
      );
    }
  }

  ModelParams toModelParams() {
    return ModelParams()
      ..nGpuLayers = gpuLayers
      ..useMemorymap = true
      ..useMemoryLock = false
      ..vocabOnly = false
      ..checkTensors = false;
  }

  ContextParams toContextParams() {
    final effectiveBatch = batchSize.clamp(1, contextSize);
    final effectiveMicroBatch = microBatchSize.clamp(1, effectiveBatch);

    return ContextParams()
      ..nCtx = contextSize
      ..nBatch = effectiveBatch
      ..nUbatch = effectiveMicroBatch
      ..nSeqMax = 1
      ..nThreads = threadCount
      ..nThreadsBatch = threadCount
      ..nPredict = maxTokens
      ..typeK = kvCacheQuantization
      ..typeV = kvCacheQuantization
      ..offloadKqv = gpuLayers > 0
      ..opOffload = gpuLayers > 0
      ..flashAttention = LlamaFlashAttnType.disabled
      ..embeddings = false;
  }

  LlamaLoad toLoadCommand() {
    validateModelPath();

    final samplingParams = SamplerParams()
      ..temp = temperature
      ..topP = topP;

    return LlamaLoad(
      path: modelPath,
      modelParams: toModelParams(),
      contextParams: toContextParams(),
      samplingParams: samplingParams,
      verbose: false,
    );
  }
}
