import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/providers/life_os_providers.dart';
import 'package:voicememory_mobile/features/archive_semantic_search/archive_semantic_query_parser.dart';
import 'package:voicememory_mobile/features/archive_semantic_search/archive_semantic_search_models.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainability_history_store.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_widgets.dart';
import 'package:voicememory_mobile/features/insights/archive_insight.dart';
import 'package:voicememory_mobile/features/onboarding_future_value/future_preview_screen.dart';
import 'package:voicememory_mobile/features/onboarding_future_value/onboarding_future_value_fixtures.dart';
import 'package:voicememory_mobile/features/pattern_recognition/pattern_recognition_dashboard_provider.dart';
import 'package:voicememory_mobile/l10n/generated/app_localizations.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/account_auth_screen.dart';
import 'package:voicememory_mobile/screens/archive_semantic_search_screen.dart';
import 'package:voicememory_mobile/screens/onboarding_intent_screen.dart';
import 'package:voicememory_mobile/screens/onboarding_loop_screen.dart';
import 'package:voicememory_mobile/screens/pattern_recognition_dashboard_screen.dart';
import 'package:voicememory_mobile/screens/subscription_review_preview.dart';
import 'package:voicememory_mobile/ui/screens/life_os/life_os_graph_screen.dart';
import 'package:voicememory_mobile/ui/screens/life_os/interactive_knowledge_graph_widget.dart';
import 'package:voicememory_mobile/widgets/main_shell.dart';

import 'support/ios_layout_assertions.dart';
import 'support/ios_device_viewport.dart';

// The original high-stress regression set remains intact for established
// Future Preview, search, explainability, and graph-widget coverage.
const _matrix = <({IosDeviceViewport viewport, double textScale})>[
  (
    viewport: IosDeviceViewport.iPhoneSe,
    textScale: IosDynamicType.accessibilityLarge,
  ),
  (
    viewport: IosDeviceViewport.iPhoneSe,
    textScale: IosDynamicType.accessibilityExtraExtraExtraLarge,
  ),
  (
    viewport: IosDeviceViewport.pro393,
    textScale: IosDynamicType.accessibilityExtraExtraExtraLarge,
  ),
  (
    viewport: IosDeviceViewport.iPhone375Landscape,
    textScale: IosDynamicType.accessibilityExtraLarge,
  ),
  (
    viewport: IosDeviceViewport.proMaxLandscape,
    textScale: IosDynamicType.accessibilityExtraExtraExtraLarge,
  ),
];

// PR coverage is deliberately stratified rather than a device × scale × screen
// Cartesian product. Each practical surface gets one representative profile.
const _prMatrix = <({IosDeviceViewport viewport, double textScale})>[
  (viewport: IosDeviceViewport.iPhoneSe, textScale: 1),
  (
    viewport: IosDeviceViewport.iPhoneSe,
    textScale: IosDynamicType.accessibilityExtraExtraExtraLarge,
  ),
  (
    viewport: IosDeviceViewport.iPhone375,
    textScale: IosDynamicType.accessibilityLarge,
  ),
  (viewport: IosDeviceViewport.pro393, textScale: 1),
  (
    viewport: IosDeviceViewport.pro393,
    textScale: IosDynamicType.accessibilityExtraExtraExtraLarge,
  ),
  (viewport: IosDeviceViewport.pro402, textScale: 1),
  (viewport: IosDeviceViewport.proMax, textScale: 1),
  (
    viewport: IosDeviceViewport.pro393Landscape,
    textScale: IosDynamicType.accessibilityExtraLarge,
  ),
];

