import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/core/config/v1_navigation_guard.dart';
import 'package:voicememory_mobile/features/archive_semantic_search/archive_semantic_query_parser.dart';
import 'package:voicememory_mobile/features/archive_semantic_search/archive_semantic_search_models.dart';
import 'package:voicememory_mobile/screens/archive_semantic_search_screen.dart';

void main() {
  testWidgets(
    'shows local privacy copy, accessible examples, and empty state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArchiveSemanticSearchScreen(
            searcher: (query) async => _page(query, const []),
          ),
        ),
      );
      expect(
        find.text('Searched on this device. Queries are not saved or sent.'),
        findsOneWidget,
      );
      expect(
        find.text('Show me every time I mentioned work burnout'),
        findsOneWidget,
      );
      expect(find.text('When was I happiest?'), findsOneWidget);

      await tester.tap(find.text('When was I happiest?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No grounded mentions'), findsOneWidget);
    },
  );

  testWidgets('latest submitted query wins', (tester) async {
    final first = Completer<ArchiveSemanticSearchPage>();
    final second = Completer<ArchiveSemanticSearchPage>();
    await tester.pumpWidget(
      MaterialApp(
        home: ArchiveSemanticSearchScreen(
          searcher: (query) => query == 'first' ? first.future : second.future,
        ),
      ),
    );
    final field = find.byKey(const Key('archive-semantic-search-field'));
    await tester.enterText(field, 'first');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(field, 'second');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    second.complete(_page('second', [_result('second', 'second result')]));
    await tester.pump();
    first.complete(_page('first', [_result('first', 'first result')]));
    await tester.pumpAndSettle();
    expect(find.textContaining('second result'), findsOneWidget);
    expect(find.textContaining('first result'), findsNothing);
  });

  testWidgets('SE 3.2x search list includes keyboard clearance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            padding: EdgeInsets.only(top: 20, bottom: 34),
            viewInsets: EdgeInsets.only(bottom: 260),
            textScaler: TextScaler.linear(3.2),
          ),
          child: child!,
        ),
        home: ArchiveSemanticSearchScreen(
          searcher: (query) async => _page(query, const []),
        ),
      ),
    );

    final list = tester.widget<ListView>(find.byType(ListView).first);
    final padding = list.padding!.resolve(TextDirection.ltr);
    expect(padding.bottom, greaterThanOrEqualTo(276));
    expect(tester.takeException(), isNull);
  });

  testWidgets('result opens the journal entry route on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/archive-search',
      routes: [
        GoRoute(
          path: '/archive-search',
          builder: (_, _) => ArchiveSemanticSearchScreen(
            searcher: (query) async =>
                _page(query, [_result('entry-1', 'joyful result')]),
          ),
        ),
        GoRoute(
          path: '/entry/:id',
          builder: (_, state) => Text('opened ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(
      find.byKey(const Key('archive-semantic-search-field')),
      'joyful',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final resultCard = find.byKey(const Key('archive-semantic-result-entry-1'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(resultCard.first);
    await tester.pumpAndSettle();
    expect(find.text('opened entry-1'), findsOneWidget);
    expect(V1NavigationGuard.isAllowed('/archive-search'), isTrue);
  });

  testWidgets('result custom actions repeat explanation and open entry', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final router = GoRouter(
      initialLocation: '/archive-search',
      routes: [
        GoRoute(
          path: '/archive-search',
          builder: (_, _) => ArchiveSemanticSearchScreen(
            searcher: (query) async =>
                _page(query, [_result('entry-action', 'action result')]),
          ),
        ),
        GoRoute(
          path: '/entry/:id',
          builder: (_, state) => Text('opened ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final field = find.byKey(const Key('archive-semantic-search-field'));
    await tester.enterText(field, 'action');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final node = _semanticsNode(
      tester,
      'Journal result from Jul 20, 2026. Match reason: Exact wording. '
      'Snippet: action result',
    )!;
    _performCustomAction(tester, node, 'Repeat match explanation');
    await tester.pump();
    expect(tester.takeException(), isNull);

    _performCustomAction(tester, node, 'Open result');
    await tester.pumpAndSettle();
    expect(find.text('opened entry-action'), findsOneWidget);
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

void _performCustomAction(
  WidgetTester tester,
  SemanticsNode node,
  String label,
) {
  final id = CustomSemanticsAction.getIdentifier(
    CustomSemanticsAction(label: label),
  );
  expect(node.getSemanticsData().customSemanticsActionIds, contains(id));
  // The test binding owns the active semantics tree.
  // ignore: deprecated_member_use
  tester.binding.pipelineOwner.semanticsOwner!.performAction(
    node.id,
    SemanticsAction.customAction,
    id,
  );
}

ArchiveSemanticSearchPage _page(
  String input,
  List<ArchiveSemanticSearchResult> results,
) {
  final query = const ArchiveSemanticQueryParser().parse(input);
  return ArchiveSemanticSearchPage(
    query: query,
    results: results,
    totalResults: results.length,
    hasMore: false,
    insufficientReason: results.isEmpty
        ? 'No grounded mentions matched.'
        : null,
  );
}

ArchiveSemanticSearchResult _result(String id, String snippet) =>
    ArchiveSemanticSearchResult(
      entryId: id,
      date: DateTime.utc(2026, 7, 20),
      score: 1,
      reason: 'Exact wording',
      snippet: snippet,
      snippetStartUtf16: 0,
      snippetEndUtf16: snippet.length,
      evidenceStartUtf16: 0,
      evidenceEndUtf16: snippet.length,
    );
