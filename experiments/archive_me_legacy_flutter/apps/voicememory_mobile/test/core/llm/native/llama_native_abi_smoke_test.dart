import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/llm/native/llama_inference_session.dart';

void main() {
  final enabled =
      Platform.environment['ARCHIVEME_RUN_LLAMA_FFI']?.toLowerCase() == 'true';
  final modelPath = Platform.environment['ARCHIVEME_LLAMA_GGUF_PATH'];
  final canRun = enabled && modelPath != null && modelPath.isNotEmpty;

  test(
    'loads the native ABI and completes with a tiny GGUF',
    () async {
      final session = LlamaInferenceSession();
      addTearDown(session.dispose);

      await session.warmUp(modelPath: modelPath!, contextSize: 512, threads: 2);
      final result = await session.infer(
        'I met Maya in London and felt hopeful.',
        maxTokens: 256,
        timeout: const Duration(seconds: 30),
      );

      expect(result.isValid, isTrue);
      expect(result.inferenceDriver, 'llama.cpp');
    },
    skip: canRun
        ? false
        : 'Set ARCHIVEME_RUN_LLAMA_FFI=true and '
              'ARCHIVEME_LLAMA_GGUF_PATH=/absolute/model.gguf.',
  );
}
