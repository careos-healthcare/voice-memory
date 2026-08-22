import 'dart:typed_data';

import 'package:archiveme_mobile/features/reflections/data/reflection_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_model_contract.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_transcript_processor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// ONNX Runtime binding for the bundled reflection extractor model.
class OnnxReflectionInference implements ReflectionInference {
  OnnxReflectionInference._(
    this._session,
    this._inputName,
    this._outputName,
  );

  final OrtSession _session;
  final String _inputName;
  final String _outputName;

  /// Loads [assetPath] from the Flutter asset bundle. Returns null when absent.
  static Future<OnnxReflectionInference?> tryCreateFromAsset({
    String assetPath = ReflectionModelContract.defaultAssetPath,
    String inputName = ReflectionModelContract.inputName,
    String outputName = ReflectionModelContract.outputName,
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
    return OnnxReflectionInference._(
      session,
      resolvedInput,
      resolvedOutput,
    );
  }

  @override
  Future<List<double>> runReflectionLogits(Float32List inputTensor) async {
    if (inputTensor.length != ReflectionTranscriptProcessor.tensorElementCount) {
      throw ArgumentError.value(
        inputTensor.length,
        'inputTensor.length',
        'expected ${ReflectionTranscriptProcessor.tensorElementCount}',
      );
    }

    final inputValue = await OrtValue.fromList(
      inputTensor,
      [1, ReflectionModelContract.maxSeqLen],
    );

    final outputs = await _session.run({_inputName: inputValue});
    final outputTensor = outputs[_outputName];
    if (outputTensor == null) {
      await inputValue.dispose();
      throw StateError('ONNX output "$_outputName" missing from session run');
    }

    final raw = await outputTensor.asFlattenedList();
    final logits = raw
        .map((value) => (value as num).toDouble())
        .toList(growable: false);

    await inputValue.dispose();
    await outputTensor.dispose();

    if (logits.length < ReflectionModelContract.reflectionLogitWidth) {
      throw StateError(
        'ONNX reflection logits ${logits.length} < '
        '${ReflectionModelContract.reflectionLogitWidth}',
      );
    }

    return logits;
  }
}
