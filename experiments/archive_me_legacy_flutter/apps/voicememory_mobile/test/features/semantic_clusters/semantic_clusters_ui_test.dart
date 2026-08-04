import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/features/semantic_clusters/ui/cluster_boundary_overlay.dart';
import 'package:voicememory_mobile/features/semantic_clusters/ui/semantic_clusters_sheet.dart';
import 'package:voicememory_mobile/ui/screens/life_os/graph_painter.dart';
import 'package:voicememory_mobile/ui/screens/life_os/knowledge_graph_layout.dart';
import 'package:voicememory_mobile/widgets/life_os/interactive_knowledge_graph_widget.dart';

void main() {
  test('boundary painter creates organic hittable hulls efficiently', () {
    final graph = _graph();
    final layout = KnowledgeGraphLayout(graph.nodes, const {
      'one': Offset(100, 100),
      'two': Offset(260, 120),
      'three': Offset(190, 250),
    }, const Size(400, 360));
    final cluster = _cluster();
    final clusters = [cluster];
    final painter = ClusterBoundaryPainter(
      layout: layout,
      clusters: clusters,
      focusClusterId: cluster.id,
    );

    expect(painter.boundaries, hasLength(1));
    expect(painter.clusterAt(const Offset(190, 155))?.id, cluster.id);
    expect(
      painter.shouldRepaint(
        ClusterBoundaryPainter(
          layout: layout,
          clusters: clusters,
          focusClusterId: cluster.id,
        ),
      ),
      isFalse,
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), layout.size);
    expect(recorder.endRecording(), isNotNull);
  });

  testWidgets('cluster hull exposes semantics and handles boundary taps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final graph = _graph();
    final cluster = _cluster();
    final controller = TransformationController();
    addTearDown(controller.dispose);
    SemanticCluster? selected;
    Map<String, Offset> positions = {};
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness(
        InteractiveKnowledgeGraphWidget(
          graph: graph,
          clusters: [cluster],
          transformationController: controller,
          onClusterSelected: (value) => selected = value,
          onLayoutComputed: (_, value) => positions = value,
        ),
      ),
    );
    await tester.pump();

    final clusterSemantics = _semanticsNode(
      tester,
      'Theme cluster, Creative circle, 3 members',
    );
    expect(clusterSemantics, isNotNull);
    expect(
      clusterSemantics!.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    final midpoint = (positions['one']! + positions['two']!) / 2;
    final topLeft = tester.getTopLeft(
      find.byKey(const Key('interactive-knowledge-graph-canvas')),
    );
    await tester.tapAt(topLeft + midpoint);
    await tester.pump();
    expect(selected?.id, cluster.id);
    semantics.dispose();
  });

  testWidgets('cluster focus fits camera and dims nonmembers', (tester) async {
    final graph = _graph(includeOutsideNode: true);
    final cluster = _cluster();
    final controller = TransformationController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness(
        InteractiveKnowledgeGraphWidget(
          graph: graph,
          clusters: [cluster],
          focusClusterId: cluster.id,
          focusClusterRevision: 1,
          transformationController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const Key('interactive-knowledge-graph-canvas')),
    );
    final graphPainter = customPaint.painter! as GraphPainter;
    expect(graphPainter.highlightedNodeIds, cluster.nodeIds.toSet());
    expect(
      controller.value.storage[0] != 1 ||
          controller.value.storage[12] != 0 ||
          controller.value.storage[13] != 0,
      isTrue,
    );
  });

  testWidgets('sheet delegates actions and supports large Dynamic Type', (
    tester,
  ) async {
    final clusters = [
      _cluster(nodeIds: const ['one', 'two', 'three', 'four']),
      _cluster(
        id: 'second',
        title: 'Second cluster',
        velocity: .3,
        nodeIds: const ['two', 'three'],
      ),
    ];
    var pinned = false;
    var renamed = '';
    var merged = '';
    var split = '';
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(500, 800),
            textScaler: TextScaler.linear(2.2),
          ),
          child: Scaffold(
            body: SemanticClustersSheet(
              clusters: clusters,
              graph: _graph(),
              onPin: (cluster, value) => pinned = value,
              onRename: (cluster, title) => renamed = title,
              onMerge: (cluster, other) => merged = other.id,
              onSplit: (cluster) => split = cluster.id,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('semantic-clusters-scroll-view')), findsOne);
    expect(tester.takeException(), isNull);

    final actions = find.byKey(const Key('semantic-cluster-actions-cluster'));
    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(pinned, isTrue);

    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('semantic-cluster-rename-field')),
      'Renamed cluster',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(renamed, 'Renamed cluster');

    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('semantic-cluster-merge-cluster-second')),
    );
    await tester.pumpAndSettle();
    expect(merged, 'second');

    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();
    expect(split, 'cluster');
    expect(tester.takeException(), isNull);
  });

  test('sheet ranks velocity first and valence second when available', () {
    final graph = _graph(valence: .8);
    final slower = _cluster(id: 'slow', velocity: .2);
    final negative = _cluster(
      id: 'negative',
      velocity: .7,
      nodeIds: const ['one', 'three'],
    );
    final positive = _cluster(id: 'positive', velocity: .7);

    expect(
      SemanticClustersSheet.rankedClusters([
        slower,
        negative,
        positive,
      ], graph).map((item) => item.id),
      ['positive', 'negative', 'slow'],
    );
  });
}

