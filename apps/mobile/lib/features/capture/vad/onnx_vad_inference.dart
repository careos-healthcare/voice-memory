import 'dart:typed_data';

import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/capture/vad/webrtc_vad_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Optional ONNX VAD — loaded only when [assetPath] exists in the bundle.
abstract interface class VadInference {
  Future<bool?> classifyFrame(Float32List frame);
}

class OnnxVadInference implements VadInference {
  OnnxVadInference._(this._session, this._inputName, this._outputName);

  final OrtSession _session;
  final String _inputName;
  final String _outputName;

  static const defaultAssetPath = 'assets/models/vad_frame.onnx';

  static Future<OnnxVadInference?> tryCreateFromAsset({
    String assetPath = defaultAssetPath,
    String inputName = 'input',
    String outputName = 'speech_prob',
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
    return OnnxVadInference._(session, resolvedInput, resolvedOutput);
  }

  @override
  Future<bool?> classifyFrame(Float32List frame) async {
    final input = await OrtValue.fromList(frame, [1, frame.length]);
    try {
      final outputs = await _session.run({_inputName: input});
      final tensor = outputs[_outputName];
      if (tensor == null) return null;
      final values = await tensor.asFlattenedList();
      await tensor.dispose();
      if (values.isEmpty) return null;
      final prob = (values.first as num).toDouble();
      return prob >= 0.5;
    } finally {
      await input.dispose();
    }
  }
}

/// Falls back to [WebRtcVadEngine] when ONNX is unavailable.
class HybridVadInference implements VadInference {
  HybridVadInference({
    required this.sampleRateHz,
    this.onnx,
    this.aggressiveness = VadAggressiveness.quality,
  });

  final VadInference? onnx;
  final int sampleRateHz;
  final VadAggressiveness aggressiveness;

  @override
  Future<bool?> classifyFrame(Float32List frame) async {
    final model = onnx;
    if (model != null) {
      final result = await model.classifyFrame(frame);
      if (result != null) return result;
    }
    final pcm = Int16List(frame.length);
    for (var i = 0; i < frame.length; i++) {
      pcm[i] = (frame[i] * 32767).round().clamp(-32768, 32767);
    }
    return WebRtcVadEngine.isSpeechPcm16(
      pcm,
      sampleRateHz: sampleRateHz,
      aggressiveness: aggressiveness,
    );
  }
}
