import 'dart:io';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/archive_beliefs/belief_change_timeline.dart';
import 'package:archiveme_mobile/features/archive_changes/archive_changes_adapter.dart';
import 'package:archiveme_mobile/features/archive_changes/archive_changes_eligibility.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/router/archive_changes_deep_link.dart';
import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/features/belief_changes/screens/belief_changes_screen.dart';
import 'package:archiveme_mobile/widgets/archive/archive_beliefs_dashboard.dart';
import 'package:archiveme_mobile/widgets/archive/archive_changes_section.dart';
import 'package:archiveme_mobile/widgets/archive/archive_changes_unavailable_notice.dart';
import 'package:archiveme_mobile/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('three primary destinations', () {
    test('shell exposes Record, Archive, Account only', () {
      expect(PrimaryDestination.shellValues, [
        PrimaryDestination.record,
        PrimaryDestination.archive,
        PrimaryDestination.account,
      ]);
      expect(
        PrimaryDestination.shellValues.map((d) => d.label),
        ['Record', 'Archive', 'Account'],
      );
      expect(RouteCatalog.primaryRoutes, hasLength(3));
      expect(RouteCatalog.primaryRoutes, isNot(contains(RouteCatalog.changesHome)));
    });

    testWidgets('fresh user sees exactly three primary destinations', (
      tester,
    ) async {
      final harness = _ThreeTabHarness();
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(_navigationLabels(tester), ['Record', 'Archive', 'Account']);
      expect(find.text('Changes'), findsNothing);
      expect(find.text('Then vs Now'), findsNothing);
    });

    testWidgets('semantics announce tab position and selected state', (
      tester,
    ) async {
      final harness = _ThreeTabHarness();
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      final nodes = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((node) => (node.properties.label ?? '').contains('tab'))
          .map((node) => node.properties.label!)
          .toList();
      expect(nodes.where((label) => label.contains('Record')), isNotEmpty);
      expect(nodes.where((label) => label.contains('tab 1 of 3')), isNotEmpty);
      expect(nodes.where((label) => label.contains('selected')), isNotEmpty);

      await _tapDestination(tester, 'Archive');
      final archiveLabels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((node) => node.properties.label ?? '')
          .where((label) => label.contains('Archive'))
          .join(' ');
      expect(archiveLabels, contains('tab 2 of 3'));
      expect(archiveLabels, contains('selected'));
    });
  });

  group('Archive Changes subsection', () {
    test('eligibility requires evidence contract and non-empty timeline', () {
      const reflection = Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: 'pattern',
        concreteObservation: 'Work pressure showed up again.',
        repeatedSignal: 'signal',
      );
      final shortEntry = JournalEntry(
        id: 'e1',
        createdAt: DateTime.utc(2026, 1, 1),
        transcript: 'hi',
        durationSeconds: 0,
        reflection: reflection,
      );
      expect(
        ArchiveChangesEligibility.isEligible(entries: [shortEntry], timeline: const []),
        isFalse,
      );

      final eligibleEntries = List<JournalEntry>.generate(
        AppConfig.patternReviewReflectionTarget,
        (i) => JournalEntry(
          id: 'e$i',
          createdAt: DateTime.utc(2026, 1, i + 1),
          transcript: 'This is a long enough reflection about work pressure $i.',
          durationSeconds: 30,
          reflection: reflection,
        ),
      );
      const timeline = [
        BeliefChangeTimelineItem(
          kind: BeliefChangeKind.weakening,
          statement: 'Work pressure may be easing.',
          detail: 'Based on recent reflections.',
          sortOrder: 0,
        ),
      ];
      expect(
        ArchiveChangesEligibility.isEligible(
          entries: eligibleEntries,
          timeline: timeline,
        ),
        isTrue,
      );
    });

    testWidgets('Archive hides Changes section without sufficient evidence', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArchiveChangesSection(
            previewSnapshot: ArchiveChangesSnapshot(
              entries: const [],
              timeline: const [],
              eligible: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('archive_changes_section_absent')), findsOneWidget);
      expect(find.byKey(const Key('archive_changes_heading')), findsNothing);
    });

    testWidgets('eligible archive shows Changes inside Archive', (tester) async {
      const timeline = [
        BeliefChangeTimelineItem(
          kind: BeliefChangeKind.weakening,
          statement: 'Work pressure may be easing.',
          detail: 'Based on recent reflections.',
          sortOrder: 0,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: ArchiveChangesSection(
            previewSnapshot: ArchiveChangesSnapshot(
              entries: const [],
              timeline: timeline,
              eligible: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('archive_changes_section')), findsOneWidget);
      expect(find.text(BeliefProductCopy.changesTabLabel), findsOneWidget);
      expect(find.byType(BeliefChangeStories), findsOneWidget);
    });
  });

  group('legacy Changes deep links', () {
    test('legacy path redirects to nested archive route', () {
      expect(ArchiveChangesDeepLink.nestedChangesPath, '/archive-belief/changes');
      expect(ArchiveChangesDeepLink.legacyPath, '/belief-changes');
    });

    testWidgets('ineligible legacy deep link opens Archive with explanation', (
      tester,
    ) async {
      late GoRouter router;
      router = GoRouter(
        initialLocation: RouteCatalog.changesHome,
        routes: [
          GoRoute(
            path: RouteCatalog.changesHome,
            redirect: (_, _) => ArchiveChangesDeepLink.nestedChangesPath,
          ),
          GoRoute(
            path: RouteCatalog.archiveHome,
            builder: (_, state) => Scaffold(
              body: Column(
                children: [
                  if (ArchiveChangesDeepLink.showsUnavailableNotice(state.uri))
                    const ArchiveChangesUnavailableNotice(),
                  const Text('archive-root'),
                ],
              ),
            ),
            routes: [
              GoRoute(
                path: 'changes',
                builder: (_, _) => const BeliefChangesScreen(previewTimeline: []),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, RouteCatalog.archiveHome);
      expect(
        router.state.uri.queryParameters[ArchiveChangesDeepLink.unavailableQueryKey],
        '1',
      );
      expect(find.byKey(ArchiveChangesUnavailableNotice.noticeKey), findsOneWidget);
      expect(find.text('archive-root'), findsOneWidget);
    });

    testWidgets('eligible legacy deep link shows Changes content', (tester) async {
      const timeline = [
        BeliefChangeTimelineItem(
          kind: BeliefChangeKind.weakening,
          statement: 'A cautious shift appeared.',
          detail: 'Detail',
          sortOrder: 0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: BeliefChangesScreen(previewTimeline: timeline),
        ),
      );
      await tester.pump();

      expect(find.text('What is changing'), findsOneWidget);
      expect(find.byType(BeliefChangeStories), findsOneWidget);
    });
  });

  group('release shell graph', () {
    test('router owns exactly three typed primary branches', () {
      final source = File('lib/router/app_router.dart').readAsStringSync();
      final shellSection = source.split('StatefulShellRoute.indexedStack').skip(1).first;
      expect(
        RegExp(r'StatefulShellBranch\s*\(').allMatches(shellSection).length,
        3,
      );
      expect(shellSection, isNot(contains('changesBranchNavigatorKey')));
      for (final route in ['recordHome', 'archiveHome', 'accountHome']) {
        expect(
          RegExp('path: RouteCatalog\\.$route').allMatches(shellSection),
          hasLength(1),
          reason: route,
        );
      }
    });

    testWidgets('production harness does not construct a Changes primary branch', (
      tester,
    ) async {
      final source = File('lib/router/app_router.dart').readAsStringSync();
      final shellSection = source.split('StatefulShellRoute.indexedStack').skip(1).first;
      expect(shellSection, isNot(contains('changesBranchNavigatorKey')));
      expect(
        RegExp(r'StatefulShellBranch\s*\(').allMatches(shellSection).length,
        3,
      );
    });
  });
}

class _ThreeTabHarness {
  _ThreeTabHarness({this.initialLocation = RouteCatalog.recordHome}) {
    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteCatalog.recordHome,
                  builder: (_, _) => const Scaffold(body: Text('Record branch')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteCatalog.archiveHome,
                  builder: (_, _) => const Scaffold(body: Text('Archive branch')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteCatalog.accountHome,
                  builder: (_, _) => const Scaffold(body: Text('Account branch')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  final String initialLocation;
  late final GoRouter router;

  void dispose() => router.dispose();
}

Future<void> _pumpHarness(WidgetTester tester, _ThreeTabHarness harness) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp.router(routerConfig: harness.router));
  await tester.pumpAndSettle();
}

List<String> _navigationLabels(WidgetTester tester) => [
  for (final destination in PrimaryDestination.shellValues)
    if (find.text(destination.label).evaluate().isNotEmpty) destination.label,
];

Future<void> _tapDestination(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
