
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_pcm24_playback_engine.dart';

void main() {
  test(
    'queue depth stream emits when chunks are queued without playback',
    () async {
      final engine = LivePcm24PlaybackEngine();
      final depths = <int>[];
      final sub = engine.queueDepthStream.listen(depths.add);

      engine.feed(const [1, 2, 3, 4]);
      await Future<void>.delayed(Duration.zero);

      expect(engine.queueDepth, 1);
      expect(engine.activeQueueDepth, 1);
      expect(depths, [1]);

      engine.feed(const [5, 6]);
      await Future<void>.delayed(Duration.zero);
      expect(engine.queueDepth, 2);
      expect(depths.last, 2);

      await sub.cancel();
    },
  );

  test('flush clears queued chunks and emits zero depth', () async {
    final engine = LivePcm24PlaybackEngine();
    final depths = <int>[];
    final sub = engine.queueDepthStream.listen(depths.add);

    engine.feed(const [1, 2, 3, 4]);
    engine.feed(const [5, 6, 7, 8]);
    await Future<void>.delayed(Duration.zero);
    expect(engine.queueDepth, greaterThan(0));

    await engine.flush();
    await Future<void>.delayed(Duration.zero);

    expect(engine.queueDepth, 0);
    expect(engine.activeQueueDepth, 0);
    expect(depths.last, 0);

    await sub.cancel();
  });
}
