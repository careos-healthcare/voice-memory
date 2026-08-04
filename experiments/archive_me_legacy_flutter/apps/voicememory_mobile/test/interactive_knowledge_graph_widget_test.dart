import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/memory_graph/ui/graph_node_hero_animation.dart';
import 'package:voicememory_mobile/ui/screens/life_os/graph_painter.dart';
import 'package:voicememory_mobile/ui/screens/life_os/knowledge_graph_layout.dart';
import 'package:voicememory_mobile/widgets/life_os/interactive_knowledge_graph_widget.dart';

void main() {
  testWidgets(
    'tap selects node, shows citations, sentiment, and governed evidence',
    (tester) async {
      final graph = _smallGraph();
      Map<String, Offset> positions = {};
      GraphNode? evidenceNode;
      GraphNode? selectedNode;
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _harness(
          InteractiveKnowledgeGraphWidget(
            graph: graph,
            onLayoutComputed: (_, value) => positions = value,
            onNodeSelected: (node) => selectedNode = node,
            onViewEvidenceMentions: (node) => evidenceNode = node,
          ),
        ),
      );
      await tester.pump();

      final canvasTopLeft = tester.getTopLeft(
        find.byKey(const Key('interactive-knowledge-graph-canvas')),
      );
      await tester.tapAt(canvasTopLeft + positions['person-alex']!);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('knowledge-graph-detail-panel')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Hero && widget.tag == graphNodeHeroTag('person-alex'),
        ),
        findsNWidgets(2),
      );
      expect(
        find.byKey(const Key('graph_node_detail_hero_person-alex')),
        findsOneWidget,
      );
      expect(selectedNode?.id, 'person-alex');
      expect(find.text('Entry ID: entry-person'), findsOneWidget);
      expect(find.text('Entry ID: entry-edge'), findsOneWidget);
      expect(find.text('Alex — [INFLUENCES] → Build a studio'), findsOneWidget);
      expect(
        find.byKey(const Key('knowledge-graph-relationship-sentiment')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Exact quote: “Alex was kind and supportive private wording”',
        ),
        findsOneWidget,
      );
      expect(find.text('UTF-16 offsets: 0–44'), findsOneWidget);

      expect(
        find.byKey(const Key('knowledge-graph-time-machine')),
        findsNothing,
      );
      await tester.ensureVisible(find.text('View Evidence Mentions'));
      await tester.tap(find.text('View Evidence Mentions'));
      await tester.pumpAndSettle();
      expect(evidenceNode?.id, 'person-alex');
    },
  );

  testWidgets('node semantics exposes an actionable tap', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(InteractiveKnowledgeGraphWidget(graph: _smallGraph())),
    );
    await tester.pumpAndSettle();

    final node = _semanticsNode(tester, 'Person, Alex, 1 evidence entry');
    expect(node, isNotNull);
    expect(node!.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    // The test binding owns the active semantics tree.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('knowledge-graph-detail-panel')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('live graph updates mark injected nodes as unconfirmed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final original = _smallGraph();
    await tester.pumpWidget(
      _harness(
        InteractiveKnowledgeGraphWidget(
          key: const ValueKey('live-graph'),
          graph: original,
        ),
      ),
    );
    await tester.pump();

    final updated = PersonalKnowledgeGraph(
      nodes: [
        ...original.nodes,
        GraphNode(
          id: 'entry-new',
          type: NodeType.journalEntry,
          label: 'Voice memory · new moment',
          confidence: 1,
          evidence: [
            GraphNodeEvidence(
              entryId: 'entry-new',
              observedAt: DateTime.utc(2026, 7, 26),
              confidence: 1,
              excerpt: 'new moment',
              startUtf16: 0,
              endUtf16: 'new moment'.length,
            ),
          ],
        ),
      ],
      edges: original.edges,
    );
    await tester.pumpWidget(
      _harness(
        InteractiveKnowledgeGraphWidget(
          key: const ValueKey('live-graph'),
          graph: updated,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      _semanticsNode(
        tester,
        'Voice memory, Voice memory · new moment, 1 evidence entry, '
        'new unconfirmed node',
      ),
      isNotNull,
    );
    semantics.dispose();
  });

  testWidgets('graph custom action switches to the sorted entity list', (
    tester,
  ) async {
    const switchAction = CustomSemanticsAction(
      label: 'Switch to accessible entity list',
    );
    const resetAction = CustomSemanticsAction(
      label: 'Center graph and reset zoom',
    );
    final controller = TransformationController();
    addTearDown(controller.dispose);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        InteractiveKnowledgeGraphWidget(
          graph: _smallGraph(),
          transformationController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(InteractiveViewer), const Offset(-80, -40));
    await tester.pump();
    expect(controller.value.storage[12], isNot(closeTo(0, 0.001)));
    final graph = _semanticsNode(
      tester,
      'Interactive knowledge graph, 2 entities and 1 connections. '
      'Pan and zoom to explore.',
    );
    expect(graph, isNotNull);
    final graphNode = graph!;
    final resetActionId = CustomSemanticsAction.getIdentifier(resetAction);
    expect(
      graphNode.getSemanticsData().customSemanticsActionIds,
      contains(resetActionId),
    );
    // The test binding owns the active semantics tree.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      graphNode.id,
      SemanticsAction.customAction,
      resetActionId,
    );
    await tester.pumpAndSettle();
    expect(controller.value.storage[12], closeTo(0, 0.001));

    final actionId = CustomSemanticsAction.getIdentifier(switchAction);
    expect(
      graphNode.getSemanticsData().customSemanticsActionIds,
      contains(actionId),
    );
    // The test binding owns the active semantics tree.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      graphNode.id,
      SemanticsAction.customAction,
      actionId,
    );
    await tester.pump();

    expect(
      find.byKey(const Key('knowledge-graph-entity-list')),
      findsOneWidget,
    );
    final tiles = tester
        .widgetList<ListTile>(
          find.descendant(
            of: find.byKey(const Key('knowledge-graph-entity-list')),
            matching: find.byType(ListTile),
          ),
        )
        .toList();
    expect((tiles.first.title! as Text).data, 'Alex');
    expect((tiles.last.title! as Text).data, 'Build a studio');
    semantics.dispose();
  });

  testWidgets('compact filter menu filters supported entity types', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(InteractiveKnowledgeGraphWidget(graph: _smallGraph())),
    );
    await tester.pump();

    const goalLabel = 'Goal, Build a studio, 1 evidence entry';
    const personLabel = 'Person, Alex, 1 evidence entry';
    expect(
      find.byKey(const Key('knowledge-graph-filter-menu')),
      findsOneWidget,
    );
    expect(_semanticsNode(tester, goalLabel), isNotNull);
    await tester.tap(find.byKey(const Key('knowledge-graph-filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-graph-filter-goal')));
    await tester.pumpAndSettle();
    expect(_semanticsNode(tester, goalLabel), isNotNull);
    expect(_semanticsNode(tester, personLabel), isNull);

    await tester.tap(find.byKey(const Key('knowledge-graph-filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-graph-filter-all')));
    await tester.pumpAndSettle();
    expect(_semanticsNode(tester, goalLabel), isNotNull);
    expect(_semanticsNode(tester, personLabel), isNotNull);
    semantics.dispose();
  });

  testWidgets('supports injected pan zoom state and animated centering', (
    tester,
  ) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    Map<String, Offset> positions = {};
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _harness(
        InteractiveKnowledgeGraphWidget(
          graph: _smallGraph(),
          transformationController: controller,
          onLayoutComputed: (_, value) => positions = value,
        ),
      ),
    );
    await tester.pump();

    final viewer = find.byType(InteractiveViewer);
    await tester.drag(viewer, const Offset(-70, -35));
    await tester.pump();
    expect(controller.value.storage[12], isNot(closeTo(0, 0.001)));

    final center = tester.getCenter(viewer);
    final first = await tester.startGesture(
      center - const Offset(22, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(22, 0),
      pointer: 2,
    );
    await first.moveTo(center - const Offset(70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(controller.value.storage[0], greaterThan(1));

    await tester.tap(find.byKey(const Key('knowledge-graph-center-all')));
    await tester.pumpAndSettle();
    expect(controller.value.storage[0], closeTo(1, 0.001));
    expect(controller.value.storage[12], closeTo(0, 0.001));

    final canvasTopLeft = tester.getTopLeft(
      find.byKey(const Key('interactive-knowledge-graph-canvas')),
    );
    await tester.tapAt(canvasTopLeft + positions['person-alex']!);
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const Key('knowledge-graph-detail-panel'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-graph-center-selected')));
    await tester.pumpAndSettle();
    expect(controller.value.storage[12], isNot(closeTo(0, 0.001)));
  });

  testWidgets('reduced motion resets the graph without an animation', (
    tester,
  ) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _harness(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(900, 900),
            disableAnimations: true,
          ),
          child: InteractiveKnowledgeGraphWidget(
            graph: _smallGraph(),
            transformationController: controller,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(InteractiveViewer), const Offset(-80, -40));
    await tester.pump();
    expect(controller.value.storage[12], isNot(closeTo(0, 0.001)));

    await tester.tap(find.byKey(const Key('knowledge-graph-center-all')));
    await tester.pump();
    expect(controller.value.storage[0], closeTo(1, 0.001));
    expect(controller.value.storage[12], closeTo(0, 0.001));
    expect(
      tester
          .getSize(find.byKey(const Key('knowledge-graph-list-toggle')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  test('public painter exposes directed weighted visible edges', () {
    final graph = _smallGraph();
    final layout = ForceDirectedKnowledgeGraphLayout.compute(
      graph.nodes,
      graph.edges,
      const Size(760, 520),
    );
    final viewState = KnowledgeGraphViewState();
    final controller = TransformationController();
    addTearDown(viewState.dispose);
    addTearDown(controller.dispose);
    final painter = GraphPainter(
      layout: layout,
      edges: graph.edges,
      viewState: viewState,
      transformationController: controller,
      viewportSize: layout.size,
      onSemanticTap: (_) {},
    );
    expect(painter.visibleEdgeCount, 1);
    expect(painter.directedEdgeCount, 1);
    expect(painter.weightedEdgeCount, 1);
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), layout.size);
    expect(recorder.endRecording(), isNotNull);
  });

  testWidgets('debug performance diagnostics can be toggled on canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(InteractiveKnowledgeGraphWidget(graph: _smallGraph())),
    );

    await tester.tap(find.byKey(const Key('graph-performance-toggle')));
    await tester.pump();

    expect(find.textContaining('FPS '), findsOneWidget);
    expect(find.textContaining('culled'), findsOneWidget);
    expect(find.textContaining('KNN'), findsOneWidget);
  });

  test('painter semantics suppresses nodes and edges without citations', () {
    final valid = _smallGraph().nodes.first;
    final invalid = GraphNode(
      id: 'invalid',
      type: NodeType.person,
      label: 'Unsupported label',
      confidence: 1,
    );
    final invalidEdge = GraphEdge(
      sourceNodeId: valid.id,
      targetNodeId: invalid.id,
      type: EdgeType.associatedWith,
      isDirected: false,
      weight: 1,
    );
    final layout = ForceDirectedKnowledgeGraphLayout.compute(
      [valid, invalid],
      [invalidEdge],
      const Size(760, 520),
    );
    final viewState = KnowledgeGraphViewState();
    final controller = TransformationController();
    addTearDown(viewState.dispose);
    addTearDown(controller.dispose);
    final painter = GraphPainter(
      layout: layout,
      edges: [invalidEdge],
      viewState: viewState,
      transformationController: controller,
      viewportSize: layout.size,
      onSemanticTap: (_) {},
    );

    final semantics = painter.semanticsBuilder(const Size(760, 520));
    expect(semantics, hasLength(1));
    expect(semantics.single.properties.label, contains('Alex'));
    expect(painter.visibleEdgeCount, 0);
  });

  testWidgets('lays out all 500+ nodes once and selection reuses the layout', (
    tester,
  ) async {
    final nodes = List.generate(
      520,
      (index) => GraphNode(
        id: 'person-$index',
        type: NodeType.person,
        label: 'Person $index',
        confidence: 0.8,
        evidence: [
          GraphNodeEvidence(
            entryId: 'entry-$index',
            observedAt: DateTime.utc(2026, 1, 1),
            confidence: 0.8,
            excerpt: 'Person $index',
            startUtf16: 0,
            endUtf16: 'Person $index'.length,
          ),
        ],
      ),
    );
    final edges = List.generate(
      519,
      (index) => GraphEdge(
        id: 'edge-$index',
        sourceNodeId: 'person-$index',
        targetNodeId: 'person-${index + 1}',
        type: EdgeType.associatedWith,
        isDirected: false,
        weight: 0.6,
        evidence: [
          GraphEdgeEvidence(
            entryId: 'edge-entry-$index',
            observedAt: DateTime.utc(2026, 1, 1),
            confidence: 0.6,
            excerpt: 'edge-$index',
            startUtf16: 0,
            endUtf16: 'edge-$index'.length,
          ),
        ],
      ),
    );
    final graph = PersonalKnowledgeGraph(nodes: nodes, edges: edges);
    var layoutCount = 0;
    Map<String, Offset> positions = {};
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _harness(
        InteractiveKnowledgeGraphWidget(
          graph: graph,
          onLayoutComputed: (count, value) {
            layoutCount = count;
            positions = value;
          },
        ),
      ),
    );
    await tester.pump();

    expect(positions, hasLength(520));
    expect(layoutCount, 1);
    final topLeft = tester.getTopLeft(
      find.byKey(const Key('interactive-knowledge-graph-canvas')),
    );
    await tester.tapAt(topLeft + positions['person-0']!);
    await tester.pump();
    expect(layoutCount, 1);
    expect(tester.takeException(), isNull);
  });
}