void main() {
  test('canonical viewport registry includes every required orientation', () {
    expect(
      IosDeviceViewport.portrait.map((device) => device.logicalSize),
      const [
        Size(320, 568),
        Size(375, 667),
        Size(390, 844),
        Size(393, 852),
        Size(402, 874),
        Size(430, 932),
      ],
    );
    expect(
      IosDeviceViewport.landscape.map((device) => device.logicalSize),
      const [
        Size(568, 320),
        Size(667, 375),
        Size(844, 390),
        Size(852, 393),
        Size(874, 402),
        Size(932, 430),
      ],
    );
    expect(IosDynamicType.presets, const [1.0, 2.0, 2.5, 3.2]);
    expect(
      IosDeviceViewport.pro393.withKeyboard().viewInsets.bottom,
      greaterThan(0),
    );
  });

  group('FuturePreviewScreen iOS matrix', () {
    for (final entry in _matrix) {
      testWidgets(
        '${entry.viewport.name} at ${entry.textScale}x: stages and sheets',
        (tester) async {
          applyIosDeviceViewport(
            tester,
            entry.viewport,
            textScale: entry.textScale,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: FuturePreviewScreen(onEvent: (_) {}, onStart: () {}),
            ),
          );
          await tester.pumpAndSettle();

          for (var stage = 0; stage < 3; stage++) {
            final chip = find.byKey(Key('future_preview_stage_chip_$stage'));
            await _scrollUntilVisible(tester, chip);
            await tester.tap(chip);
            await _pumpStable(tester);
            final action = find.byKey(
              Key(stage == 2 ? 'future_preview_start' : 'future_preview_next'),
            );
            await _scrollUntilVisible(tester, action);
            expect(action, findsOneWidget);
            _expectTapTarget(tester, action);
            _expectInsideSafeHorizontalBounds(tester, action, entry.viewport);
            _expectTapSemantics(tester, action);
            _expectNoLayoutException(tester);
          }

          final currentStage = find.byKey(
            const Key('future_preview_stage_scroll_2'),
          );
          await _openWithin(
            tester,
            find.descendant(
              of: currentStage,
              matching: find.byKey(
                const Key('explainable_alternatives_button'),
              ),
            ),
            _verticalScrollableWithin(currentStage),
          );
          _expectSheetInsideSafeArea(
            tester,
            find.byKey(const Key('explainable_alternatives_sheet')),
            entry.viewport,
          );
          _expectNoLayoutException(tester);
          await _dismissSheet(
            tester,
            find.byKey(const Key('explainable_alternatives_sheet')),
          );

          final evidence = find.descendant(
            of: currentStage,
            matching: find.byKey(
              const ValueKey(
                'explainable_evidence_onboarding-preview-entry-1_15',
              ),
            ),
          );
          await _openWithin(
            tester,
            evidence,
            _verticalScrollableWithin(currentStage),
          );
          _expectSheetInsideSafeArea(
            tester,
            find.byKey(const Key('future_preview_evidence_sheet')),
            entry.viewport,
          );
          _expectNoLayoutException(tester);
          await _dismissSheet(
            tester,
            find.byKey(const Key('future_preview_evidence_sheet')),
          );

          await _openWithin(
            tester,
            find.descendant(
              of: currentStage,
              matching: find.byKey(
                const Key('future_preview_graph_node_habit'),
              ),
            ),
            _verticalScrollableWithin(currentStage),
          );
          _expectSheetInsideSafeArea(
            tester,
            find.byKey(const Key('future_preview_node_evidence_sheet')),
            entry.viewport,
          );
          _expectNoLayoutException(tester);
          await _dismissSheet(
            tester,
            find.byKey(const Key('future_preview_node_evidence_sheet')),
          );

          await _openWithin(
            tester,
            find.descendant(
              of: currentStage,
              matching: find.byKey(const Key('explainable_history_button')),
            ),
            _verticalScrollableWithin(currentStage),
          );
          _expectSheetInsideSafeArea(
            tester,
            find.byKey(const Key('future_preview_history_sheet')),
            entry.viewport,
          );
          _expectNoLayoutException(tester);
        },
      );
    }
  });

  group('ArchiveSemanticSearchScreen iOS matrix', () {
    for (final entry in _matrix) {
      testWidgets(
        '${entry.viewport.name} at ${entry.textScale}x: initial/loading/results/error',
        (tester) async {
          applyIosDeviceViewport(
            tester,
            entry.viewport,
            textScale: entry.textScale,
          );
          final pending = Completer<ArchiveSemanticSearchPage>();
          await tester.pumpWidget(_archiveApp((_) => pending.future));
          await tester.pumpAndSettle();
          await _scrollUntilVisible(
            tester,
            find.byKey(const Key('archive-semantic-search-field')),
          );
          expect(
            find.byKey(const Key('archive-semantic-search-field')),
            findsOneWidget,
          );
          _expectSafeBody(tester, entry.viewport);

          await _submitArchiveQuery(tester);
          await _scrollUntilVisible(
            tester,
            find.byType(CircularProgressIndicator),
          );
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          _expectNoLayoutException(tester);
          pending.complete(_archivePage(results: [_archiveResult()]));
          await tester.pumpAndSettle();

          final result = find.byKey(
            const Key('archive-semantic-result-entry-layout'),
          );
          await tester.ensureVisible(result);
          await tester.pumpAndSettle();
          expect(result, findsOneWidget);
          _expectTapTarget(tester, result);
          _expectInsideSafeHorizontalBounds(tester, result, entry.viewport);
          _expectNoLayoutException(tester);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pumpWidget(
            _archiveApp((_) async => throw StateError('offline fixture')),
          );
          await tester.pumpAndSettle();
          await _submitArchiveQuery(tester);
          await tester.pumpAndSettle();
          final retry = find.text('Try again');
          await _scrollUntilVisible(tester, retry);
          expect(retry, findsOneWidget);
          _expectTapTarget(
            tester,
            find.widgetWithText(TextButton, 'Try again'),
          );
          _expectNoLayoutException(tester);
        },
      );
    }
  });

  group('ExplainableConclusionCard iOS matrix', () {
    for (final entry in _matrix) {
      testWidgets(
        '${entry.viewport.name} at ${entry.textScale}x: evidence/alternatives/history',
        (tester) async {
          applyIosDeviceViewport(
            tester,
            entry.viewport,
            textScale: entry.textScale,
          );
          final fixtures = OnboardingFutureValueFixtures.sample;
          var evidenceSelected = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Builder(
                        builder: (context) => ExplainableConclusionCard(
                          conclusion: fixtures.validatedFiveMoment,
                          onEvidenceSelected: (_, _) => evidenceSelected = true,
                          onShowHistory: () => ExplainableHistorySheet.show(
                            context,
                            entries: [
                              ExplainabilityHistoryEntry(
                                conclusion: fixtures.fiveMomentConclusion,
                                appendedAt: DateTime.utc(2026, 7, 1),
                              ),
                            ],
                            canonicalTranscripts: fixtures.canonicalTranscripts,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final evidence = find
              .byKey(
                const ValueKey(
                  'explainable_evidence_onboarding-preview-entry-1_15',
                ),
              )
              .first;
          await _openVisible(tester, evidence);
          expect(evidenceSelected, isTrue);
          _expectTapTarget(tester, evidence);

          await _openVisible(
            tester,
            find.byKey(const Key('explainable_alternatives_button')),
          );
          _expectSheetInsideSafeArea(
            tester,
            find.byKey(const Key('explainable_alternatives_sheet')),
            entry.viewport,
          );
          _expectNoLayoutException(tester);
          await _dismissSheet(
            tester,
            find.byKey(const Key('explainable_alternatives_sheet')),
          );

          await _openVisible(
            tester,
            find.byKey(const Key('explainable_history_button')),
          );
          _expectSheetInsideSafeArea(
            tester,
            find.byKey(const Key('explainable_history_sheet')),
            entry.viewport,
          );
          _expectNoLayoutException(tester);
        },
      );
    }
  });

  group('Life OS graph iOS matrix', () {
    for (final entry in _matrix) {
      testWidgets(
        '${entry.viewport.name} at ${entry.textScale}x: controls/list/detail',
        (tester) async {
          applyIosDeviceViewport(
            tester,
            entry.viewport,
            textScale: entry.textScale,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: InteractiveKnowledgeGraphWidget(
                      graph: _graph(),
                      height: 360,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final filter = find.byKey(const Key('knowledge-graph-filter-menu'));
          expect(filter, findsOneWidget);
          _expectTapTarget(tester, filter);
          expect(
            find.byKey(const Key('interactive-knowledge-graph-canvas')),
            findsOneWidget,
          );
          _expectNoLayoutException(tester);

          await _openVisible(
            tester,
            find.byKey(const Key('knowledge-graph-list-toggle')),
          );
          expect(
            find.byKey(const Key('knowledge-graph-entity-list')),
            findsOneWidget,
          );
          final entityList = find.byKey(
            const Key('knowledge-graph-entity-list'),
          );
          await _openWithin(
            tester,
            find.byKey(const Key('knowledge-graph-entity-person-layout')),
            _verticalScrollableWithin(entityList),
          );
          final panel = find.byKey(const Key('knowledge-graph-detail-panel'));
          expect(panel, findsOneWidget);
          final evidenceAction = find.widgetWithText(
            OutlinedButton,
            'View Evidence Mentions',
          );
          final detailScrollable = _verticalScrollableWithin(
            find.byKey(const Key('knowledge-graph-detail-scroll')),
          );
          await tester.scrollUntilVisible(
            evidenceAction,
            120,
            scrollable: detailScrollable,
            maxScrolls: 50,
          );
          final visibleEvidenceAction = await _makeVisibleWithin(
            tester,
            evidenceAction,
            detailScrollable,
          );
          _expectTapTarget(tester, evidenceAction);
          expect(visibleEvidenceAction.width, greaterThanOrEqualTo(44));
          expect(visibleEvidenceAction.height, greaterThanOrEqualTo(44));
          expect(
            visibleEvidenceAction.bottom,
            lessThanOrEqualTo(
              entry.viewport.logicalSize.height - entry.viewport.padding.bottom,
            ),
          );
          _expectNoLayoutException(tester);
        },
      );
    }
  });

  group('stratified practical-surface PR matrix', () {
    for (var index = 0; index < _prMatrix.length; index++) {
      final entry = _prMatrix[index];
      testWidgets('${entry.viewport.name} at ${entry.textScale}x: '
          '${_prSurfaceName(index)}', (tester) async {
        applyIosDeviceViewport(
          tester,
          entry.viewport,
          textScale: entry.textScale,
        );
        await _pumpPrSurface(tester, index, entry.viewport);
        expectNoLayoutException(tester);
      });
    }
  });

  testWidgets('iPhone Pro 393 keyboard keeps account auth controls reachable', (
    tester,
  ) async {
    final viewport = IosDeviceViewport.pro393.withKeyboard(height: 346);
    applyIosDeviceViewport(
      tester,
      viewport,
      textScale: IosDynamicType.accessibilityLarge,
    );
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountAuthScreen(intent: AccountAuthIntent.createAccount),
      ),
    );
    await _pumpStable(tester);

    final field = find.byKey(const Key('account_auth_email_field'));
    final cta = find.byKey(const Key('account_auth_primary_cta'));
    expect(field, findsOneWidget);
    await tester.ensureVisible(cta);
    await _pumpStable(tester);
    expectVisibleTapTarget(tester, cta);
    expectInsideSafeHorizontalBounds(tester, cta, viewport);
    expectTapSemantics(tester, cta);
    final mediaQuery = MediaQuery.of(tester.element(find.byType(Scaffold)));
    expect(mediaQuery.viewPadding, viewport.viewPadding);
    expect(mediaQuery.padding, viewport.padding);
    expect(mediaQuery.viewInsets.bottom, 346);
    expectNoLayoutException(tester);
  });
}

String _prSurfaceName(int index) => const [
  'MainShell navigation',
  'onboarding intent',
  'onboarding loop',
  'journal search',
  'account auth',
  'full Life OS graph',
  'pattern playback',
  'subscription fallback',
][index];

Future<void> _pumpPrSurface(
  WidgetTester tester,
  int index,
  IosDeviceViewport viewport,
) async {
  switch (index) {
    case 0:
      await tester.pumpWidget(_mainShellHarness());
      await _pumpStable(tester);
      final navigationBar = find.byType(NavigationBar);
      expect(navigationBar, findsOneWidget);
      final destinations = find.descendant(
        of: navigationBar,
        matching: find.byType(NavigationDestination),
      );
      expect(destinations, findsNWidgets(4));
      for (final destination in destinations.evaluate()) {
        expectVisibleTapTarget(tester, find.byWidget(destination.widget));
      }
      expectSafeBodyBounds(
        tester,
        find.byKey(const Key('shell_body')),
        viewport,
      );
    case 1:
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingIntentScreen()),
      );
      await _pumpStable(tester);
      final skip = find.byKey(const Key('onboarding_intent_skip'));
      final choice = find.byType(OutlinedButton).first;
      expect(skip, findsOneWidget);
      await _scrollUntilVisible(tester, choice);
      expectVisibleTapTarget(tester, choice);
      expectInsideSafeHorizontalBounds(tester, choice, viewport);
    case 2:
      await tester.pumpWidget(const MaterialApp(home: OnboardingLoopScreen()));
      await _pumpStable(tester);
      final cta = find.byKey(const Key('onboarding_loop_start_cta'));
      await tester.ensureVisible(cta);
      await _pumpStable(tester);
      expectVisibleTapTarget(tester, cta);
      expectInsideSafeHorizontalBounds(tester, cta, viewport);
    case 3:
      await tester.pumpWidget(_archiveApp((_) async => _archivePage()));
      await _pumpStable(tester);
      final field = find.byKey(const Key('archive-semantic-search-field'));
      await _scrollUntilVisible(tester, field);
      expectVisibleTapTarget(tester, field);
      expectSafeBodyBounds(tester, find.byType(ListView).first, viewport);
    case 4:
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountAuthScreen(intent: AccountAuthIntent.createAccount),
        ),
      );
      await _pumpStable(tester);
      final field = find.byKey(const Key('account_auth_email_field'));
      await tester.ensureVisible(field);
      await _pumpStable(tester);
      expectVisibleTapTarget(tester, field);
      expectInsideSafeHorizontalBounds(tester, field, viewport);
    case 5:
      await tester.pumpWidget(_lifeOsGraphHarness());
      await _pumpStable(tester);
      expect(find.text('Memory Graph'), findsOneWidget);
      final search = find.byKey(const Key('life_os_graph_search_bar'));
      expectVisibleTapTarget(tester, search);
      expectInsideSafeHorizontalBounds(tester, search, viewport);
    case 6:
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patternRecognitionDashboardProvider.overrideWith(
              _MatrixDashboardController.new,
            ),
          ],
          child: const MaterialApp(home: PatternRecognitionDashboard()),
        ),
      );
      await _pumpStable(tester);
      final memory = find.byKey(const Key('pattern_memory_matrix-entry'));
      await tester.scrollUntilVisible(
        memory,
        240,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
      await tester.tap(memory);
      await _pumpStable(tester);
      final playback = find.byKey(const Key('rich_memory_playback'));
      expect(playback, findsOneWidget);
      expectSheetInsideSafeArea(tester, playback, viewport);
    case 7:
      await tester.pumpWidget(
        const MaterialApp(home: SubscriptionReviewPreviewScreen()),
      );
      await _pumpStable(tester);
      final cta = find.byType(FilledButton).first;
      await _scrollUntilVisible(tester, cta);
      expectVisibleTapTarget(tester, cta);
      expectInsideSafeHorizontalBounds(tester, cta, viewport);
  }
}

