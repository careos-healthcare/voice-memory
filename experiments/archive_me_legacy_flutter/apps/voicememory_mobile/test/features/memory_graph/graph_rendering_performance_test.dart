import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/features/memory_graph/rendering/graph_lod_engine.dart';
import 'package:voicememory_mobile/ui/screens/life_os/graph_painter.dart';
import 'package:voicememory_mobile/ui/screens/life_os/knowledge_graph_layout.dart';

void main() {
  test('LOD thresholds select marker, standard, and card renderers', () {
    expect(GraphLODEngine.forScale(.49).level, GraphLODLevel.far);
    expect(GraphLODEngine.forScale(.5).level, GraphLODLevel.mid);
    expect(GraphLODEngine.forScale(1.5).level, GraphLODLevel.mid);
    expect(GraphLODEngine.forScale(1.51).level, GraphLODLevel.close);
  });

  test('10,000-node far-LOD paint stays within the 16.6ms CPU budget', () {
    final observedAt = DateTime.utc(2026, 7, 27);
    final nodes = List.generate(
      10000,
      (index) => GraphNode(
        id: 'node-$index',
        type: NodeType.memory,
        label: 'Memory $index',
        confidence: .8,
        evidence: [
          GraphNodeEvidence(
            entryId: 'entry-$index',
            observedAt: observedAt,
            excerpt: 'Evidence',
            confidence: .8,
          ),
        ],
      ),
      growable: false,
    );
    final positions = <String, Offset>{
      for (var index = 0; index < nodes.length; index++)
        nodes[index].id: Offset(
          (index % 100) * 48 + 24,
          (index ~/ 100) * 48 + 24,
        ),
    };
    final layout = KnowledgeGraphLayout(
      nodes,
      positions,
      const Size(4800, 4800),
    );
    final controller = TransformationController(
      Matrix4.diagonal3Values(.1, .1, 1),
    );
    final viewState = KnowledgeGraphViewState();
    addTearDown(controller.dispose);
    addTearDown(viewState.dispose);
    final painter = GraphPainter(
      layout: layout,
      edges: const [],
      viewState: viewState,
      transformationController: controller,
      viewportSize: const Size(480, 480),
      onSemanticTap: (_) {},
    );

    _paint(painter, layout.size);
    final stopwatch = Stopwatch()..start();
    const samples = 30;
    for (var frame = 0; frame < samples; frame++) {
      _paint(painter, layout.size);
    }
    stopwatch.stop();

    final averageMilliseconds = stopwatch.elapsedMicroseconds / samples / 1000;
    expect(
      averageMilliseconds,
      lessThan(16.6),
      reason:
          'Far-LOD batching and quadtree culling must keep CPU paint work '
          'inside one 60fps frame.',
    );
  });
}

void _paint(GraphPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}
