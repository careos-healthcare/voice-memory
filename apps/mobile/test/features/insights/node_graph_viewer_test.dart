import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/insights/models/theory_connection_graph.dart';
import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';
import 'package:archiveme_mobile/features/insights/widgets/node_graph_viewer.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrackedTheory _sampleTheory({
  List<TheoryEvidenceQuote> supporting = const [],
  List<TheoryEvidenceQuote> contradicting = const [],
  TheoryRankingInspection? inspection,
}) {
  return TrackedTheory(
    id: 'theory-1',
    statement: 'Partner conflict keeps surfacing at home',
    confidence: 42,
    confidenceDelta: 3,
    supportingEvidenceCount: supporting.length,
    contradictingEvidenceCount: contradicting.length,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 2, 1),
    status: TheoryStatus.active,
    supportingEvidence: supporting,
    contradictingEvidence: contradicting,
    whatChanged: const [],
    source: 'belief_catalog',
    inspection: inspection,
  );
}

TheoryEvidenceQuote _quote({
  required String entryId,
  String dateLabel = 'Jan 12',
  String quote = 'We argued about chores again.',
  bool withPlayback = false,
}) {
  return TheoryEvidenceQuote(
    entryId: entryId,
    dateLabel: dateLabel,
    quote: quote,
    audioId: withPlayback ? 'audio-$entryId' : null,
    startTimestampMs: withPlayback ? 1200 : null,
    endTimestampMs: withPlayback ? 4800 : null,
    chunkId: withPlayback ? 'chunk-$entryId' : null,
  );
}

void main() {
  group('TheoryConnectionGraphBuilder', () {
    const builder = TheoryConnectionGraphBuilder();

    test('builds theme, memory, and counter nodes with edges from theme', () {
      final theory = _sampleTheory(
        supporting: [
          _quote(entryId: 'entry-a', dateLabel: 'Jan 10'),
          _quote(entryId: 'entry-b', dateLabel: 'Jan 11'),
        ],
        inspection: const TheoryRankingInspection(
          confidenceBreakdown: TheoryConfidenceBreakdown(
            volumePoints: 10,
            consistencyPoints: 8,
            recencyPoints: 6,
            contradictionPenalty: 0,
            counterPenalty: 4,
            lowEvidenceMultiplierApplied: false,
            staleMultiplierApplied: false,
            rawTotalBeforeModifiers: 18,
            finalPercent: 18,
          ),
          rankBreakdown: TheoryRankBreakdown(
            volumePoints: 8,
            consistencyPoints: 6,
            recencyPoints: 4,
            contradictionPoints: 0,
            surprisePoints: 0,
            counterQualityPoints: 2,
            finalScore: 20,
          ),
          retrievedChunks: [
            TheoryRetrievalChunk(
              entryId: 'entry-c',
              excerpt: 'Maybe I am overreacting about small things.',
              role: TheoryRetrievalRole.counter,
            ),
          ],
          finalConfidencePercent: 18,
          finalRankScore: 20,
        ),
      );

      final graph = builder.build(theory);

      expect(graph.nodes.length, 4);
      expect(graph.edges.length, 3);
      expect(
        graph.nodes.where((n) => n.kind == InsightGraphNodeKind.theme).length,
        1,
      );
      expect(
        graph.nodes.where((n) => n.kind == InsightGraphNodeKind.memory).length,
        2,
      );
      expect(
        graph.nodes
            .where((n) => n.kind == InsightGraphNodeKind.counterEvidence)
            .length,
        1,
      );
      for (final edge in graph.edges) {
        expect(edge.fromId, graph.themeNodeId);
      }
      expect(graph.canvasSize.width, greaterThan(0));
      expect(graph.canvasSize.height, greaterThan(0));
    });

    test('deduplicates memory nodes by entry id', () {
      final theory = _sampleTheory(
        supporting: [
          _quote(entryId: 'entry-a'),
          _quote(entryId: 'entry-a', dateLabel: 'Jan 13'),
        ],
      );

      final graph = builder.build(theory);
      final memories = graph.nodes
          .where((n) => n.kind == InsightGraphNodeKind.memory)
          .toList();

      expect(memories.length, 1);
      expect(memories.single.entryId, 'entry-a');
    });
  });

  group('NodeGraphViewer', () {
    testWidgets('renders graph canvas and legend', (tester) async {
      final theory = _sampleTheory(
        supporting: [_quote(entryId: 'entry-a')],
      );
      final graph = const TheoryConnectionGraphBuilder().build(theory);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 520,
              width: 360,
              child: NodeGraphViewer(graph: graph),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('node_graph_interactive_viewer')), findsOneWidget);
      expect(find.byKey(const Key('node_graph_canvas')), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Memory'), findsOneWidget);
      expect(find.text('Counter-evidence'), findsOneWidget);
    });

    testWidgets('expands memory node on tap and fires callbacks', (tester) async {
      final theory = _sampleTheory(
        supporting: [
          _quote(entryId: 'entry-a', withPlayback: true),
        ],
      );
      final graph = const TheoryConnectionGraphBuilder().build(theory);
      InsightGraphNode? tapped;
      TheoryEvidenceQuote? played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 520,
              width: 360,
              child: NodeGraphViewer(
                graph: graph,
                onNodeTap: (node) => tapped = node,
                onCitationPlay: (quote) => played = quote,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('node_hit_memory-entry-a')));
      await tester.pumpAndSettle();

      expect(tapped?.entryId, 'entry-a');
      expect(find.byKey(const Key('node_graph_expanded_memory-entry-a')), findsOneWidget);
      expect(find.text('Open transcript'), findsOneWidget);

      await tester.tap(find.byKey(const Key('citation_badge_chunk-entry-a')));
      await tester.pumpAndSettle();

      expect(played?.entryId, 'entry-a');
    });

    test('NodeGraphPainter maps node kinds to design tokens', () {
      expect(
        NodeGraphPainter.colorForKind(InsightGraphNodeKind.theme),
        AppColors.accentSecondary,
      );
      expect(
        NodeGraphPainter.colorForKind(InsightGraphNodeKind.memory),
        AppColors.accentPrimary,
      );
      expect(
        NodeGraphPainter.colorForKind(InsightGraphNodeKind.counterEvidence),
        AppColors.warning,
      );
    });
  });
}