Widget _archiveApp(
  Future<ArchiveSemanticSearchPage> Function(String query) searcher,
) => MaterialApp(
  home: ArchiveSemanticSearchScreen(key: UniqueKey(), searcher: searcher),
);

Future<void> _submitArchiveQuery(WidgetTester tester) async {
  final field = find.byKey(const Key('archive-semantic-search-field'));
  await _scrollUntilVisible(tester, field);
  await tester.enterText(field, 'layout');
  final submit = find.byIcon(Icons.arrow_forward);
  await _scrollUntilVisible(tester, submit);
  await tester.tap(submit);
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
}

ArchiveSemanticSearchPage _archivePage({
  List<ArchiveSemanticSearchResult> results = const [],
}) {
  return ArchiveSemanticSearchPage(
    query: const ArchiveSemanticQueryParser().parse('layout'),
    results: results,
    totalResults: results.length,
    hasMore: false,
    insufficientReason: results.isEmpty
        ? 'No grounded mentions matched.'
        : null,
  );
}

ArchiveSemanticSearchResult _archiveResult() => ArchiveSemanticSearchResult(
  entryId: 'entry-layout',
  date: DateTime.utc(2026, 7, 20),
  score: 1,
  reason: 'Exact wording',
  snippet:
      'A deliberately long grounded result that verifies wrapping at large '
      'accessibility text without clipping the primary result action.',
  snippetStartUtf16: 0,
  snippetEndUtf16: 128,
  evidenceStartUtf16: 2,
  evidenceEndUtf16: 20,
);

