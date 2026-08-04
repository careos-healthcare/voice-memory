import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/spatial_nexus/spatial_nexus_models.dart';
import 'package:voicememory_mobile/features/spatial_nexus/spatial_nexus_renderer.dart';

void main() {
  test('builds deterministic scenes and projects visible nodes', () {
    final graph = PersonalKnowledgeGraph(
      nodes: [
        GraphNode(
          id: 'node-a',
          type: NodeType.memory,
          label: 'Private memory',
          confidence: .8,
        ),
        GraphNode(
          id: 'node-b',
          type: NodeType.project,
          label: 'Private project',
          confidence: .7,
        ),
      ],
      edges: [
        GraphEdge(
          sourceNodeId: 'node-a',
          targetNodeId: 'node-b',
          type: EdgeType.associatedWith,
          isDirected: false,
          weight: .9,
          emotionalValenceScore: .6,
        ),
      ],
    );
    final renderer = SpatialNexusRenderer();
    final first = renderer.buildScene(graph: graph);
    final second = renderer.buildScene(graph: graph);

    expect(
      first.nodes.first.position.toJson(),
      second.nodes.first.position.toJson(),
    );
    expect(first.nodes.first.valence, .6);
    final projected = renderer.project(
      scene: first,
      camera: const SpatialCamera(),
      viewportWidth: 800,
      viewportHeight: 600,
    );
    expect(projected, isNotEmpty);
    expect(
      projected.every(
        (node) =>
            node.screenX >= 0 &&
            node.screenX <= 800 &&
            node.screenY >= 0 &&
            node.screenY <= 600,
      ),
      isTrue,
    );
  });

  test('culls nodes outside the camera frustum and separates collisions', () {
    final renderer = SpatialNexusRenderer();
    const base = SpatialNode(
      id: 'a',
      label: 'A',
      type: 'memory',
      position: SpatialVector3.zero(),
      velocity: SpatialVector3.zero(),
      radius: .2,
      valence: 0,
      clusterId: null,
      isHorizonProjection: false,
    );
    final scene = SpatialScene(
      nodes: [
        base,
        base.copyWith(position: const SpatialVector3.zero()),
        SpatialNode(
          id: 'outside',
          label: 'Outside',
          type: 'memory',
          position: const SpatialVector3(100, 0, 0),
          velocity: const SpatialVector3.zero(),
          radius: .2,
          valence: 0,
          clusterId: null,
          isHorizonProjection: false,
        ),
      ],
      edges: const [],
      preset: SpatialEnvironmentPreset.neuralVoid,
    );

    final projected = renderer.project(
      scene: scene,
      camera: const SpatialCamera(),
      viewportWidth: 400,
      viewportHeight: 400,
    );
    expect(projected.map((node) => node.node.id), isNot(contains('outside')));

    final simulated = renderer.simulate(scene, iterations: 6);
    expect(
      (simulated.nodes[0].position - simulated.nodes[1].position).length,
      greaterThan(0),
    );
  });

  test('native renderer capabilities fail closed', () async {
    final capabilities = await SpatialNexusRenderer().capabilities();
    expect(capabilities, isNotEmpty);
    expect(capabilities.every((capability) => !capability.available), isTrue);
  });
}
