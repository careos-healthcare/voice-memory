import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/reflections/data/whisper_model_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// ONNX Runtime binding for quantized Whisper-tiny.en local STT.
class OnnxWhisperTranscription {
  OnnxWhisperTranscription._(
    this._session,
    this._inputName,
    this._outputName,
    this._outputKind,
  );

  final OrtSession _session;
  final String _inputName;
  final String _outputName;
  final _WhisperOutputKind _outputKind;

  static Future<OnnxWhisperTranscription?> tryCreateFromAsset({
    String assetPath = WhisperModelContract.defaultAssetPath,
  }) async {
    try {
      await rootBundle.load(assetPath);
    } on Object {
      return null;
    }

    final runtime = OnnxRuntime();
    final session = await runtime.createSessionFromAsset(assetPath);

    final inputName = session.inputNames.contains(
      WhisperModelContract.inputFeaturesName,
    )
        ? WhisperModelContract.inputFeaturesName
        : session.inputNames.contains(WhisperModelContract.melInputName)
        ? WhisperModelContract.melInputName
        : session.inputNames.first;

    _WhisperOutputKind kind;
    String outputName;
    if (session.outputNames.contains(WhisperModelContract.textOutputName)) {
      outputName = WhisperModelContract.textOutputName;
      kind = _WhisperOutputKind.text;
    } else if (session.outputNames.contains(
      WhisperModelContract.tokenIdsOutputName,
    )) {
      outputName = WhisperModelContract.tokenIdsOutputName;
      kind = _WhisperOutputKind.tokenIds;
    } else {
      outputName = session.outputNames.contains(
        WhisperModelContract.logitsOutputName,
      )
          ? WhisperModelContract.logitsOutputName
          : session.outputNames.first;
      kind = _WhisperOutputKind.logits;
    }

    return OnnxWhisperTranscription._(
      session,
      inputName,
      outputName,
      kind,
    );
  }

  bool get isAvailable => true;

  Future<WhisperTranscriptionResult> transcribeMel(Float32List melFlat) async {
    final input = await OrtValue.fromList(
      melFlat,
      [
        1,
        WhisperModelContract.nMelBins,
        WhisperModelContract.maxFrames,
      ],
    );

    try {
      final outputs = await _session.run({_inputName: input});
      final tensor = outputs[_outputName];
      if (tensor == null) {
        throw StateError('Whisper ONNX output "$_outputName" missing');
      }

      return switch (_outputKind) {
        _WhisperOutputKind.text => _decodeTextOutput(tensor),
        _WhisperOutputKind.tokenIds => _decodeTokenIds(tensor),
        _WhisperOutputKind.logits => _decodeLogits(tensor),
      };
    } finally {
      await input.dispose();
    }
  }

  Future<WhisperTranscriptionResult> transcribeFile(
    Float32List melFlat,
  ) => transcribeMel(melFlat);

  Future<WhisperTranscriptionResult> _decodeTextOutput(OrtValue tensor) async {
    final values = await tensor.asFlattenedList();
    await tensor.dispose();
    final text = values.whereType<String>().join('').trim();
    if (text.isNotEmpty) {
      return WhisperTranscriptionResult(
        transcript: text,
        confidence: 0.88,
        usedOnnx: true,
      );
    }
    return const WhisperTranscriptionResult(
      transcript: '',
      confidence: 0.0,
      usedOnnx: true,
    );
  }

  Future<WhisperTranscriptionResult> _decodeTokenIds(OrtValue tensor) async {
    final values = await tensor.asFlattenedList();
    await tensor.dispose();
    final ids = values.map((v) => (v as num).toInt()).toList(growable: false);
    return _tokensToResult(ids);
  }

  Future<WhisperTranscriptionResult> _decodeLogits(OrtValue tensor) async {
    final values = await tensor.asFlattenedList();
    await tensor.dispose();
    if (values.isEmpty) {
      return const WhisperTranscriptionResult(
        transcript: '',
        confidence: 0.0,
        usedOnnx: true,
      );
    }

    final vocab = _estimateVocabSize(values.length);
    final seqLen = values.length ~/ vocab;
    final tokenIds = <int>[];
    var logProbSum = 0.0;

    for (var t = 0; t < seqLen; t++) {
      var bestIdx = 0;
      var bestLogit = double.negativeInfinity;
      for (var v = 0; v < vocab; v++) {
        final logit = (values[t * vocab + v] as num).toDouble();
        if (logit > bestLogit) {
          bestLogit = logit;
          bestIdx = v;
        }
      }
      if (bestIdx == WhisperModelContract.endOfTextToken) break;
      if (bestIdx > 50257) continue;
      tokenIds.add(bestIdx);
      logProbSum += _softmaxConfidence(values, t * vocab, vocab, bestIdx);
    }

    final result = _tokensToResult(tokenIds);
    final avg = tokenIds.isEmpty ? 0.0 : logProbSum / tokenIds.length;
    return WhisperTranscriptionResult(
      transcript: result.transcript,
      confidence: avg.clamp(0.0, 1.0),
      usedOnnx: true,
    );
  }

  WhisperTranscriptionResult _tokensToResult(List<int> tokenIds) {
    final buffer = StringBuffer();
    for (final id in tokenIds) {
      if (id == WhisperModelContract.endOfTextToken) break;
      if (id >= 32 && id < 127) {
        buffer.writeCharCode(id);
      }
    }
    final text = buffer.toString().trim();
    return WhisperTranscriptionResult(
      transcript: text,
      confidence: text.isEmpty ? 0.0 : 0.82,
      usedOnnx: true,
    );
  }

  int _estimateVocabSize(int flatLength) {
    const candidates = [51865, 51864, 50258, 4096, 1024];
    for (final vocab in candidates) {
      if (flatLength % vocab == 0) return vocab;
    }
    return max(256, flatLength ~/ 64);
  }

  double _softmaxConfidence(
    List<dynamic> values,
    int offset,
    int vocab,
    int chosen,
  ) {
    var maxLogit = double.negativeInfinity;
    for (var i = 0; i < vocab; i++) {
      final logit = (values[offset + i] as num).toDouble();
      if (logit > maxLogit) maxLogit = logit;
    }
    var sum = 0.0;
    for (var i = 0; i < vocab; i++) {
      sum += exp((values[offset + i] as num).toDouble() - maxLogit);
    }
    final chosenProb =
        exp((values[offset + chosen] as num).toDouble() - maxLogit) / sum;
    return chosenProb;
  }
}

enum _WhisperOutputKind { text, tokenIds, logits }

class WhisperTranscriptionResult {
  const WhisperTranscriptionResult({
    required this.transcript,
    required this.confidence,
    required this.usedOnnx,
  });

  final String transcript;
  final double confidence;
  final bool usedOnnx;
}

/// Builds mel features from a WAV file and runs Whisper when loaded.
abstract interface class LocalSpeechToText {
  Future<WhisperTranscriptionResult?> transcribeWavFile(
    Float32List melFeatures,
  );
}

class OnnxWhisperSpeechToText implements LocalSpeechToText {
  OnnxWhisperSpeechToText(this._whisper);

  final OnnxWhisperTranscription _whisper;

  static Future<OnnxWhisperSpeechToText?> tryCreate() async {
    final whisper = await OnnxWhisperTranscription.tryCreateFromAsset();
    if (whisper == null) return null;
    return OnnxWhisperSpeechToText(whisper);
  }

  @override
  Future<WhisperTranscriptionResult?> transcribeWavFile(
    Float32List melFeatures,
  ) async {
    return _whisper.transcribeMel(melFeatures);
  }
}