PersonalKnowledgeGraph _graph() => PersonalKnowledgeGraph(
  nodes: [
    GraphNode(
      id: 'person-layout',
      type: NodeType.person,
      label: 'A person with a deliberately wrapping accessibility label',
      confidence: 0.9,
      evidence: [
        GraphNodeEvidence(
          entryId: 'entry-layout',
          observedAt: DateTime.utc(2026, 7, 20),
          confidence: 0.9,
          excerpt: 'Grounded graph evidence',
          startUtf16: 0,
          endUtf16: 23,
        ),
      ],
    ),
  ],
);

Widget _mainShellHarness() {
  final router = GoRouter(
    initialLocation: '/record',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          for (final path in [
            '/record',
            '/archive-belief',
            '/belief-changes',
            '/account',
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) => SafeArea(
                    child: SizedBox.expand(
                      key: const Key('shell_body'),
                      child: Center(child: Text(path)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Widget _lifeOsGraphHarness() {
  final router = GoRouter(
    initialLocation: LifeOsGraphScreen.route,
    routes: [
      GoRoute(
        path: LifeOsGraphScreen.route,
        builder: (context, state) => const LifeOsGraphScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [knowledgeGraphProvider.overrideWith((ref) async => _graph())],
    child: MaterialApp.router(routerConfig: router),
  );
}

final _matrixEntry = JournalEntry(
  id: 'matrix-entry',
  createdAt: DateTime.utc(2026, 7, 20),
  transcript:
      'A grounded memory with enough text to exercise wrapping in playback.',
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['boundaries'],
    exactLanguagePattern: '',
    concreteObservation: 'You protected quiet time.',
    repeatedSignal: '',
  ),
);

class _MatrixDashboardController extends PatternRecognitionDashboardController {
  @override
  Future<PatternRecognitionDashboardState> build() async =>
      PatternRecognitionDashboardState(
        entries: [_matrixEntry],
        insights: ArchiveInsightsSnapshot.empty,
        recurringTopics: const [RecurringTopic(label: 'boundaries', count: 3)],
        moodTrends: const [
          MoodTrend(mood: 'calm', count: 2, averageIntensity: 2),
        ],
        loadedFromLocalFallback: false,
        isPro: true,
      );
}

Future<void> _openVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.05);
  await _pumpStable(tester);
  await tester.tap(finder);
  await _pumpStable(tester);
}

Future<void> _openWithin(
  WidgetTester tester,
  Finder finder,
  Finder scrollable,
) async {
  final visibleRect = await _makeVisibleWithin(tester, finder, scrollable);
  await tester.tapAt(visibleRect.center);
  await _pumpStable(tester);
}

Future<Rect> _makeVisibleWithin(
  WidgetTester tester,
  Finder finder,
  Finder scrollable,
) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.2);
  await _pumpStable(tester);
  final root =
      Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  final visibleRect = tester
      .getRect(finder)
      .intersect(tester.getRect(scrollable))
      .intersect(root);
  if (visibleRect.width >= 44 && visibleRect.height >= 44) {
    return visibleRect;
  }
  fail('Could not make $finder reachable in $scrollable');
}

Finder _verticalScrollableWithin(Finder owner) => find
    .descendant(
      of: owner,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            (widget.axisDirection == AxisDirection.down ||
                widget.axisDirection == AxisDirection.up),
      ),
    )
    .first;

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    await Scrollable.ensureVisible(
      tester.element(finder.first),
      alignment: 0.35,
    );
    await _pumpStable(tester);
    return;
  }
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 50,
  );
  await _pumpStable(tester);
}

