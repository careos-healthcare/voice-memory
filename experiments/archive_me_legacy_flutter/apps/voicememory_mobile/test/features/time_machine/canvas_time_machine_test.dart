import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/time_machine/ui/canvas_time_machine_slider.dart';
import 'package:voicememory_mobile/ui/screens/life_os/interactive_knowledge_graph_widget.dart';

void main() {
  testWidgets('slider exposes markers and scrubs to a historical date', (
    tester,
  ) async {
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CanvasTimeMachineSlider(
              start: DateTime.utc(2025),
              end: DateTime.utc(2026),
              selected: DateTime.utc(2026),
              markers: [DateTime.utc(2025, 6)],
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('canvas-time-machine-slider')), findsOneWidget);
    expect(find.text('History Mode'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('canvas-time-machine-control')),
      const Offset(-180, 0),
    );
    await tester.pump();
    expect(selected, isNotNull);
    expect(selected!.isBefore(DateTime.utc(2026)), isTrue);
  });

  testWidgets('history mode locks mutations and opens historical details', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final graph = _graph();
    Map<String, Offset> positions = const {};
    var draftRequested = false;
    var connectionRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveKnowledgeGraphWidget(
            graph: graph,
            height: 520,
            readOnly: true,
            targetTime: DateTime.utc(2025, 6),
            onLayoutComputed: (_, value) => positions = value,
            onEmptySpaceLongPress: (_) => draftRequested = true,
            onManualConnection: (_, _) => connectionRequested = true,
          ),
        ),
      ),
    );
    await tester.pump();
    final canvas = find.byKey(const Key('interactive-knowledge-graph-canvas'));
    final topLeft = tester.getTopLeft(canvas);
    final source = topLeft + positions['node-a']!;
    final semanticsNode = _semanticsNode(
      tester,
      'Topic, Alpha, 1 evidence entry',
    );
    expect(semanticsNode, isNotNull);
    // The test binding owns the active semantics tree.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      semanticsNode!.id,
      SemanticsAction.tap,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('historical-node-sheet')), findsOneWidget);
    expect(find.textContaining('Read only'), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('historical-node-sheet'))),
    ).pop();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.longPressAt(topLeft + const Offset(700, 480));
    await tester.pump();
    expect(draftRequested, isFalse);

    final target = topLeft + positions['node-b']!;
    final gesture = await tester.startGesture(source);
    await gesture.moveTo(target);
    await tester.pump();
    expect(find.byKey(const Key('manual-edge-preview')), findsNothing);
    await gesture.up();
    expect(connectionRequested, isFalse);
    semantics.dispose();
  });
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

PersonalKnowledgeGraph _graph() {
  GraphNode node(String id, String label) => GraphNode(
    id: id,
    type: NodeType.topic,
    label: label,
    confidence: .7,
    evidence: [
      GraphNodeEvidence(
        entryId: 'entry-$id',
        observedAt: DateTime.utc(2025),
        confidence: .7,
        excerpt: label,
        startUtf16: 0,
        endUtf16: label.length,
      ),
    ],
  );
  return PersonalKnowledgeGraph(
    nodes: [node('node-a', 'Alpha'), node('node-b', 'Beta')],
  );
}
