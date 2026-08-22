import 'dart:typed_data';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/vision/image_embedding_inference.dart';
import 'package:archiveme_mobile/features/vision/image_processor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// ONNX Runtime binding for bundled vision encoder models (e.g. MobileCLIP).
///
/// Falls back to callers when the asset is missing — see [tryCreateFromAsset].
class OnnxImageEmbeddingInference implements ImageEmbeddingInference {
  OnnxImageEmbeddingInference._(this._session, this._inputName, this._outputName);

  final OrtSession _session;
  final String _inputName;
  final String _outputName;

  static const defaultAssetPath = 'assets/models/image_encoder.onnx';
  static const defaultInputName = 'input';
  static const defaultOutputName = 'embedding';

  /// Loads [assetPath] from the Flutter asset bundle. Returns null when absent.
  static Future<OnnxImageEmbeddingInference?> tryCreateFromAsset({
    String assetPath = defaultAssetPath,
    String inputName = defaultInputName,
    String outputName = defaultOutputName,
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
    return OnnxImageEmbeddingInference._(
      session,
      resolvedInput,
      resolvedOutput,
    );
  }

  @override
  Future<List<double>> embed(Float32List nchwTensor) async {
    if (nchwTensor.length != ImageProcessor.tensorElementCount) {
      throw ArgumentError.value(
        nchwTensor.length,
        'nchwTensor.length',
        'expected ${ImageProcessor.tensorElementCount}',
      );
    }

    final inputValue = await OrtValue.fromList(
      nchwTensor,
      [
        1,
        ImageProcessor.channelCount,
        ImageProcessor.inputSize,
        ImageProcessor.inputSize,
      ],
    );

    final outputs = await _session.run({_inputName: inputValue});
    final outputTensor = outputs[_outputName];
    if (outputTensor == null) {
      throw StateError('ONNX output "$_outputName" missing from session run');
    }

    final raw = await outputTensor.asFlattenedList();
    final flat = raw.map((value) => (value as num).toDouble()).toList(growable: false);
    if (flat.length != imageEmbeddingDimensions) {
      throw StateError(
        'ONNX embedding width ${flat.length} != $imageEmbeddingDimensions',
      );
    }

    await inputValue.dispose();
    await outputTensor.dispose();

    return ImageProcessor.l2Normalize(flat);
  }
}