Future<void> _dismissSheet(WidgetTester tester, Finder sheet) async {
  Navigator.of(tester.element(sheet)).pop();
  await _pumpStable(tester);
}

Future<void> _pumpStable(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void _expectTapTarget(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(44), reason: '$finder width');
  expect(size.height, greaterThanOrEqualTo(44), reason: '$finder height');
}

void _expectTapSemantics(WidgetTester tester, Finder finder) {
  final handle = tester.ensureSemantics();
  try {
    expect(
      tester
          .getSemantics(finder)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
  } finally {
    handle.dispose();
  }
}

void _expectInsideSafeHorizontalBounds(
  WidgetTester tester,
  Finder finder,
  IosDeviceViewport viewport,
) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(viewport.padding.left));
  expect(
    rect.right,
    lessThanOrEqualTo(viewport.logicalSize.width - viewport.padding.right),
  );
}

void _expectSafeBody(WidgetTester tester, IosDeviceViewport viewport) {
  final list = find.byType(ListView).first;
  final rect = tester.getRect(list);
  expect(rect.left, greaterThanOrEqualTo(viewport.padding.left));
  expect(
    rect.right,
    lessThanOrEqualTo(viewport.logicalSize.width - viewport.padding.right),
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(viewport.logicalSize.height - viewport.padding.bottom),
  );
}

void _expectSheetInsideSafeArea(
  WidgetTester tester,
  Finder finder,
  IosDeviceViewport viewport,
) {
  expectSheetInsideSafeArea(tester, finder, viewport);
}

void _expectNoLayoutException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(
    exception,
    isNull,
    reason: 'Render/layout exception at the current iOS matrix state',
  );
}
