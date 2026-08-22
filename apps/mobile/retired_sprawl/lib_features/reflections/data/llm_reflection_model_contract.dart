/// Bundled lightweight LLM (Phi-3.5-mini / Llama-3.2-1B INT4 ONNX) contract.
///
/// Export to [defaultAssetPath] with generative JSON extraction for
/// [ReflectionDto] fields. Falls back to [ReflectionModelContract] logits
/// extractor when absent.
abstract final class LlmReflectionModelContract {
  LlmReflectionModelContract._();

  static const defaultAssetPath =
      'assets/models/llm_reflection_extractor_int4.onnx';

  static const inputIdsName = 'input_ids';
  static const attentionMaskName = 'attention_mask';
  static const logitsOutputName = 'logits';
  static const generatedIdsOutputName = 'generated_ids';

  static const maxPromptTokens = 512;
  static const maxGeneratedTokens = 256;

  static const reflectionJsonPrompt = '''
Extract reflection JSON from the journal transcript.
Return ONLY valid JSON with keys:
mood, emotionalIntensity, recurringThemes, tensionOrContradiction, nextSmallAction.
Transcript:
''';
}
