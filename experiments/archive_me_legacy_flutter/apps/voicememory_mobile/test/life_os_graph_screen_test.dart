import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/providers/life_os_providers.dart';
import 'package:voicememory_mobile/services/app_services_providers.dart';
import 'package:voicememory_mobile/ui/screens/life_os/life_os_graph_screen.dart';

void main() {
  testWidgets('shows loading then an inviting empty state', (tester) async {
    final completer = Completer<PersonalKnowledgeGraph>();
    await tester.pumpWidget(_harness((ref) => completer.future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(PersonalKnowledgeGraph());
    await tester.pumpAndSettle();

    expect(find.textContaining('Record your first entries'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('renders the dedicated graph canvas for graph data', (
    tester,
  ) async {
    await tester.pumpWidget(_harness((ref) async => _graph()));
    await tester.pumpAndSettle();

    expect(find.text('Memory Graph'), findsOneWidget);
    expect(find.byKey(const Key('memory_graph_canvas')), findsOneWidget);
    expect(find.byKey(const Key('life_os_graph_search_bar')), findsOneWidget);
    expect(
      find.byKey(const Key('interactive-knowledge-graph-canvas')),
      findsOneWidget,
    );
  });

  testWidgets('SE safe area and 3.2x text keep graph controls scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const media = MediaQueryData(
      size: Size(320, 568),
      padding: EdgeInsets.only(top: 44, bottom: 34),
      textScaler: TextScaler.linear(3.2),
    );

    await tester.pumpWidget(
      _harness((ref) async => _graph(), mediaData: media),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('life_os_graph_search_bar')), findsOneWidget);
    expect(
      find.byKey(const Key('interactive-knowledge-graph-canvas')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('evidence query mode is chronological and opens exact entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        (ref) async => _graph(),
        initialLocation: '/life-os/graph?view=evidence&nodeId=person-alex',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evidence mentions'), findsOneWidget);
    expect(find.text('2026-06-15'), findsOneWidget);
    expect(find.text('Entry ID: entry-1'), findsOneWidget);
    expect(find.textContaining('private transcript'), findsNothing);

    await tester.tap(find.text('Entry ID: entry-1'));
    await tester.pumpAndSettle();
    expect(find.text('Entry opened: entry-1'), findsOneWidget);
  });
}

Widget _harness(
  Future<PersonalKnowledgeGraph> Function(Ref ref) create, {
  String initialLocation = '/life-os/graph',
  MediaQueryData? mediaData,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: LifeOsGraphScreen.route,
        builder: (context, state) => LifeOsGraphScreen(
          view: state.uri.queryParameters['view'],
          nodeId: state.uri.queryParameters['nodeId'],
        ),
      ),
      GoRoute(
        path: '/entry/:id',
        builder: (context, state) =>
            Text('Entry opened: ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/record',
        builder: (context, state) => const Text('Record route'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      knowledgeGraphProvider.overrideWith(create),
      journalEntriesStreamProvider.overrideWith((ref) => const Stream.empty()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: mediaData == null
          ? null
          : (context, child) => MediaQuery(data: mediaData, child: child!),
    ),
  );
}

PersonalKnowledgeGraph _graph() => PersonalKnowledgeGraph(
  nodes: [
    GraphNode(
      id: 'person-alex',
      type: NodeType.person,
      label: 'Alex',
      confidence: 0.9,
      evidence: [
        GraphNodeEvidence(
          entryId: 'entry-1',
          observedAt: DateTime.utc(2026, 6, 15),
          confidence: 0.9,
          excerpt: 'private transcript must not render',
          startUtf16: 0,
          endUtf16: 'private transcript must not render'.length,
        ),
      ],
    ),
  ],
);
