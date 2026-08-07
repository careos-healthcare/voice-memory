import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/audio/playback_service.dart';

import 'helpers/mock_audioplayers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installMockAudioplayers);
  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    uninstallMockAudioplayers();
  });

  test('PlaybackState copyWith clears optional fields', () {
    const initial = PlaybackState(
      phase: PlaybackPhase.playing,
      sourceKind: PlaybackSourceKind.livePcm,
      filePath: '/tmp/a.wav',
      queueDepth: 2,
      activeQueueDepth: 2,
      error: 'boom',
    );

    final cleared = initial.copyWith(clearFilePath: true, clearError: true);

    expect(cleared.filePath, isNull);
    expect(cleared.error, isNull);
    expect(cleared.phase, PlaybackPhase.playing);
    expect(cleared.queueDepth, 2);
  });

  test('PlaybackService.create uses injectable player factory', () async {
    var factoryCalls = 0;
    final service = PlaybackService.create(
      playerFactory: () {
        factoryCalls++;
        return AudioPlayer();
      },
    );

    expect(service, isNotNull);
    expect(factoryCalls, 0);

    await service.disposeAsync();
  });

  test('feedLivePcm updates playback state for live PCM', () async {
    final service = PlaybackService.create();

    await service.prepareLiveSession();
    service.feedLivePcm(const [1, 2, 3, 4]);

    expect(service.state.sourceKind, PlaybackSourceKind.livePcm);
    expect(service.state.phase, PlaybackPhase.playing);

    await service.disposeAsync();
  });

  test(
    'queue depth stream emits when chunks are queued without playback',
    () async {
      final service = PlaybackService.create(testMode: true);
      final depths = <int>[];
      final sub = service.queueDepthStream.listen(depths.add);

      service.feedLivePcm(const [1, 2, 3, 4]);
      await Future<void>.delayed(Duration.zero);

      expect(service.pcmQueue.queueDepth, 1);
      expect(service.activeQueueDepth, 1);
      expect(depths, [1]);

      service.feedLivePcm(const [5, 6]);
      await Future<void>.delayed(Duration.zero);
      expect(service.pcmQueue.queueDepth, 2);
      expect(depths.last, 2);

      await sub.cancel();
      await service.disposeAsync();
    },
  );

  test('flushLivePcm clears queued chunks and emits zero depth', () async {
    final service = PlaybackService.create(testMode: true);
    final depths = <int>[];
    final sub = service.queueDepthStream.listen(depths.add);

    service.feedLivePcm(const [1, 2, 3, 4]);
    service.feedLivePcm(const [5, 6, 7, 8]);
    await Future<void>.delayed(Duration.zero);
    expect(service.pcmQueue.queueDepth, greaterThan(0));

    await service.flushLivePcm();
    await Future<void>.delayed(Duration.zero);

    expect(service.pcmQueue.queueDepth, 0);
    expect(service.activeQueueDepth, 0);
    expect(service.state.queueDepth, 0);
    expect(service.state.activeQueueDepth, 0);
    expect(depths.last, 0);

    await sub.cancel();
    await service.disposeAsync();
  });
}
