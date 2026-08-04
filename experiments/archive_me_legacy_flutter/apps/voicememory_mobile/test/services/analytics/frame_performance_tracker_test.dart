import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/analytics/frame_performance_tracker.dart';
import 'package:voicememory_mobile/shared/ui/glassmorphic_container.dart';
import 'package:voicememory_mobile/features/memory_graph/rendering/graph_lod_engine.dart';

void main() {
  test('degrades quality under sustained sub-55fps load', () {
    final tracker = FramePerformanceTracker(
      degradeAfterSamples: 2,
      recoverAfterSamples: 3,
    );

    tracker.recordFrameDuration(const Duration(milliseconds: 25));
    tracker.recordFrameDuration(const Duration(milliseconds: 25));

    expect(tracker.qualityTier, ApexQualityTier.balanced);
    expect(GlassQualityGovernor.maximum, GlassRenderQuality.reduced);
    expect(tracker.snapshot.droppedFrameStreak, 2);
    expect(tracker.snapshot.reason, contains('sub-55 FPS'));

    tracker.recordFrameDuration(const Duration(milliseconds: 10));
    tracker.recordFrameDuration(const Duration(milliseconds: 10));
    tracker.recordFrameDuration(const Duration(milliseconds: 10));

    expect(tracker.qualityTier, ApexQualityTier.full);
    expect(tracker.snapshot.droppedFrameStreak, 0);
    tracker.dispose();
  });

  test('thermal pressure immediately selects survival quality', () {
    final tracker = FramePerformanceTracker();

    tracker.applySystemPressure(thermal: true, batteryLow: false);

    expect(tracker.qualityTier, ApexQualityTier.survival);
    expect(tracker.snapshot.spatialParticleFraction, .25);
    expect(tracker.snapshot.spatialSimulationStride, 5);
    expect(
      GraphLODEngine.forScale(2, qualityPenalty: 2).level,
      GraphLODLevel.far,
    );
    tracker.dispose();
  });

  test('reports sampled vector latency and process RSS semantics', () {
    final tracker = FramePerformanceTracker();

    tracker.recordVectorLatency(const Duration(milliseconds: 12));
    tracker.recordVectorLatency(const Duration(milliseconds: 18));

    expect(tracker.snapshot.vectorLatencyMs, 15);
    expect(tracker.snapshot.processRssBytes, greaterThan(0));
    tracker.dispose();
  });
}
