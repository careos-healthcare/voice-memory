import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_dashboard_scroll_view.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/features/archive_changes/archive_changes_adapter.dart';
import 'package:archiveme_mobile/features/feature_unlock/feature_unlock_service.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/widgets/archive/feature_unlock_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows how many entries remain before each tool', (tester) async {
    await tester.pumpWidget(
      _tools(
        const FeatureUnlockState(entryCount: 2, loaded: true),
      ),
    );

    expect(
      find.text('3 more entries to unlock Blind Spot Analysis'),
      findsOneWidget,
    );
    expect(
      find.text('8 more entries to unlock Key Themes'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('feature_unlock_blind_spots')), findsNothing);
    expect(
      find.byKey(const Key('feature_unlock_theory_engines')),
      findsNothing,
    );
  });

  testWidgets('renders the opened tools and hides the progress lines', (
    tester,
  ) async {
    var openedTheories = false;
    await tester.pumpWidget(
      _tools(
        const FeatureUnlockState(entryCount: 10, loaded: true),
        onOpenTheoryEngines: () => openedTheories = true,
      ),
    );

    expect(find.byKey(const Key('feature_unlock_blind_spots')), findsOneWidget);
    expect(
      find.byKey(const Key('feature_unlock_theory_engines')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('feature_unlock_blind_spots_progress')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('feature_unlock_theory_engines')));
    expect(openedTheories, isTrue);
  });

  testWidgets('plays a celebration when a threshold is crossed', (
    tester,
  ) async {
    FeatureUnlockMilestone? celebrated;
    await tester.pumpWidget(
      _tools(
        const FeatureUnlockState(
          entryCount: 5,
          loaded: true,
          pendingCelebrations: [FeatureUnlockMilestone.blindSpots],
        ),
        onCelebrated: (milestone) => celebrated = milestone,
      ),
    );

    expect(find.text('Blind Spot Analysis is open.'), findsOneWidget);
    expect(find.byKey(const Key('feature_unlock_blind_spots')), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(celebrated, FeatureUnlockMilestone.blindSpots);
  });

  testWidgets('archive home shows the progress line from the unlock state', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: ArchiveDashboardScrollView(
              controller: ScrollController(),
              feed: const ArchiveFeedState(
                loadState: ArchiveBeliefLoadState.loaded,
                entries: [],
                archiveTotalCount: 0,
                totalCount: 0,
              ),
              loadState: ArchiveBeliefLoadState.loaded,
              visibleEntries: const [],
              showChangesUnavailable: false,
              previewChangesSnapshot: const ArchiveChangesSnapshot(
                entries: [],
                timeline: [],
                eligible: false,
              ),
              onRefresh: () async {},
              onEntryTap: (_) {},
              onQueryChanged: (_) {},
              onCapture: () {},
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureUnlockProvider.overrideWith(
            () => _PresetUnlock(
              const FeatureUnlockState(entryCount: 2, loaded: true),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(
      find.text('3 more entries to unlock Blind Spot Analysis'),
      findsOneWidget,
    );
  });

  testWidgets('the first pattern highlight offers premium extras', (
    tester,
  ) async {
    PremiumAccess.apply(PremiumEntitlement.free);
    addTearDown(() => PremiumAccess.apply(PremiumEntitlement.free));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monetizationRevenueCatServiceProvider.overrideWithValue(
            MonetizationRevenueCatService(seed: PremiumEntitlement.free),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPatternSynthesisPaywall(context),
              child: const Text('highlight'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('highlight'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Encrypted cloud backups'), findsOneWidget);
    expect(find.text('Automated Obsidian sync'), findsOneWidget);
    expect(find.text('Pattern synthesis'), findsOneWidget);
    expect(find.text('Start Premium'), findsOneWidget);
  });
}

class _PresetUnlock extends FeatureUnlockNotifier {
  _PresetUnlock(this.value);

  final FeatureUnlockState value;

  @override
  FeatureUnlockState build() => value;
}

Widget _tools(
  FeatureUnlockState state, {
  ValueChanged<FeatureUnlockMilestone>? onCelebrated,
  VoidCallback? onOpenTheoryEngines,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FeatureUnlockTools(
        state: state,
        onCelebrated: onCelebrated ?? (_) {},
        onOpenTheoryEngines: onOpenTheoryEngines,
      ),
    ),
  );
}