Widget _harness(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

SemanticCluster _cluster({
  String id = 'cluster',
  String title = 'Creative circle',
  double velocity = .7,
  List<String> nodeIds = const ['one', 'two', 'three'],
}) => SemanticCluster(
  id: id,
  title: title,
  category: SemanticClusterCategory.theme,
  nodeIds: nodeIds,
  activityVelocity: velocity,
  confidenceScore: .8,
  summary: 'A connected creative theme',
);

PersonalKnowledgeGraph _graph({
  bool includeOutsideNode = false,
  double valence = .8,
}) {
  final nodes = [
    _node('one', 'One'),
    _node('two', 'Two'),
    _node('three', 'Three'),
    if (includeOutsideNode) _node('outside', 'Outside'),
  ];
  return PersonalKnowledgeGraph(
    nodes: nodes,
    edges: [
      _edge('one', 'two', valence),
      _edge('two', 'three', -.6),
      if (includeOutsideNode) _edge('three', 'outside', .1),
    ],
  );
}

GraphNode _node(String id, String label) => GraphNode(
  id: id,
  type: NodeType.topic,
  label: label,
  confidence: .9,
  evidence: [
    GraphNodeEvidence(
      entryId: 'entry-$id',
      observedAt: DateTime.utc(2026, 7, 1),
      confidence: .9,
      excerpt: label,
      startUtf16: 0,
      endUtf16: label.length,
    ),
  ],
);

GraphEdge _edge(String source, String target, double valence) => GraphEdge(
  id: '$source-$target',
  sourceNodeId: source,
  targetNodeId: target,
  type: EdgeType.associatedWith,
  isDirected: false,
  weight: .8,
  emotionalValenceScore: valence,
  evidence: [
    GraphEdgeEvidence(
      entryId: 'edge-$source-$target',
      observedAt: DateTime.utc(2026, 7, 1),
      confidence: .8,
      excerpt: '$source $target',
      startUtf16: 0,
      endUtf16: '$source $target'.length,
    ),
  ],
);

SemanticsNode? _semanticsNode(WidgetTester tester, String label) {
  SemanticsNode? result;
  bool visit(SemanticsNode node) {
    if (node.getSemanticsData().label == label) {
      result = node;
      return false;
    }
    node.visitChildren(visit);
    return result == null;
  }

  // ignore: deprecated_member_use
  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return result;
}
