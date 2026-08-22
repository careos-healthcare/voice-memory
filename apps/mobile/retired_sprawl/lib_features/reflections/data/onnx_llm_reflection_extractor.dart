import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/reflections/data/llm_reflection_model_contract.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_heuristic_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/features/reflections/data/onnx_reflection_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_output_parser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Result of local LLM / logits reflection extraction.
class LocalReflectionExtractionResult {
  const LocalReflectionExtractionResult({
    required this.reflection,
    required this.knowledgeGraph,
    required this.confidence,
    required this.usedOnnx,
    required this.usedGenerativeLlm,
  });

  final ReflectionDto reflection;
  final OfflineReflectionKnowledgeGraph knowledgeGraph;
  final double confidence;
  final bool usedOnnx;
  final bool usedGenerativeLlm;
}

/// Generative LLM ONNX extractor with logits-model and heuristic fallback.
class OnnxLlmReflectionExtractor {
  OnnxLlmReflectionExtractor._(
    this._session,
    this._inputName,
    this._outputName,
  );

  final OrtSession _session;
  final String _inputName;
  final String _outputName;

  static Future<OnnxLlmReflectionExtractor?> tryCreateFromAsset({
    String assetPath = LlmReflectionModelContract.defaultAssetPath,
  }) async {
    try {
      await rootBundle.load(assetPath);
    } on Object {
      return null;
    }

    final runtime = OnnxRuntime();
    final session = await runtime.createSessionFromAsset(assetPath);
    final inputName = session.inputNames.contains(
      LlmReflectionModelContract.inputIdsName,
    )
        ? LlmReflectionModelContract.inputIdsName
        : session.inputNames.first;
    final outputName = session.outputNames.contains(
      LlmReflectionModelContract.generatedIdsOutputName,
    )
        ? LlmReflectionModelContract.generatedIdsOutputName
        : session.outputNames.contains(
            LlmReflectionModelContract.logitsOutputName,
          )
        ? LlmReflectionModelContract.logitsOutputName
        : session.outputNames.first;

    return OnnxLlmReflectionExtractor._(session, inputName, outputName);
  }

  Future<LocalReflectionExtractionResult> extract({
    required String transcript,
    required String entryId,
  }) async {
    final prompt =
        '${LlmReflectionModelContract.reflectionJsonPrompt}\n$transcript';
    final inputIds = _tokenizePrompt(prompt);
    final input = await OrtValue.fromList(
      Int64List.fromList(inputIds),
      [1, inputIds.length],
    );

    try {
      final outputs = await _session.run({_inputName: input});
      final tensor = outputs[_outputName];
      if (tensor == null) {
        throw StateError('LLM ONNX output "$_outputName" missing');
      }
      final generated = await _decodeGeneratedText(tensor);
      await tensor.dispose();

      final parsed = _parseReflectionJson(generated, transcript);
      if (parsed != null) {
        return LocalReflectionExtractionResult(
          reflection: parsed,
          knowledgeGraph: ReflectionOutputParser.buildKnowledgeGraph(
            entryId: entryId,
            reflection: parsed,
          ),
          confidence: 0.90,
          usedOnnx: true,
          usedGenerativeLlm: true,
        );
      }
    } finally {
      await input.dispose();
    }

    return _fallbackExtract(transcript: transcript, entryId: entryId);
  }

  Future<String> _decodeGeneratedText(OrtValue tensor) async {
    final values = await tensor.asFlattenedList();
    if (values.isEmpty) return '';

    if (values.first is String) {
      return values.whereType<String>().join('');
    }

    final buffer = StringBuffer();
    for (final value in values) {
      final id = (value as num).toInt();
      if (id <= 0 || id >= 32000) continue;
      if (id >= 32 && id < 127) buffer.writeCharCode(id);
    }
    return buffer.toString();
  }

  ReflectionDto? _parseReflectionJson(String generated, String transcript) {
    final start = generated.indexOf('{');
    final end = generated.lastIndexOf('}');
    if (start < 0 || end <= start) return null;

    try {
      final map = jsonDecode(generated.substring(start, end + 1))
          as Map<String, dynamic>;
      return ReflectionDto(
        mood: map['mood'] as String? ?? 'reflective',
        emotionalIntensity: ((map['emotionalIntensity'] as num?) ?? 5)
            .toInt()
            .clamp(1, 10),
        recurringThemes: (map['recurringThemes'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
        tensionOrContradiction:
            _optionalString(map['tensionOrContradiction']),
        nextSmallAction: _optionalString(map['nextSmallAction']),
        exactLanguagePattern: transcript.length > 80
            ? '${transcript.substring(0, 77)}…'
            : transcript,
        concreteObservation: transcript.length > 140
            ? '${transcript.substring(0, 137).trim()}…'
            : transcript,
        repeatedSignal: 'Extracted on-device from this entry.',
      );
    } on Object {
      return null;
    }
  }

  String? _optionalString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<int> _tokenizePrompt(String prompt) {
    final ids = <int>[1];
    for (final unit in prompt.codeUnits.take(
      LlmReflectionModelContract.maxPromptTokens - 2,
    )) {
      ids.add(unit.clamp(0, 32000));
    }
    ids.add(2);
    return ids;
  }

  Future<LocalReflectionExtractionResult> _fallbackExtract({
    required String transcript,
    required String entryId,
  }) async {
    final source = await LocalReflectionDataSource.create();
    final result = await source.inferFromTranscript(
      transcript: transcript,
      entryId: entryId,
    );
    return LocalReflectionExtractionResult(
      reflection: result.reflection,
      knowledgeGraph: result.knowledgeGraph,
      confidence: result.usedOnnx ? 0.84 : 0.72,
      usedOnnx: result.usedOnnx,
      usedGenerativeLlm: false,
    );
  }
}

/// Unified local reflection extraction — prefers generative LLM, then logits ONNX.
class LocalReflectionExtractor {
  LocalReflectionExtractor({
    OnnxLlmReflectionExtractor? llm,
    LocalReflectionDataSource? logitsSource,
  }) : _llm = llm,
       _logitsSource = logitsSource;

  final OnnxLlmReflectionExtractor? _llm;
  final LocalReflectionDataSource? _logitsSource;

  static Future<LocalReflectionExtractor> create() async {
    final llm = await OnnxLlmReflectionExtractor.tryCreateFromAsset();
    if (llm != null) {
      return LocalReflectionExtractor(llm: llm);
    }

    final logitsOnnx = await OnnxReflectionInference.tryCreateFromAsset();
    final source = LocalReflectionDataSource(
      inference: logitsOnnx ?? const LocalReflectionHeuristicInference(),
    );
    return LocalReflectionExtractor(logitsSource: source);
  }

  Future<LocalReflectionExtractionResult> extract({
    required String transcript,
    required String entryId,
  }) async {
    final llm = _llm;
    if (llm != null) {
      return llm.extract(transcript: transcript, entryId: entryId);
    }

    final source =
        _logitsSource ?? await LocalReflectionDataSource.create();
    final result = await source.inferFromTranscript(
      transcript: transcript,
      entryId: entryId,
    );
    return LocalReflectionExtractionResult(
      reflection: result.reflection,
      knowledgeGraph: result.knowledgeGraph,
      confidence: result.usedOnnx ? 0.84 : 0.72,
      usedOnnx: result.usedOnnx,
      usedGenerativeLlm: false,
    );
  }
}
