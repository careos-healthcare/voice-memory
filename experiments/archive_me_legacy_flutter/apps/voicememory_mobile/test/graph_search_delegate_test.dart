import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/search/local_vector_search_engine.dart';
import 'package:voicememory_mobile/ui/screens/life_os/graph_search_delegate.dart';

void main() {
  testWidgets('searches locally and returns excerpt-free evidence hits', (
    tester,
  ) async {
    final graph = PersonalKnowledgeGraph(
      nodes: [
        GraphNode(
          id: 'person-sarah',
          type: NodeType.person,
          label: 'Sarah',
          confidence: 0.9,
          evidence: [
            GraphNodeEvidence(
              entryId: 'entry-private',
              observedAt: DateTime.utc(2026, 7, 23),
              confidence: 0.9,
              excerpt: 'private conversation details',
              startUtf16: 0,
              endUtf16: 28,
            ),
          ],
        ),
      ],
    );
    final engine = LocalVectorSearchEngine(
      graph: graph,
      lexicalIndex: InMemoryLexicalIndex(),
    );
    addTearDown(engine.dispose);
    KnowledgeGraphSearchHit? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraphSearchLauncher(
            engineLoader: () async => engine,
            onSelected: (hit) => selected = hit,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('life_os_graph_search_bar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('life_os_graph_search_bar')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('magical_search_overlay')), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('magical_search_field')),
        matching: find.byType(EditableText),
      ),
      'Conversations with Sarah',
    );
    await tester.pumpAndSettle();

    final result = find.byKey(
      const Key('life_os_graph_search_result_person-sarah'),
    );
    expect(result, findsOneWidget);
    expect(find.text('Person · 1 evidence mention'), findsOneWidget);
    expect(find.textContaining('private conversation details'), findsNothing);

    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(selected?.node.id, 'person-sarah');
    expect(selected?.node.evidence, isEmpty);
    expect(selected?.evidenceLinks.single.entryId, 'entry-private');
  });
}
