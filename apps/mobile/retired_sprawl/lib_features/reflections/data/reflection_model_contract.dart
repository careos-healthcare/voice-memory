/// Bundled ONNX reflection extractor contract.
///
/// Export a distilled model to `assets/models/reflection_extractor.onnx` with:
/// - Input `input_ids`: float32 `[1, maxSeqLen]` hashed token ids (see
///   [ReflectionTranscriptProcessor]).
/// - Output `reflection_logits`: float32 `[1, reflectionLogitWidth]` — parsed by
///   [ReflectionOutputParser].
abstract final class ReflectionModelContract {
  ReflectionModelContract._();

  static const defaultAssetPath = 'assets/models/reflection_extractor.onnx';
  static const inputName = 'input_ids';
  static const outputName = 'reflection_logits';

  static const maxSeqLen = 128;
  static const reflectionLogitWidth = 512;

  /// Mood label order — argmax over [moodLogitStart, moodLogitEnd).
  static const moodLogitStart = 0;
  static const moodLogitCount = 16;
  static const moodLabels = [
    'calm',
    'focused',
    'tired',
    'anxious',
    'hopeful',
    'frustrated',
    'grateful',
    'uncertain',
    'energized',
    'overwhelmed',
    'reflective',
    'irritated',
    'content',
    'restless',
    'low',
    'mixed',
  ];

  static const intensityLogitIndex = 16;

  static const themeLogitStart = 17;
  static const themeLogitCount = 32;

  static const themeLabels = [
    'work',
    'health',
    'relationships',
    'family',
    'sleep',
    'money',
    'growth',
    'creativity',
    'boundaries',
    'time',
    'stress',
    'habits',
    'identity',
    'loss',
    'decision',
    'conflict',
    'rest',
    'career',
    'parenting',
    'friendship',
    'body',
    'home',
    'learning',
    'purpose',
    'grief',
    'change',
    'trust',
    'control',
    'loneliness',
    'joy',
    'anger',
    'planning',
  ];

  /// Normalized UTF-16 span endpoints in [0, 1] for tension extraction.
  static const tensionSpanStartIndex = 49;
  static const tensionSpanEndIndex = 50;

  /// Normalized UTF-16 span endpoints for next-step extraction.
  static const actionSpanStartIndex = 51;
  static const actionSpanEndIndex = 52;

  static const patternLogitStart = 53;
  static const patternLogitCount = 8;
}
