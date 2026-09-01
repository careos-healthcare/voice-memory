import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_dashboard_scroll_view.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_entry_hero_tags.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/features/archive_changes/archive_changes_adapter.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _absentChanges = ArchiveChangesSnapshot(
  entries: [],
  timeline: [],
  eligible: false,
);

JournalEntry _entry({required String id}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 6, 12, 10),
    transcript: 'A saved moment transcript for responsive layout testing.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: ['focus'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  group('ArchiveResponsiveLayout', () {
    test('uses three columns on very wide dashboards', () {
      // Raw viewport widths. Archive Home then subtracts page padding and
      // the 720px center inset, so the sliver extent is often still one
      // column — this helper does not measure that padded width.
      expect(ArchiveResponsiveLayout.entryGridColumnsForWidth(1200), 3);
      expect(ArchiveResponsiveLayout.entryGridColumnsForWidth(800), 2);
      expect(ArchiveResponsiveLayout.entryGridColumnsForWidth(500), 1);
    });

    test('keeps the tablet grid at normal text scale', () {
      expect(
        ArchiveResponsiveLayout.prefersEntryList(
          crossAxisCount: 2,
          textScaler: TextScaler.noScaling,
        ),
        isFalse,
      );
      expect(
        ArchiveResponsiveLayout.prefersEntryList(
          crossAxisCount: 3,
          textScaler: const TextScaler.linear(1.2),
        ),
        isFalse,
      );
    });

    test('falls back to the list above the large-text threshold', () {
      expect(
        ArchiveResponsiveLayout.prefersEntryList(
          crossAxisCount: 2,
          textScaler: const TextScaler.linear(
            ArchiveResponsiveLayout.largeTextListFallbackThreshold,
          ),
        ),
        isTrue,
      );
      expect(
        ArchiveResponsiveLayout.prefersEntryList(
          crossAxisCount: 1,
          textScaler: TextScaler.noScaling,
        ),
        isTrue,
      );
    });

    test('centers content inset on wide viewports', () {
      expect(
        ArchiveResponsiveLayout.horizontalCenterInset(viewportWidth: 1000),
        140,
      );
      expect(
        ArchiveResponsiveLayout.horizontalCenterInset(viewportWidth: 600),
        0,
      );
    });
  });

  group('ArchiveEntryCard', () {
    testWidgets('registers hero tags for card-to-detail transitions', (
      tester,
    ) async {
      final entry = _entry(id: 'hero-entry');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveEntryCard(entry: entry, onTap: () {}),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Hero &&
              widget.tag == ArchiveEntryHeroTags.surface('hero-entry'),
        ),
        findsOneWidget,
      );
    });
  });

  group('ArchiveDashboardScrollView large text', () {
    testWidgets('does not overflow at tablet width and 200% text scale', (
      tester,
    ) async {
      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        flutterErrors.add(details);
        previousOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      const tablet = Size(800, 1024);
      await tester.binding.setSurfaceSize(tablet);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final entries = [
        _entry(id: 'wide-1'),
        _entry(id: 'wide-2'),
        _entry(id: 'wide-3'),
        _entry(id: 'wide-4'),
      ];
      final controller = ScrollController();
      addTearDown(controller.dispose);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: ArchiveDashboardScrollView(
                controller: controller,
                feed: ArchiveFeedState(
                  loadState: ArchiveBeliefLoadState.loaded,
                  entries: entries,
                  archiveTotalCount: entries.length,
                  totalCount: entries.length,
                ),
                loadState: ArchiveBeliefLoadState.loaded,
                visibleEntries: entries,
                showChangesUnavailable: false,
                previewChangesSnapshot: _absentChanges,
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
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Raw width says 2 columns; padded sliver extent stays under 720, so
      // production already uses the list. The 200% fallback must not overflow
      // that real path. find.byType(SliverGrid) would not catch a future
      // padding change — prefersEntryList covers that.
      expect(ArchiveResponsiveLayout.entryGridColumnsForWidth(800), 2);
      expect(find.byType(SliverGrid), findsNothing);
      expect(find.byType(SliverList), findsWidgets);
      expect(find.byType(ArchiveEntryCard), findsAtLeastNWidgets(1));
      expect(
        flutterErrors,
        isEmpty,
        reason:
            'Archive Home overflowed at tablet + 200%: '
            '${flutterErrors.map((d) => d.exceptionAsString()).join('; ')}',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'does not flip the current tablet feed into a different sliver at 100%',
      (tester) async {
        const tablet = Size(800, 1024);
        await tester.binding.setSurfaceSize(tablet);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final entries = [_entry(id: 'n1'), _entry(id: 'n2'), _entry(id: 'n3')];
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ArchiveDashboardScrollView(
                controller: controller,
                feed: ArchiveFeedState(
                  loadState: ArchiveBeliefLoadState.loaded,
                  entries: entries,
                  archiveTotalCount: entries.length,
                  totalCount: entries.length,
                ),
                loadState: ArchiveBeliefLoadState.loaded,
                visibleEntries: entries,
                showChangesUnavailable: false,
                previewChangesSnapshot: _absentChanges,
                onRefresh: () async {},
                onEntryTap: (_) {},
                onQueryChanged: (_) {},
                onCapture: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Today's padding keeps the sliver under 720px, so 100% tablet is
        // already a list — same as phone. The threshold must not invent a grid.
        expect(find.byType(SliverGrid), findsNothing);
        expect(find.byType(SliverList), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
