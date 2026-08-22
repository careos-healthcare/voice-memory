import 'dart:typed_data';

import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// ONNX Runtime binding for bundled reflection encoders (384-d output).
class OnnxReflectionEmbeddingInference implements ReflectionEmbeddingInference {
  OnnxReflectionEmbeddingInference._(
    this._session,
    this._inputName,
    this._outputName,
  );

  final OrtSession _session;
  final String _inputName;
  final String _outputName;

  static Future<OnnxReflectionEmbeddingInference?> tryCreateFromAsset({
    String assetPath = ReflectionEmbeddingContract.defaultAssetPath,
    String inputName = ReflectionEmbeddingContract.inputName,
    String outputName = ReflectionEmbeddingContract.outputName,
  }) async {
    try {
      await rootBundle.load(assetPath);
    } on Object {
      return null;
    }

    final runtime = OnnxRuntime();
    final session = await runtime.createSessionFromAsset(assetPath);
    final resolvedInput = session.inputNames.contains(inputName)
        ? inputName
        : session.inputNames.first;
    final resolvedOutput = session.outputNames.contains(outputName)
        ? outputName
        : session.outputNames.first;
    return OnnxReflectionEmbeddingInference._(
      session,
      resolvedInput,
      resolvedOutput,
    );
  }

  @override
  Future<List<double>> embed(Float32List inputTensor) async {
    if (inputTensor.length != ReflectionTextProcessor.tensorElementCount) {
      throw ArgumentError.value(
        inputTensor.length,
        'inputTensor.length',
        'expected ${ReflectionTextProcessor.tensorElementCount}',
      );
    }

    final inputValue = await OrtValue.fromList(
      inputTensor,
      [1, ReflectionEmbeddingContract.maxSeqLen],
    );

    final outputs = await _session.run({_inputName: inputValue});
    final outputTensor = outputs[_outputName];
    if (outputTensor == null) {
      await inputValue.dispose();
      throw StateError('ONNX output "$_outputName" missing from session run');
    }

    final raw = await outputTensor.asFlattenedList();
    final flat = raw
        .map((value) => (value as num).toDouble())
        .toList(growable: false);

    await inputValue.dispose();
    await outputTensor.dispose();

    if (flat.length < ReflectionEmbeddingContract.dimensions) {
      throw StateError(
        'ONNX reflection embedding width ${flat.length} < '
        '${ReflectionEmbeddingContract.dimensions}',
      );
    }

    return ReflectionTextProcessor.l2Normalize(
      flat.take(ReflectionEmbeddingContract.dimensions).toList(growable: false),
    );
  }
}
