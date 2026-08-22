import 'package:archiveme_mobile/features/graph/domain/graph_topology.dart';
import 'package:archiveme_mobile/features/graph/presentation/graph_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GraphCanvas LOD', () {
    test('uses low detail below scale threshold', () {
      final controller = TransformationController(
        Matrix4.diagonal3Values(0.5, 0.5, 1),
      );
      expect(graphCanvasUsesLowDetail(controller), isTrue);
    });

    test('uses high detail at or above scale threshold', () {
      final controller = TransformationController(
        Matrix4.diagonal3Values(0.6, 0.6, 1),
      );
      expect(graphCanvasUsesLowDetail(controller), isFalse);
    });
  });

  testWidgets('renders interactive graph canvas', (tester) async {
    const topology = GraphTopology(
      nodes: [
        GraphNodeRecord(
          id: 'n1',
          entryId: 'e1',
          kind: 'journal_entry',
          label: 'Memory',
        ),
        GraphNodeRecord(
          id: 'n2',
          entryId: 'e1',
          kind: 'theme',
          label: 'Focus',
        ),
      ],
      links: [
        GraphLinkRecord(
          fromNodeId: 'n1',
          toNodeId: 'n2',
          relation: 'mentions_theme',
          weight: 1,
        ),
      ],
      seedEntryId: 'e1',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GraphCanvas(
            topology: topology,
            canvasSize: Size(400, 300),
            warmupTicks: 4,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('graph_canvas_interactive_viewer')), findsOneWidget);
    expect(find.byKey(const Key('graph_canvas_painter')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
  });
}
