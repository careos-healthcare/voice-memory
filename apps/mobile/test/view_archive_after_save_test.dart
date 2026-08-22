// Covers the "View archive" hop from Record's first-save card into the
// Archive tab, plus the legacy-route redirect that keeps old deep links
// working. The four-state Patterns-style assertions this file used to carry
// against ArchiveBeliefScreen were testing behavior that has since moved to
// the Changes tab (test/archive_tab_four_state_test.dart,
// test/belief_changes_navigation_test.dart) — removed rather than kept as
// stale duplicate coverage. PatternsFirstArchiveView (an unreachable, unused
// widget) was deleted as part of the Objective 1 launch-surface cleanup, so
// its dedicated tests are gone too.
import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/router/developer_route_guard.dart';
import 'package:archiveme_mobile/screens/archive_belief_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:archiveme_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

JournalEntry _entry({String id = 'e1'}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
    transcript: 'A long enough transcript to count as a saved reflection.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
  );
}

Future<void> _resetServices() async {
  final dir = Directory.systemTemp.createTempSync('vm_view_archive_');
  await AppServices.resetForTest(
    journalPath: '${dir.path}/journal.json',
    prefsPath: '${dir.path}/prefs.json',
    skipRevenueCat: true,
  );
}

void main() {
  setUp(() async {
    await _resetServices();
  });

  group('View archive routing', () {
    test('legacy journal path redirects to the Archive tab in production', () {
      expect(
        DeveloperRouteGuard.redirectFor('/journal'),
        DeveloperRouteGuard.patternsHome,
      );
      expect(DeveloperRouteGuard.patternsHome, '/archive-belief');
    });

    testWidgets(
      'first-save View archive navigates to the Archive tab not Record',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/record',
          routes: [
            GoRoute(
              path: '/record',
              builder: (context, state) => Scaffold(
                body: FirstSaveEvidenceCard(
                  onViewArchive: () => context.go('/archive-belief'),
                  onRecordAnother: () {},
                  onDoneForToday: () {},
                ),
              ),
            ),
            GoRoute(
              path: '/archive-belief',
              builder: (context, state) =>
                  const Scaffold(body: Text('ARCHIVE_TAB_MARKER')),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('first_save_view_archive_cta')));
        await tester.pumpAndSettle();

        expect(find.text('ARCHIVE_TAB_MARKER'), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/archive-belief',
        );
      },
    );

    testWidgets('archive screen shows the saved entry as an original moment', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry());
      });

      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveBeliefScreen(key: UniqueKey()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Original moments'), findsOneWidget);
      expect(find.textContaining('A long enough transcript'), findsOneWidget);
      expect(
        find.byKey(const Key('archive_tab_entry_state_empty')),
        findsNothing,
      );
    });
  });

  group('PatternsEmptyView — shared Changes-tab empty state', () {
    testWidgets('shows four-state empty copy and record CTA only', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView()),
        ),
      );
      await tester.pump();

      expect(find.text('Record a moment'), findsOneWidget);
      expect(
        find.byKey(const Key('archive_tab_record_moment_cta')),
        findsOneWidget,
      );
    });
  });
}