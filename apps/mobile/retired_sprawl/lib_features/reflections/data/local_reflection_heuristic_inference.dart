import 'dart:typed_data';

import 'package:archiveme_mobile/features/reflections/data/reflection_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_model_contract.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_transcript_processor.dart';

/// Deterministic on-device fallback when the bundled ONNX model is absent.
///
/// Produces logits compatible with [ReflectionOutputParser] using transcript
/// heuristics only — no network calls.
///
/// Mood and emotional intensity are deliberately left unset. Nothing derivable
/// from a transcript hash carries either signal, and a synthesised number is
/// indistinguishable from a measured one once it reaches a surface.
class LocalReflectionHeuristicInference implements ReflectionInference {
  const LocalReflectionHeuristicInference();

  @override
  Future<List<double>> runReflectionLogits(Float32List inputTensor) async {
    return List<double>.filled(
      ReflectionModelContract.reflectionLogitWidth,
      0,
    );
  }

  /// Builds logits using full [transcript] text (heuristic path).
  Future<List<double>> runForTranscript(String transcript) async {
    final tensor = ReflectionTranscriptProcessor.buildInputTensor(transcript);
    final logits = await runReflectionLogits(tensor);

    final lower = transcript.toLowerCase();
    _applyThemeHints(logits, lower);
    _applySpanHints(logits, transcript);
    _applyPatternHints(logits, lower);
    return logits;
  }

  void _applyThemeHints(List<double> logits, String lower) {
    for (var i = 0; i < ReflectionModelContract.themeLogitCount; i++) {
      final theme = ReflectionModelContract.themeLabels[i];
      if (lower.contains(theme)) {
        logits[ReflectionModelContract.themeLogitStart + i] = 0.9;
      }
    }
  }

  void _applySpanHints(List<double> logits, String transcript) {
    final tension = ReflectionTranscriptProcessor.detectTensionSpan(transcript);
    if (tension != null) {
      logits[ReflectionModelContract.tensionSpanStartIndex] = tension.start;
      logits[ReflectionModelContract.tensionSpanEndIndex] = tension.end;
    }

    final action = ReflectionTranscriptProcessor.detectActionSpan(transcript);
    if (action != null) {
      logits[ReflectionModelContract.actionSpanStartIndex] = action.start;
      logits[ReflectionModelContract.actionSpanEndIndex] = action.end;
    }
  }

  void _applyPatternHints(List<double> logits, String lower) {
    if (lower.contains(' but ')) {
      logits[ReflectionModelContract.patternLogitStart + 3] = 0.8;
    }
    if (lower.contains('maybe') || lower.contains('kind of')) {
      logits[ReflectionModelContract.patternLogitStart + 4] = 0.75;
    }
  }
}
