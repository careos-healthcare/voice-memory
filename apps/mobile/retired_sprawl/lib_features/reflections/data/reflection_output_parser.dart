import 'dart:math';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_model_contract.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_transcript_processor.dart';

/// Maps raw ONNX logits into [ReflectionDto] and the offline knowledge graph.
abstract final class ReflectionOutputParser {
  ReflectionOutputParser._();

  static ReflectionDto toReflectionDto({
    required String transcript,
    required List<double> logits,
  }) {
    final padded = _padLogits(logits);
    final mood = _decodeMood(padded);
    final intensity = _decodeIntensity(padded);
    final themes = _decodeThemes(padded, transcript);

    final tensionSpan = _decodeSpan(
      transcript,
      padded[ReflectionModelContract.tensionSpanStartIndex],
      padded[ReflectionModelContract.tensionSpanEndIndex],
    );
    final actionSpan = _decodeSpan(
      transcript,
      padded[ReflectionModelContract.actionSpanStartIndex],
      padded[ReflectionModelContract.actionSpanEndIndex],
    );

    final tension = _finalizeField(tensionSpan) ??
        _heuristicTension(transcript, padded);
    final action = _finalizeField(actionSpan) ??
        _heuristicAction(transcript, padded);

    final exactLanguage = _extractExactLanguage(transcript);
    final observation = _extractConcreteObservation(transcript);
    final repeated = _extractRepeatedSignal(transcript, padded);
    final avoided = _extractAvoidedArea(transcript);
    final patterns = _decodePatternObservations(transcript, padded);

    return ReflectionDto(
      mood: mood,
      emotionalIntensity: intensity,
      recurringThemes: themes,
      exactLanguagePattern: exactLanguage,
      concreteObservation: observation,
      repeatedSignal: repeated,
      tensionOrContradiction: tension,
      avoidedOrVagueArea: avoided,
      nextSmallAction: action,
      patternObservations: patterns,
    );
  }

  static OfflineReflectionKnowledgeGraph buildKnowledgeGraph({
    required String entryId,
    required ReflectionDto reflection,
  }) {
    return OfflineReflectionKnowledgeGraph.fromReflectionFields(
      entryId: entryId,
      tensionOrContradiction: reflection.tensionOrContradiction,
      nextSmallAction: reflection.nextSmallAction,
      recurringThemes: reflection.recurringThemes,
    );
  }

  static List<double> _padLogits(List<double> logits) {
    final out = List<double>.filled(
      ReflectionModelContract.reflectionLogitWidth,
      0,
    );
    for (var i = 0; i < min(logits.length, out.length); i++) {
      out[i] = logits[i];
    }
    return out;
  }

  static String _decodeMood(List<double> logits) {
    var bestIdx = 0;
    var best = double.negativeInfinity;
    for (var i = 0; i < ReflectionModelContract.moodLogitCount; i++) {
      final score = logits[ReflectionModelContract.moodLogitStart + i];
      if (score > best) {
        best = score;
        bestIdx = i;
      }
    }
    if (best <= 0) return 'reflective';
    return ReflectionModelContract.moodLabels[bestIdx];
  }

  static int _decodeIntensity(List<double> logits) {
    final raw = logits[ReflectionModelContract.intensityLogitIndex];
    final scaled = (1 / (1 + exp(-raw))) * 10;
    return scaled.round().clamp(1, 10);
  }

  static List<String> _decodeThemes(List<double> logits, String transcript) {
    final themes = <String>[];
    for (var i = 0; i < ReflectionModelContract.themeLogitCount; i++) {
      final score = logits[ReflectionModelContract.themeLogitStart + i];
      if (score > 0.35) {
        themes.add(ReflectionModelContract.themeLabels[i]);
      }
    }
    if (themes.isNotEmpty) return themes.take(4).toList(growable: false);

    return _keywordThemes(transcript).take(4).toList(growable: false);
  }

  static List<String> _keywordThemes(String transcript) {
    final lower = transcript.toLowerCase();
    final hits = <String>[];
    for (final theme in ReflectionModelContract.themeLabels) {
      if (lower.contains(theme)) hits.add(theme);
    }
    return hits;
  }

  static String? _decodeSpan(
    String transcript,
    double startNorm,
    double endNorm,
  ) {
    if (startNorm <= 0 && endNorm <= 0) return null;
    if ((endNorm - startNorm) < 0.02) return null;
    final slice = ReflectionTranscriptProcessor.spanSlice(
      transcript,
      startNorm,
      endNorm,
    );
    return slice.isEmpty ? null : slice;
  }

