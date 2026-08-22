import 'dart:io';

import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:archiveme_mobile/router/primary_navigation_controller.dart';
import 'package:archiveme_mobile/router/record_navigation_activity_controller.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A root route outside the three-branch shell, used to prove that secondary
/// destinations render without the primary navigation and keep their query.
const _secondaryRoute = '/secondary-detail';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('primary destination model', () {
    test('has exactly three ordered shell routes and excludes graph', () {
      expect(PrimaryDestination.shellValues, [
        PrimaryDestination.record,
        PrimaryDestination.archive,
        PrimaryDestination.account,
      ]);
      expect(
        PrimaryDestination.shellValues.map((destination) => destination.route),
        RouteCatalog.primaryRoutes,
      );
      expect(RouteCatalog.primaryRoutes, isNot(contains(_secondaryRoute)));
    });
  });

  group('three-branch shell behavior', () {
    testWidgets('defaults to Record and exposes three destinations in order', (
      tester,
    ) async {
      final harness = _ShellHarness();
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(_navigationLabels(tester), ['Record', 'Archive', 'Account']);
      expect(find.text('Changes'), findsNothing);
      expect(find.text('Intelligence'), findsNothing);
      expect(find.text('Memory Graph'), findsNothing);
      expect(find.text('Record branch'), findsOneWidget);
      expect(_selectedPhoneIndex(tester), PrimaryDestination.record.shellIndex);
      expect(find.bySemanticsLabel('Primary navigation'), findsOneWidget);
    });

    testWidgets('each destination renders a real branch without a modal', (
      tester,
    ) async {
      final harness = _ShellHarness();
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);
      final baselineBarriers = find.byType(ModalBarrier).evaluate().length;

      for (final destination in PrimaryDestination.shellValues.skip(1)) {
        await _tapDestination(tester, destination.label);
        expect(find.text('${destination.label} branch'), findsOneWidget);
        expect(_selectedPhoneIndex(tester), destination.shellIndex);
        expect(
          find.byType(ModalBarrier).evaluate(),
          hasLength(baselineBarriers),
        );
        expect(find.byType(BottomSheet), findsNothing);
      }
    });

    testWidgets(
      'inactive branch state is retained and roots are not duplicated',
      (tester) async {
        final harness = _ShellHarness();
        addTearDown(harness.dispose);
        await _pumpHarness(tester, harness);

        await _tapDestination(tester, 'Archive');
        await tester.enterText(find.byKey(const Key('archive_state')), 'kept');
        await _tapDestination(tester, 'Account');
        await _tapDestination(tester, 'Archive');

        expect(find.text('kept'), findsOneWidget);
        expect(find.byKey(const Key('archive_root')), findsOneWidget);
        expect(harness.archiveBuilds, 1);
      },
    );

    testWidgets('reselecting a branch returns it to its initial location', (
      tester,
    ) async {
      final harness = _ShellHarness();
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      await _tapDestination(tester, 'Archive');
      await tester.tap(find.byKey(const Key('archive_detail_button')));
      await tester.pumpAndSettle();
      expect(find.text('Archive detail'), findsOneWidget);

      await _tapDestination(tester, 'Archive');
      expect(find.byKey(const Key('archive_root')), findsOneWidget);
      expect(find.text('Archive detail'), findsNothing);
    });

    testWidgets('recording and processing block cross-tab selection', (
      tester,
    ) async {
      final harness = _ShellHarness();
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      for (final activity in [
        RecordNavigationActivity.recording,
        RecordNavigationActivity.processing,
      ]) {
        harness.recordActivity.update(activity);
        await tester.pump();
        await _tapDestination(tester, 'Archive');
        expect(find.text('Record branch'), findsOneWidget);
        expect(
          find.text('Finish or cancel the recording first.'),
          findsOneWidget,
        );
        harness.recordActivity.release();
        await tester.pump();
      }

      await _tapDestination(tester, 'Archive');
      expect(find.text('Archive branch'), findsOneWidget);
    });

    testWidgets('root back returns secondary branches to Record', (
      tester,
    ) async {
      for (final destination in [
        PrimaryDestination.archive,
        PrimaryDestination.account,
      ]) {
        final harness = _ShellHarness(initialLocation: destination.route);
        await _pumpHarness(tester, harness);
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(find.text('Record branch'), findsOneWidget);
        harness.dispose();
      }
    });

    testWidgets('a real detail pops before switching to Record', (
      tester,
    ) async {
      final harness = _ShellHarness(
        initialLocation: '${RouteCatalog.archiveHome}/detail',
      );
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      expect(find.text('Archive detail'), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('archive_root')), findsOneWidget);
      expect(_selectedPhoneIndex(tester), PrimaryDestination.archive.shellIndex);
    });

    testWidgets('Settings pops back to Account', (tester) async {
      final harness = _ShellHarness(initialLocation: RouteCatalog.accountHome);
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      await tester.tap(find.byKey(const Key('open_settings')));
      await tester.pumpAndSettle();
      expect(find.text('Settings page'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Account branch'), findsOneWidget);
    });

    testWidgets('a root secondary route keeps its query values', (
      tester,
    ) async {
      final harness = _ShellHarness(
        initialLocation: '$_secondaryRoute?view=evidence&nodeId=test',
      );
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      expect(find.text('Graph evidence test'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('responsive and accessible navigation', () {
    testWidgets('phone supports text scale 2 with usable destinations', (
      tester,
    ) async {
      final harness = _ShellHarness(
        textScale: 2,
        surfaceSize: const Size(320, 568),
      );
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      for (final destination in PrimaryDestination.shellValues) {
        final finder = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(destination.label),
        );
        expect(finder, findsOneWidget);
        final size = tester.getSize(
          find.ancestor(
            of: finder,
            matching: find.byType(NavigationDestination),
          ),
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet uses a NavigationRail with three destinations', (
      tester,
    ) async {
      final harness = _ShellHarness(surfaceSize: const Size(834, 1194));
      addTearDown(harness.dispose);
      await _pumpHarness(tester, harness);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(_navigationLabels(tester), ['Record', 'Archive', 'Account']);
      expect(tester.takeException(), isNull);
    });
  });

  group('record activity controller', () {
    test('release and disposal never leave navigation locked', () {
      final controller = RecordNavigationActivityController();
      controller.update(RecordNavigationActivity.requestingPermission);
      expect(controller.isNavigationLocked, isTrue);
      controller.release();
      expect(controller.isNavigationLocked, isFalse);
      controller.update(RecordNavigationActivity.recording);
      controller.dispose();
      expect(controller.activity, RecordNavigationActivity.idle);
      expect(controller.isNavigationLocked, isFalse);
    });
  });

  group('architecture guards', () {
    test(
      'shell contains no graph-backed modal or radial capture architecture',
      () {
        final source = File('lib/widgets/main_shell.dart').readAsStringSync();
        for (final forbidden in [
          'showCanvasFeaturePanel',
          'Timer(',
          'RadialActionMenu',
          'ArchiveBeliefScreen',
          'AccountScreen',
          'memory_graph_capture_fab',
        ]) {
          expect(source, isNot(contains(forbidden)), reason: forbidden);
        }
      },
    );

    test('router owns exactly three typed primary branches', () {
      final source = File('lib/router/app_router.dart').readAsStringSync();
      expect(
        RegExp(r'StatefulShellRoute\.indexedStack').allMatches(source),
        hasLength(1),
      );
      final shellSection = source.split('StatefulShellRoute.indexedStack').skip(1).first;
      expect(
        RegExp(r'StatefulShellBranch\s*\(').allMatches(shellSection).length,
        3,
      );
      for (final route in ['recordHome', 'archiveHome', 'accountHome']) {
        expect(
          RegExp('path: RouteCatalog\\.$route').allMatches(shellSection),
          hasLength(1),
          reason: route,
        );
      }
      expect(source, contains('initialLocation: RouteCatalog.recordHome'));
    });

    test('production does not directly push a primary destination', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final forbidden = RegExp(
        r'''context\.push(?:<[^>]+>)?\(\s*(?:RouteCatalog\.(?:recordHome|archiveHome|changesHome|accountHome)|['"]/(?:record|archive-belief|then-vs-now|belief-changes|account)['"])''',
      );
      for (final file in files) {
        expect(
          forbidden.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    });
  });
}

class _ShellHarness {
  _ShellHarness({
    this.initialLocation = RouteCatalog.recordHome,
    this.textScale = 1,
    this.surfaceSize = const Size(390, 844),
  }) {
    router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => MainShell(
            navigationShell: shell,
            primaryNavigationController: navigation,
            recordNavigationActivityController: recordActivity,
          ),
          branches: [
            StatefulShellBranch(
              navigatorKey: recordBranchNavigatorKey,
              routes: [
                GoRoute(
                  path: RouteCatalog.recordHome,
                  builder: (_, _) => const _BranchPage(label: 'Record'),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: archiveBranchNavigatorKey,
              routes: [
                GoRoute(
                  path: RouteCatalog.archiveHome,
                  builder: (_, _) {
                    archiveBuilds += 1;
                    return const _ArchiveBranchPage();
                  },
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (_, _) => const Scaffold(
                        body: Center(child: Text('Archive detail')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: accountBranchNavigatorKey,
              routes: [
                GoRoute(
                  path: RouteCatalog.accountHome,
                  builder: (_, _) => const _AccountBranchPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          parentNavigatorKey: rootKey,
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('Settings page'))),
        ),
        GoRoute(
          path: _secondaryRoute,
          parentNavigatorKey: rootKey,
          builder: (_, state) => Scaffold(
            body: Center(
              child: Text(
                'Graph ${state.uri.queryParameters['view']} '
                '${state.uri.queryParameters['nodeId']}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  final String initialLocation;
  final double textScale;
  final Size surfaceSize;
  final rootKey = GlobalKey<NavigatorState>();
  final navigation = PrimaryNavigationController();
  final recordActivity = RecordNavigationActivityController();
  late final GoRouter router;
  int archiveBuilds = 0;

  void dispose() {
    router.dispose();
    navigation.dispose();
    recordActivity.dispose();
  }
}

class _BranchPage extends StatelessWidget {
  const _BranchPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('$label branch')));
}

class _ArchiveBranchPage extends StatelessWidget {
  const _ArchiveBranchPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('archive_root'),
    body: Column(
      children: [
        const Text('Archive branch'),
        const TextField(key: Key('archive_state')),
        FilledButton(
          key: const Key('archive_detail_button'),
          onPressed: () => context.push('${RouteCatalog.archiveHome}/detail'),
          child: const Text('Open detail'),
        ),
      ],
    ),
  );
}

class _AccountBranchPage extends StatelessWidget {
  const _AccountBranchPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('Account branch'),
        FilledButton(
          key: const Key('open_settings'),
          onPressed: () => context.push('/settings'),
          child: const Text('Settings'),
        ),
      ],
    ),
  );
}

Future<void> _pumpHarness(WidgetTester tester, _ShellHarness harness) async {
  await tester.binding.setSurfaceSize(harness.surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: harness.router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(harness.textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _navigationLabels(WidgetTester tester) => [
  for (final destination in PrimaryDestination.shellValues)
    if (find.text(destination.label).evaluate().isNotEmpty) destination.label,
];

int _selectedPhoneIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Future<void> _tapDestination(WidgetTester tester, String label) async {
  final navigation = find.byType(NavigationBar).evaluate().isNotEmpty
      ? find.byType(NavigationBar)
      : find.byType(NavigationRail);
  await tester.tap(
    find.descendant(of: navigation, matching: find.text(label)).last,
  );
  await tester.pumpAndSettle();
}
