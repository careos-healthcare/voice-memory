import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/spatial_nexus/spatial_interaction_controller.dart';
import 'package:voicememory_mobile/features/spatial_nexus/spatial_nexus_models.dart';
import 'package:voicememory_mobile/features/spatial_nexus/spatial_sound_engine.dart';

void main() {
  test('positions local audio by distance azimuth and proximity', () async {
    final driver = _FakeAudioDriver();
    final engine = SpatialSoundEngine(
      driver: driver,
      audibleRadius: 5,
      maxActiveSources: 1,
    );
    addTearDown(engine.dispose);

    final right = engine.position(
      listener: const SpatialVector3.zero(),
      source: const SpatialVector3(2, 0, -2),
    );
    expect(right.gain, greaterThan(0));
    expect(right.pan, greaterThan(0));

    await engine.update(
      listener: const SpatialVector3.zero(),
      sources: const [
        SpatialNode(
          id: 'near',
          label: 'Near',
          type: 'memory',
          position: SpatialVector3(0, 0, -1),
          velocity: SpatialVector3.zero(),
          radius: .2,
          valence: 0,
          clusterId: null,
          isHorizonProjection: false,
        ),
        SpatialNode(
          id: 'far',
          label: 'Far',
          type: 'memory',
          position: SpatialVector3(0, 0, -4),
          velocity: SpatialVector3.zero(),
          radius: .2,
          valence: 0,
          clusterId: null,
          isHorizonProjection: false,
        ),
      ],
    );
    expect(driver.updates.single.$1, 'near');
    await engine.setPaused(true);
    expect(driver.stopAllCount, 1);
  });

  test('pinch, cluster pull, and projected-node picking are bounded', () {
    const controller = SpatialInteractionController();
    final zoomed = controller.pinch(const SpatialCamera(), 2);
    expect(zoomed.position.z, 4);

    const node = SpatialNode(
      id: 'node',
      label: 'Node',
      type: 'memory',
      position: SpatialVector3.zero(),
      velocity: SpatialVector3.zero(),
      radius: .2,
      valence: 0,
      clusterId: 'cluster',
      isHorizonProjection: false,
    );
    final scene = controller.pullCluster(
      scene: const SpatialScene(
        nodes: [node],
        edges: [],
        preset: SpatialEnvironmentPreset.neuralVoid,
      ),
      clusterId: 'cluster',
      delta: const SpatialVector3(10, 0, 0),
    );
    expect(scene.nodes.single.position.x, 3);

    final selected = controller.pick(
      projected: const [
        SpatialProjectedNode(
          node: node,
          screenX: 100,
          screenY: 100,
          depth: 8,
          scale: 1,
          blurSigma: 0,
        ),
      ],
      x: 105,
      y: 102,
    );
    expect(selected?.id, 'node');
  });
}

final class _FakeAudioDriver implements SpatialAudioDriver {
  final updates = <(String, SpatialAudioParameters)>[];
  int stopAllCount = 0;

  @override
  Future<void> updateSource(
    String sourceId,
    SpatialAudioParameters parameters,
  ) async => updates.add((sourceId, parameters));

  @override
  Future<void> stopSource(String sourceId) async {}

  @override
  Future<void> stopAll() async => stopAllCount++;

  @override
  Future<void> dispose() async {}
}
