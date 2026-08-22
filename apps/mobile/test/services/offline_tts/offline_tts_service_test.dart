import 'package:archiveme_mobile/audio/playback_service.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineTtsService', () {
    late OfflineTtsService service;
    late PlaybackService playback;
    final emittedChunks = <List<int>>[];

    setUp(() async {
      emittedChunks.clear();
      playback = OfflineTtsService.createPlayback(
        sampleRateHz: 24000,
        testMode: true,
      );
      service = OfflineTtsService(
        backend: StubOfflineTtsBackend(
          sampleRateHz: 24000,
          chunkDurationSeconds: 0.02,
        ),
        playback: playback,
        onPcmChunk: (chunk) => emittedChunks.add(chunk.pcmBytes),
      );
      await service.loadModel(
        const OfflineTtsConfig(
          vitsModelPath: '/tmp/stub-model.onnx',
          tokensPath: '/tmp/stub-tokens.txt',
        ),
      );
    });

    tearDown(() async {
      await service.dispose();
      await playback.disposeAsync();
    });

    test('streams PCM chunks into playback during speak', () async {
      final result = await service.speak('Hello offline voice');

      expect(result.chunkCount, greaterThan(0));
      expect(result.totalPcmBytes, greaterThan(0));
      expect(result.sampleRateHz, 24000);
      expect(emittedChunks, isNotEmpty);
      expect(playback.activeQueueDepth, greaterThan(0));
      await playback.flushLivePcm();
      expect(playback.activeQueueDepth, 0);
    });

    test('stop cancels an in-flight synthesis', () async {
      await service.dispose();
      await playback.disposeAsync();

      playback = OfflineTtsService.createPlayback(
        sampleRateHz: 24000,
        testMode: true,
      );
      service = OfflineTtsService(
        backend: StubOfflineTtsBackend(
          sampleRateHz: 24000,
          chunkDurationSeconds: 0.02,
          interChunkDelay: const Duration(milliseconds: 25),
        ),
        playback: playback,
      );
      await service.loadModel(
        const OfflineTtsConfig(
          vitsModelPath: '/tmp/stub-model.onnx',
          tokensPath: '/tmp/stub-tokens.txt',
        ),
      );

      final speakFuture = service.speak('One two three four five six seven eight');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.stop();

      final result = await speakFuture;
      expect(result.chunkCount, lessThan(8));
    });

    test('tryCreate returns null when model files are missing', () async {
      final created = await OfflineTtsService.tryCreate(
        modelPath: '/tmp/does-not-exist.onnx',
        tokensPath: '/tmp/does-not-exist.txt',
        backend: StubOfflineTtsBackend(),
      );

      expect(created, isNull);
    });
  });

  group('StubOfflineTtsBackend', () {
    test('rejects empty text', () async {
      final backend = StubOfflineTtsBackend();
      await backend.load(
        const OfflineTtsConfig(
          vitsModelPath: '/tmp/stub-model.onnx',
          tokensPath: '/tmp/stub-tokens.txt',
        ),
      );

      await expectLater(
        backend.synthesize(const OfflineTtsSpeakRequest(text: '   ')).first,
        throwsA(isA<OfflineTtsException>()),
      );
      await backend.dispose();
    });
  });
}
