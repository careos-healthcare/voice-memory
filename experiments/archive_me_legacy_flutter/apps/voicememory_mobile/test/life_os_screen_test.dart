import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/providers/life_os_providers.dart';
import 'package:voicememory_mobile/screens/life_os_screen.dart';
import 'package:voicememory_mobile/widgets/accessibility/accessible_primary_surface.dart';

void main() {
  testWidgets('shows an accessible empty evidence state without app globals', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(PersonalKnowledgeGraph(clock: () => DateTime.utc(2026, 7, 23))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Life Story'), findsOneWidget);
    expect(find.text('Your Life Story'), findsOneWidget);
    expect(
      find.textContaining('No graph evidence is available'),
      findsOneWidget,
    );
    expect(find.byType(AccessiblePrimarySurface), findsOneWidget);
    expect(find.byKey(const Key('llama_model_download_card')), findsOneWidget);
    expect(
      find.byKey(const Key('llama_model_download_source_life_os')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('life-os-historical-query')), findsOneWidget);
  });

  testWidgets('historical query shows labels and exact entry ID citations', (
    tester,
  ) async {
    const firstExcerpt = 'private transcript wording one';
    const secondExcerpt = 'private transcript wording two';
    final graph = PersonalKnowledgeGraph(
      clock: () => DateTime.utc(2026, 7, 23),
      nodes: [
        GraphNode(
          id: 'person-alex',
          type: NodeType.person,
          label: 'Alex',
          confidence: 0.9,
          evidence: [
            GraphNodeEvidence(
              entryId: 'entry-exact-001',
              observedAt: DateTime.utc(2026, 6, 22),
              confidence: 0.9,
              excerpt: firstExcerpt,
              startUtf16: 0,
              endUtf16: firstExcerpt.length,
            ),
            GraphNodeEvidence(
              entryId: 'entry-exact-002',
              observedAt: DateTime.utc(2026, 6, 24),
              confidence: 0.8,
              excerpt: secondExcerpt,
              startUtf16: 0,
              endUtf16: secondExcerpt.length,
            ),
          ],
        ),
        GraphNode(
          id: 'goal-company',
          type: NodeType.goal,
          label: 'Build a company',
          confidence: 0.8,
          evidence: [
            GraphNodeEvidence(
              entryId: 'entry-exact-001',
              observedAt: DateTime.utc(2026, 6, 22),
              confidence: 0.8,
              excerpt: firstExcerpt,
              startUtf16: 0,
              endUtf16: firstExcerpt.length,
            ),
            GraphNodeEvidence(
              entryId: 'entry-exact-002',
              observedAt: DateTime.utc(2026, 6, 24),
              confidence: 0.8,
              excerpt: secondExcerpt,
              startUtf16: 0,
              endUtf16: secondExcerpt.length,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(_harness(graph));
    await tester.pumpAndSettle();

    expect(find.text('Story evidence'), findsOneWidget);
    expect(find.byKey(const Key('llama_model_download_card')), findsOneWidget);
    expect(
      find.byKey(const Key('llama_model_download_source_life_os')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('life-os-visual-graph-entry')), findsOneWidget);
    expect(find.text('Visual Graph Canvas'), findsOneWidget);
    expect(find.text('Life story and chapters'), findsNothing);
    expect(find.text('Coaching observations'), findsNothing);
    expect(find.text('Conditional forecasts'), findsNothing);

    await _scrollDownUntilVisible(
      tester,
      find.byKey(const Key('life-os-historical-query')),
    );
    await tester.enterText(
      find.byKey(const Key('life-os-historical-query')),
      'one month ago',
    );
    await tester.tap(find.text('Search evidence'));
    await tester.pumpAndSettle();

    await _scrollDownUntilVisible(tester, find.text('Snapshot labels'));
    expect(find.text('Snapshot labels'), findsOneWidget);
    expect(find.text('Entry ID: entry-exact-001'), findsOneWidget);
    expect(find.text('Entry ID: entry-exact-002'), findsOneWidget);
    expect(find.textContaining(firstExcerpt), findsNothing);
    expect(find.textContaining(secondExcerpt), findsNothing);
  });
}

Widget _harness(PersonalKnowledgeGraph graph) => ProviderScope(
  overrides: [knowledgeGraphProvider.overrideWith((ref) async => graph)],
  child: const MaterialApp(home: LifeOsScreen()),
);

Future<void> _scrollDownUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 12 && finder.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
  }
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await tester.pump();
}