  static String? _heuristicTension(String transcript, List<double> logits) {
    final span = ReflectionTranscriptProcessor.detectTensionSpan(transcript);
    if (span == null) return null;
    final slice = ReflectionTranscriptProcessor.spanSlice(
      transcript,
      span.start,
      span.end,
    );
    if (slice.length >= 8) return slice;
    final score = logits[ReflectionModelContract.tensionSpanStartIndex];
    return score > 0.2 ? _summarizeTension(transcript) : null;
  }

  static String? _heuristicAction(String transcript, List<double> logits) {
    final span = ReflectionTranscriptProcessor.detectActionSpan(transcript);
    if (span != null) {
      final slice = ReflectionTranscriptProcessor.spanSlice(
        transcript,
        span.start,
        span.end,
      );
      if (slice.length >= 6 && slice.length <= 80) return slice;
    }
    final score = logits[ReflectionModelContract.actionSpanStartIndex];
    return score > 0.2 ? _summarizeAction(transcript) : null;
  }

  static String? _finalizeField(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.length < 6) return null;
    return trimmed.length > 160 ? '${trimmed.substring(0, 157)}…' : trimmed;
  }

  static String _extractExactLanguage(String transcript) {
    final quoted = RegExp(r'"([^"]{4,80})"').firstMatch(transcript);
    if (quoted != null) return quoted.group(1)!;

    final words = transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final snippet = words.take(12).join(' ');
    return snippet.length > 80 ? '${snippet.substring(0, 77)}…' : snippet;
  }

  static String _extractConcreteObservation(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.length <= 140) return trimmed;
    return '${trimmed.substring(0, 137).trim()}…';
  }

  static String _extractRepeatedSignal(String transcript, List<double> logits) {
    final words = transcript.toLowerCase().split(RegExp(r'\s+'));
    final counts = <String, int>{};
    for (final word in words) {
      if (word.length < 4) continue;
      counts[word] = (counts[word] ?? 0) + 1;
    }
    final repeated = counts.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (repeated.isNotEmpty) {
      return 'Repeated "${repeated.first.key}" in this entry.';
    }

    final patternScore = logits.sublist(
      ReflectionModelContract.patternLogitStart,
      ReflectionModelContract.patternLogitStart +
          ReflectionModelContract.patternLogitCount,
    );
    if (patternScore.any((score) => score > 0.4)) {
      return 'Language loops without resolving in this entry.';
    }
    return 'Nothing repeated clearly in this entry.';
  }

  static String? _extractAvoidedArea(String transcript) {
    final lower = transcript.toLowerCase();
    const vague = [
      'that thing',
      'that situation',
      'you know',
      'kind of',
      'sort of',
      'stuff',
      'something',
    ];
    for (final marker in vague) {
      if (lower.contains(marker)) {
        return 'Circles around something without naming it directly.';
      }
    }
    return null;
  }

  static List<String> _decodePatternObservations(
    String transcript,
    List<double> logits,
  ) {
    final patterns = <String>[];
    for (var i = 0; i < ReflectionModelContract.patternLogitCount; i++) {
      final score =
          logits[ReflectionModelContract.patternLogitStart + i];
      if (score <= 0.45) continue;
      patterns.add(_patternLabel(i));
    }
    if (patterns.isNotEmpty) return patterns;

    if (ReflectionTranscriptProcessor.detectTensionSpan(transcript) != null) {
      patterns.add('Pull-between language detected.');
    }
    return patterns;
  }

  static String _patternLabel(int index) => switch (index) {
    0 => 'Hedging increases toward the end.',
    1 => 'Same concern restated with different words.',
    2 => 'Future intent without a named first step.',
    3 => 'Contrast marker ("but") shifts the sentence.',
    4 => 'Vague referent instead of a concrete noun.',
    5 => 'Self-correction mid-thought.',
    6 => 'Intensity rises without resolution.',
    _ => 'Repeated emotional cue.',
  };

  static String? _summarizeTension(String transcript) {
    final span = ReflectionTranscriptProcessor.detectTensionSpan(transcript);
    if (span == null) return null;
    return ReflectionTranscriptProcessor.spanSlice(
      transcript,
      span.start,
      span.end,
    );
  }

  static String? _summarizeAction(String transcript) {
    final span = ReflectionTranscriptProcessor.detectActionSpan(transcript);
    if (span == null) return null;
    return ReflectionTranscriptProcessor.spanSlice(
      transcript,
      span.start,
      span.end,
    );
  }
}
