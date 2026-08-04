import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/memory_graph/memory_graph_canvas.dart';

void main() {
  for (final width in <double>[390, 430]) {
    testWidgets('graph exposes only three primary actions at ${width}px', (
      tester,
    ) async {
      var searchTaps = 0;
      var filterTaps = 0;
      var moreTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: MemoryGraphPrimaryToolbar(
                  onSearch: () => searchTaps += 1,
                  onFilter: () => filterTaps += 1,
                  onMore: () => moreTaps += 1,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
      final semanticsWidget = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Memory Graph controls' &&
              widget.properties.button != true,
        ),
      );
      expect(semanticsWidget.properties.label, 'Memory Graph controls');
      final moreSemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label == 'More graph actions',
        ),
      );
      expect(moreSemantics.properties.hint, 'Opens Advanced Labs and Systems');

      await tester.tap(find.byKey(const Key('memory_graph_search')));
      await tester.tap(find.byKey(const Key('memory_graph_filter')));
      await tester.tap(find.byKey(const Key('memory_graph_more')));
      expect((searchTaps, filterTaps, moreTaps), (1, 1, 1));
    });
  }

  testWidgets('More opens the Advanced Labs and Systems sheet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 700,
              child: MemoryGraphCanvas(graph: PersonalKnowledgeGraph()),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('memory_graph_more')));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Labs & Systems'), findsOneWidget);
    expect(find.text('Graph overview'), findsOneWidget);
    expect(find.text('Life Dashboard'), findsOneWidget);
  });
}
