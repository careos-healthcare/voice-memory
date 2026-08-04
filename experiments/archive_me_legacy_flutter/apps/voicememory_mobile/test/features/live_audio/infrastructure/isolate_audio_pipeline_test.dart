import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/isolate_audio_pipeline.dart';
import 'package:voicememory_mobile/features/live_audio/live_audio_constants.dart';

void main() {
  group('resampleLinearInt16', () {
    test('returns input unchanged when rates match', () {
      final input = Int16List.fromList(const [100, 200, 300, 400]);
      expect(resampleLinearInt16(input, 16000, 16000), same(input));
    });

    test('preserves first sample when downsampling 48 kHz to 16 kHz', () {
      final input = Int16List.fromList(
        List<int>.generate(480, (i) => i % 1000),
      );
      final output = resampleLinearInt16(input, 48000, 16000);

      expect(output.length, 160);
      expect(output.first, input.first);
    });

    test('uses linear interpolation between adjacent samples', () {
      final input = Int16List.fromList(const [0, 100]);
      final output = resampleLinearInt16(input, 2, 1);

      expect(output, Int16List.fromList(const [0]));
    });

    test('scales output length by sample-rate ratio', () {
      const inputLength = 1920;
      final input = Int16List.fromList(
        List<int>.generate(inputLength, (i) => i),
      );
      final output = resampleLinearInt16(input, 48000, 16000);

      expect(output.length, inputLength ~/ 3);
    });
  });

  group('AudioPipelineProcessor', () {
    test('emits fixed 20 ms frames at target sample rate', () {
      const config = PipelineConfig(
        inputSampleRate: liveInputSampleRateHz,
        targetSampleRate: liveInputSampleRateHz,
        frameDurationMs: 20,
      );
      final processor = AudioPipelineProcessor(config);
      final frameSize = config.targetSamplesPerFrame;

      final result = processor.processRawBuffer(
        Int16List.fromList(List<int>.generate(frameSize * 2, (i) => i)),
      );

      expect(result.frames, hasLength(2));
      expect(result.frames.first, hasLength(frameSize));
      expect(result.droppedOldestFrame, isFalse);
    });

    test('retains partial frame samples in accumulator', () {
      const config = PipelineConfig(
        inputSampleRate: liveInputSampleRateHz,
        targetSampleRate: liveInputSampleRateHz,
        frameDurationMs: 20,
      );
      final processor = AudioPipelineProcessor(config);
      final frameSize = config.targetSamplesPerFrame;

      final first = processor.processRawBuffer(
        Int16List.fromList(List<int>.generate(frameSize + 10, (i) => i)),
      );
      expect(first.frames, hasLength(1));

      final second = processor.processRawBuffer(
        Int16List.fromList(List<int>.generate(frameSize, (i) => i + 1000)),
      );
      expect(second.frames, hasLength(1));
      expect(second.frames.single.first, frameSize);
    });

    test('drops oldest frames when ring buffer exceeds maxRingBufferSize', () {
      const config = PipelineConfig(
        inputSampleRate: liveInputSampleRateHz,
        targetSampleRate: liveInputSampleRateHz,
        frameDurationMs: 20,
        maxRingBufferSize: 2,
      );
      final processor = AudioPipelineProcessor(config);
      final frameSize = config.targetSamplesPerFrame;

      final result = processor.processRawBuffer(
        Int16List.fromList(List<int>.generate(frameSize * 4, (i) => 1)),
      );

      expect(result.frames, hasLength(2));
      expect(result.droppedOldestFrame, isTrue);
    });
  });

  group('IsolateAudioPipeline Deep Architectural Tests', () {
    late IsolateAudioPipeline pipeline;

    tearDown(() async {
      await pipeline.dispose();
    });

    test(
      'downsamples 48 kHz hardware stream to 16 kHz and packs into 20 ms windows',
      () async {
        const config = PipelineConfig(
          inputSampleRate: 48000,
          targetSampleRate: 16000,
          frameDurationMs: 20,
        );

        pipeline = IsolateAudioPipeline(config);
        expect(config.targetSamplesPerFrame, 320);

        final receivedFrames = <Int16List>[];
        final completer = Completer<void>();

        await pipeline.start();

        pipeline.processedAudioStream.listen((frame) {
          receivedFrames.add(frame);
          if (receivedFrames.length == 2) {
            completer.complete();
          }
        });

        // 320 target samples * 3 (48k -> 16k) * 2 frames = 1920 hardware samples
        final hardwareBuffer = Int16List.fromList(
          List<int>.generate(1920, (i) => (i % 1000) - 500),
        );

        pipeline.pushRawHardwareBuffer(hardwareBuffer);

        await completer.future.timeout(const Duration(seconds: 2));

        expect(receivedFrames, hasLength(2));
        expect(receivedFrames[0], hasLength(320));
        expect(receivedFrames[1], hasLength(320));
      },
    );

    test(
      'enforces maxRingBufferSize and drops oldest frames under backpressure',
      () async {
        const config = PipelineConfig(
          inputSampleRate: 16000,
          targetSampleRate: 16000,
          frameDurationMs: 20,
          maxRingBufferSize: 2,
        );

        pipeline = IsolateAudioPipeline(config);
        await pipeline.start();

        final receivedFrames = <Int16List>[];
        pipeline.processedAudioStream.listen(receivedFrames.add);

        final excessHardwareBuffer = Int16List.fromList(
          List<int>.generate(320 * 4, (i) => 1),
        );

        pipeline.pushRawHardwareBuffer(excessHardwareBuffer);

        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(pipeline.isRunning, isTrue);
        expect(receivedFrames, hasLength(2));
      },
    );

    test(
      'survives repeated stress payloads without growing frame batches',
      () async {
        const config = PipelineConfig(
          inputSampleRate: 16000,
          targetSampleRate: 16000,
          frameDurationMs: 20,
          maxRingBufferSize: 2,
        );

        pipeline = IsolateAudioPipeline(config);
        await pipeline.start();

        final receivedFrames = <Int16List>[];
        pipeline.processedAudioStream.listen(receivedFrames.add);

        final stressBuffer = Int16List.fromList(
          List<int>.generate(320 * 4, (i) => i & 0x7fff),
        );

        for (var i = 0; i < 20; i++) {
          pipeline.pushRawHardwareBuffer(stressBuffer);
        }

        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(pipeline.isRunning, isTrue);
        expect(receivedFrames.length, lessThanOrEqualTo(40));
        for (final frame in receivedFrames) {
          expect(frame, hasLength(320));
        }
      },
    );

    test(
      'supports injected isolate spawn for deterministic worker execution',
      () async {
        pipeline = IsolateAudioPipeline(
          const PipelineConfig(inputSampleRate: liveInputSampleRateHz),
          spawnIsolate: (entryPoint, mainSendPort) async {
            entryPoint(mainSendPort);
            return null;
          },
        );

        await pipeline.start();

        final receivedFrames = <Int16List>[];
        pipeline.processedAudioStream.listen(receivedFrames.add);

        pipeline.pushRawHardwareBuffer(
          Int16List.fromList(List<int>.generate(640, (i) => i)),
        );

        await pumpEventQueue(times: 5);

        expect(pipeline.isRunning, isTrue);
        expect(receivedFrames, hasLength(2));
        expect(receivedFrames.every((frame) => frame.length == 320), isTrue);
      },
    );
  });
}