Widget _harness(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

PersonalKnowledgeGraph _smallGraph() {
  final observedAt = DateTime.utc(2026, 6, 15);
  return PersonalKnowledgeGraph(
    clock: () => DateTime.utc(2026, 7, 1),
    nodes: [
      GraphNode(
        id: 'person-alex',
        type: NodeType.person,
        label: 'Alex',
        confidence: 0.9,
        evidence: [
          GraphNodeEvidence(
            entryId: 'entry-person',
            observedAt: observedAt,
            confidence: 0.9,
            excerpt: 'Alex was kind and supportive private wording',
            startUtf16: 0,
            endUtf16: 44,
          ),
        ],
      ),
      GraphNode(
        id: 'goal-studio',
        type: NodeType.goal,
        label: 'Build a studio',
        confidence: 0.8,
        evidence: [
          GraphNodeEvidence(
            entryId: 'entry-goal',
            observedAt: observedAt,
            confidence: 0.8,
            excerpt: 'private wording goal',
            startUtf16: 0,
            endUtf16: 20,
          ),
        ],
      ),
    ],
    edges: [
      GraphEdge(
        id: 'alex-studio',
        sourceNodeId: 'person-alex',
        targetNodeId: 'goal-studio',
        type: EdgeType.influences,
        isDirected: true,
        weight: 0.8,
        evidence: [
          GraphEdgeEvidence(
            entryId: 'entry-edge',
            observedAt: observedAt,
            confidence: 0.8,
            excerpt: 'private wording edge',
            startUtf16: 0,
            endUtf16: 20,
          ),
        ],
      ),
    ],
  );
}

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

  // The test binding owns the active semantics tree.
  // ignore: deprecated_member_use
  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return result;
}
