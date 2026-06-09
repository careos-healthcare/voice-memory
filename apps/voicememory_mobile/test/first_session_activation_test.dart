import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/screens/pressure_check_in_screen.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/first_session/first_session_explanation_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_first_week_nudge.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_first_win_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_insights_empty_state.dart';

import 'support/memory_pressure_stores.dart';

PressureCheckInRecord _record({String id = 'a'}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 8, 12),
    optionId: 'did_more_to_not_feel_behind',
    contextIds: const ['work'],
    fear: null,
    choseToStop: false,
    transcript: 'I did more so I wouldn\'t feel behind.',
  );
}

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
  await tester.pump();
}

Future<void> _pumpInsights(
  WidgetTester tester, {
  required List<PressureCheckInRecord> records,
  bool pro = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PressureInsightsScreen(
        entitlementReader: FakeArchiveEntitlementReader(pro: pro),
        // In-memory stores: AppServices may be initialized by earlier tests
        // in this file, and live stores would do file IO in the widget zone.
        microExperimentStore: MemoryExperimentStore(),
        returnTriggerStore: MemoryReturnTriggerStore(),
        records: records,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('First-session explanation card', () {
    test('shows only for a brand-new user', () {
      expect(FirstSessionExplanationCard.shouldShow(0), isTrue);
      expect(FirstSessionExplanationCard.shouldShow(1), isFalse);
      expect(FirstSessionExplanationCard.shouldShow(5), isFalse);
    });

    testWidgets('renders copy and both actions', (tester) async {
      var logged = 0;
      var recorded = 0;
      await _pumpCard(
        tester,
        FirstSessionExplanationCard(
          onLogPressure: () => logged++,
          onRecord: () => recorded++,
        ),
      );

      expect(find.text(FirstSessionExplanationCard.title), findsOneWidget);
      expect(find.text(FirstSessionExplanationCard.body), findsOneWidget);
      expect(find.text(FirstSessionExplanationCard.primaryLabel), findsOneWidget);
      expect(
        find.text(FirstSessionExplanationCard.secondaryLabel),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('first_session_log_pressure_cta')));
      await tester.tap(find.byKey(const Key('first_session_record_cta')));
      expect(logged, 1);
      expect(recorded, 1);
    });
  });

  group('First pressure win', () {
    testWidgets('first-win card renders its copy and CTA', (tester) async {
      var tapped = 0;
      await _pumpCard(
        tester,
        PressureFirstWinCard(onSeeMeaning: () => tapped++),
      );

      expect(find.text(PressureFirstWinCard.title), findsOneWidget);
      expect(find.text(PressureFirstWinCard.body), findsOneWidget);
      expect(find.text(PressureFirstWinCard.ctaLabel), findsOneWidget);

      await tester.tap(find.byKey(const Key('pressure_first_win_cta')));
      expect(tapped, 1);
    });

    testWidgets('first check-in shows first-win and CTA opens insights',
        (tester) async {
      await tester.runAsync(() async {
        final dir = Directory('test/tmp/first_session');
        if (!await dir.exists()) await dir.create(recursive: true);
        final journalPath = '${dir.path}/journal.json';
        final prefsPath = '${dir.path}/prefs.json';
        // Start from a clean archive so first-win detection is deterministic.
        for (final path in [journalPath, prefsPath]) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        await AppServices.resetForTest(
          journalPath: journalPath,
          prefsPath: prefsPath,
          skipRevenueCat: true,
        );
      });

      await tester.binding.setSurfaceSize(const Size(390, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PressureCheckInScreen(),
          ),
          GoRoute(
            path: '/pressure-insights',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('INSIGHTS_MARKER'))),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      await tester.tap(find.text("I couldn't stop even though I wanted to"));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pressure_quick_save_cta')));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      // First win replaces the generic quick-save success.
      expect(find.byKey(const Key('pressure_first_win_card')), findsOneWidget);
      expect(find.text(PressureFirstWinCard.title), findsOneWidget);
      expect(
        find.byKey(const Key('pressure_quick_save_success')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('pressure_first_win_cta')));
      await tester.pumpAndSettle();
      expect(find.text('INSIGHTS_MARKER'), findsOneWidget);
    });
  });

  group('Pressure insights activation copy', () {
    testWidgets('empty state shows improved copy and CTA', (tester) async {
      await _pumpInsights(tester, records: const []);

      expect(
        find.byKey(const Key('pressure_insights_empty_state')),
        findsOneWidget,
      );
      expect(find.text(PressureInsightsEmptyState.title), findsOneWidget);
      expect(find.text(PressureInsightsEmptyState.body), findsOneWidget);
      expect(find.text(PressureInsightsEmptyState.ctaLabel), findsOneWidget);
      // The full insight cards are not shown without data.
      expect(
        find.byKey(const Key('pressure_loop_visibility_card')),
        findsNothing,
      );
    });

    testWidgets('early-signal nudge appears for one entry', (tester) async {
      await _pumpInsights(tester, records: [_record(id: 'a')]);

      expect(
        find.byKey(const Key('pressure_first_week_nudge')),
        findsOneWidget,
      );
      expect(find.text(PressureFirstWeekNudge.title), findsOneWidget);
      expect(find.text(PressureFirstWeekNudge.body), findsOneWidget);
    });

    testWidgets('early-signal nudge appears for two entries', (tester) async {
      await _pumpInsights(
        tester,
        records: [_record(id: 'a'), _record(id: 'b')],
      );
      expect(
        find.byKey(const Key('pressure_first_week_nudge')),
        findsOneWidget,
      );
    });

    testWidgets('nudge is gone once there are three or more entries',
        (tester) async {
      await _pumpInsights(
        tester,
        records: [_record(id: 'a'), _record(id: 'b'), _record(id: 'c')],
      );
      expect(find.byKey(const Key('pressure_first_week_nudge')), findsNothing);
    });
  });

  group('No VoiceMemory consumer copy', () {
    testWidgets('first-session surfaces never show VoiceMemory', (tester) async {
      await _pumpCard(
        tester,
        Column(
          children: [
            FirstSessionExplanationCard(onLogPressure: () {}, onRecord: () {}),
            PressureFirstWinCard(onSeeMeaning: () {}),
            PressureInsightsEmptyState(onLogPressure: () {}),
            const PressureFirstWeekNudge(),
          ],
        ),
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });
}
