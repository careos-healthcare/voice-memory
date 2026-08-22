import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/reflections/data/reflection_model_contract.dart';

/// Converts voice transcripts into the fixed-size ONNX input tensor.
abstract final class ReflectionTranscriptProcessor {
  ReflectionTranscriptProcessor._();

  static const minTranscriptChars = 8;

  /// Number of elements in the flat `[1, maxSeqLen]` input tensor.
  static int get tensorElementCount => ReflectionModelContract.maxSeqLen;

  /// Builds hashed token ids from [transcript] for `OrtValue.fromList`.
  static Float32List buildInputTensor(String transcript) {
    final normalized = _normalize(transcript);
    final tokens = _tokenize(normalized);
    final out = Float32List(tensorElementCount);
    if (tokens.isEmpty) return out;

    for (var i = 0; i < tensorElementCount; i++) {
      if (i >= tokens.length) break;
      out[i] = tokens[i].toDouble();
    }
    return out;
  }

  static String _normalize(String transcript) {
    return transcript
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  static List<int> _tokenize(String normalized) {
    if (normalized.isEmpty) return const [];
    final words = normalized.split(' ');
    final buckets = <int>[];
    for (final word in words) {
      if (word.isEmpty) continue;
      buckets.add(_hashToken(word));
      if (buckets.length >= ReflectionModelContract.maxSeqLen) break;
    }
    return buckets;
  }

  static int _hashToken(String token) {
    var hash = 2166136261;
    for (final unit in token.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash % 32000 + 1;
  }

  /// Extracts a substring using normalized [0,1] span endpoints over UTF-16.
  static String spanSlice(String transcript, double startNorm, double endNorm) {
    final text = transcript.trim();
    if (text.isEmpty) return '';

    final start = (text.length * startNorm.clamp(0.0, 1.0)).floor();
    final end = (text.length * endNorm.clamp(0.0, 1.0)).ceil();
    if (end <= start || start >= text.length) return '';

    final sliceEnd = min(end, text.length);
    return text.substring(start, sliceEnd).trim();
  }

  /// Heuristic tension span when ONNX logits are unavailable.
  static ({double start, double end})? detectTensionSpan(String transcript) {
    final lower = transcript.toLowerCase();
    const markers = [
      ' but ',
      ' however ',
      ' even though ',
      ' on the other hand ',
      " i say ",
      " i keep ",
      ' want to but ',
      ' should but ',
    ];
    for (final marker in markers) {
      final index = lower.indexOf(marker);
      if (index < 0) continue;
      final start = index / transcript.length;
      final end = min(transcript.length, index + marker.length + 48) / transcript.length;
      return (start: start, end: end.clamp(0.0, 1.0));
    }
    return null;
  }

  /// Heuristic action span from imperative / intent phrases.
  static ({double start, double end})? detectActionSpan(String transcript) {
    final lower = transcript.toLowerCase();
    const markers = [
      ' i need to ',
      ' i will ',
      " i'll ",
      ' tomorrow i ',
      ' next i ',
      ' going to ',
      ' plan to ',
    ];
    for (final marker in markers) {
      final index = lower.indexOf(marker);
      if (index < 0) continue;
      final start = index / transcript.length;
      final end = min(transcript.length, index + marker.length + 64) / transcript.length;
      return (start: start, end: end.clamp(0.0, 1.0));
    }
    return null;
  }
}
