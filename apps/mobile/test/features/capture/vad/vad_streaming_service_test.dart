import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_segment_writer.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_streaming_service.dart';
import 'package:archiveme_mobile/features/capture/vad/onnx_vad_inference.dart';
import 'package:archiveme_mobile/features/capture/vad/webrtc_vad_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _pcmFrame({
  required int sampleRateHz,
  required int frameDurationMs,
  double amplitude = 12000,
}) {
  final sampleCount = (sampleRateHz * frameDurationMs / 1000).round();
  final bytes = Uint8List(sampleCount * 2);
  for (var i = 0; i < sampleCount; i++) {
    final sample = (amplitude * math.sin(2 * math.pi * 440 * i / sampleRateHz))
        .round();
    bytes[i * 2] = sample & 0xff;
    bytes[i * 2 + 1] = (sample >> 8) & 0xff;
  }
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VadStreamingService', () {
    late Directory tempDir;
    late VadStreamingService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vad_stream_test_');
      service = VadStreamingService(
        config: const VadStreamConfig(
          minSpeechMs: 200,
          silenceHangoverMs: 200,
          preSpeechPaddingMs: 0,
        ),
        inference: _DeterministicVadInference(),
        segmentWriter: VadSegmentWriter(
          outputDirectory: tempDir.path,
          sampleRateHz: 16000,
        ),
      );
    });

    tearDown(() async {
      await service.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('emits a segment after speech followed by silence', () async {
      final controller = StreamController<Uint8List>();
      final events = <VadSegmentEvent>[];
      final sub = service.segments.listen(events.add);

      await service.startPcmStream(controller.stream);

      final speechFrame = _pcmFrame(sampleRateHz: 16000, frameDurationMs: 20);
      final silenceFrame = _pcmFrame(sampleRateHz: 16000, frameDurationMs: 20, amplitude: 0);

      for (var i = 0; i < 20; i++) {
        controller.add(speechFrame);
      }
      for (var i = 0; i < 20; i++) {
        controller.add(silenceFrame);
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await service.stop(reason: VadSegmentCloseReason.manualStop);
      await sub.cancel();
      await controller.close();

      expect(events, isNotEmpty);
      expect(service.completedSegments, isNotEmpty);
    });
  });
}

class _DeterministicVadInference implements VadInference {
  @override
  Future<bool?> classifyFrame(Float32List frame) async {
    return WebRtcVadEngine.isSpeechPcm16(
      Int16List.fromList(
        List.generate(frame.length, (i) => (frame[i] * 32767).round()),
      ),
      sampleRateHz: 16000,
    );
  }
}
