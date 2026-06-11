import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/first_session/first_save_rescue.dart';
import 'package:voicememory_mobile/features/first_session/two_day_activation_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/done_for_today_receipt_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/pressure_check_in_screen.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';
import 'package:voicememory_mobile/widgets/first_session/first_save_rescue_card.dart';
import 'package:voicememory_mobile/widgets/first_session/first_session_explanation_card.dart';
import 'package:voicememory_mobile/widgets/first_session/two_day_activation_card.dart';
import 'package:voicememory_mobile/widgets/record/done_for_today_receipt_card.dart';
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

    testWidgets('renders the exact loop copy and both actions', (tester) async {
      var logged = 0;
      var recorded = 0;
      await _pumpCard(
        tester,
        FirstSessionExplanationCard(
          onLogPressure: () => logged++,
          onRecord: () => recorded++,
        ),
      );

      expect(find.text('How ArchiveMe works'), findsOneWidget);
      expect(find.text('Record one small thing.'), findsOneWidget);
      expect(find.text('ArchiveMe notices what repeats.'), findsOneWidget);
      expect(
        find.text('Tomorrow, check whether it returned, faded, or changed.'),
        findsOneWidget,
      );
      expect(find.text('That is enough for today.'), findsOneWidget);
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

    testWidgets('adds no extra choices beyond the two existing starts',
        (tester) async {
      await _pumpCard(
        tester,
        FirstSessionExplanationCard(onLogPressure: () {}, onRecord: () {}),
      );
      // Exactly the two pre-existing CTAs — no new prompt choices.
      expect(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        findsNWidgets(2),
      );
      expect(
        find.byKey(const Key('first_session_log_pressure_cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('first_session_record_cta')),
        findsOneWidget,
      );
      expect(find.text('Record this'), findsNothing);
    });

    test('no banned or pressure wording in the loop copy', () {
      final copy = [
        FirstSessionExplanationCard.title,
        ...FirstSessionExplanationCard.steps,
        FirstSessionExplanationCard.footer,
        FirstSessionExplanationCard.primaryLabel,
        FirstSessionExplanationCard.secondaryLabel,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'task',
        'homework',
        'must',
        'should',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnos',
        'definitely',
        'therapy',
        'treatment',
      ]) {
        expect(copy, isNot(contains(banned)),
            reason: 'copy must not contain "$banned"');
      }
      expect(copy, isNot(contains('voicememory')));
    });
  });

  group('First save rescue card', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
      FirstSaveRescue.resetForTest();
    });

    tearDown(() {
      ActivationFunnelAnalytics.resetForTest();
      FirstSaveRescue.resetForTest();
    });

    test('shows only at zero entries', () {
      expect(FirstSaveRescueCard.shouldShow(0), isTrue);
      expect(FirstSaveRescueCard.shouldShow(1), isFalse);
      expect(FirstSaveRescueCard.shouldShow(5), isFalse);
    });

    testWidgets('renders the exact copy with a single CTA', (tester) async {
      await _pumpCard(tester, FirstSaveRescueCard(onStart: () {}));

      expect(find.byKey(const Key('first_save_rescue_card')), findsOneWidget);
      expect(find.text('Try a 10-second test'), findsOneWidget);
      expect(
        find.text(
          'Say one sentence: \u201cWhat has been repeating lately?\u201d',
        ),
        findsOneWidget,
      );
      expect(find.text('You can delete it after.'), findsOneWidget);
      expect(find.text('Start test recording'), findsOneWidget);
      // Exactly one new CTA — nothing else to choose.
      expect(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        findsOneWidget,
      );
    });

    testWidgets('seen event fires once with counts only', (tester) async {
      await _pumpCard(tester, FirstSaveRescueCard(onStart: () {}));
      final seen = captured
          .where(
            (e) => e.event == ActivationFunnelAnalytics.firstSaveRescueSeen,
          )
          .toList();
      expect(seen, hasLength(1));
      expect(seen.single.properties, {'entry_count': 0});
    });

    testWidgets('CTA starts the existing recording flow and logs the tap',
        (tester) async {
      var started = 0;
      await _pumpCard(tester, FirstSaveRescueCard(onStart: () => started++));

      await tester.tap(find.byKey(const Key('first_save_rescue_cta')));
      expect(started, 1);
      expect(FirstSaveRescue.startedFromRescueThisSession, isTrue);

      final tapped = captured
          .where(
            (e) => e.event == ActivationFunnelAnalytics.firstSaveRescueTapped,
          )
          .toList();
      expect(tapped, hasLength(1));
      expect(tapped.single.properties, {'entry_count': 0});
    });

    testWidgets('no private content in any rescue payload', (tester) async {
      await _pumpCard(
        tester,
        FirstSaveRescueCard(onStart: () {}),
      );
      await tester.tap(find.byKey(const Key('first_save_rescue_cta')));

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(
          e.properties.keys.toSet().difference(
                ActivationFunnelAnalytics.allowedPropertyKeys,
              ),
          isEmpty,
        );
        final flat = '${e.event} ${e.properties.values.join(' ')}'.toLowerCase();
        expect(flat, isNot(contains('repeating lately')));
        expect(flat, isNot(contains('voicememory')));
      }
    });

    test('no banned words or VoiceMemory in the rescue copy', () {
      final copy = [
        FirstSaveRescueCard.title,
        FirstSaveRescueCard.body,
        FirstSaveRescueCard.reassurance,
        FirstSaveRescueCard.ctaLabel,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'task',
        'homework',
        'must',
        'should',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnos',
        'definitely',
        'therapy',
        'treatment',
      ]) {
        expect(copy, isNot(contains(banned)),
            reason: 'rescue copy must not contain "$banned"');
      }
      expect(copy, isNot(contains('voicememory')));
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

  group('Record screen first-session visibility', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_first_session_loop_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpRecordScreen(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('loop explanation appears before the first save',
        (tester) async {
      await pumpRecordScreen(tester);
      expect(
        find.byKey(const Key('first_session_explanation_card')),
        findsOneWidget,
      );
      expect(find.text('How ArchiveMe works'), findsOneWidget);
      expect(find.text('Record one small thing.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rescue appears at zero entries alongside the explainer',
        (tester) async {
      await pumpRecordScreen(tester);
      // Both first-session surfaces coexist; the rescue replaces nothing.
      expect(find.byKey(const Key('first_save_rescue_card')), findsOneWidget);
      expect(find.text('Try a 10-second test'), findsOneWidget);
      expect(
        find.byKey(const Key('first_session_explanation_card')),
        findsOneWidget,
      );
      expect(find.text('How ArchiveMe works'), findsOneWidget);
      // The normal recording path stays available — never blocked.
      expect(find.byType(CaptureEntryActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rescue hides once a recording is saved', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'e1',
            createdAt: DateTime(2026, 6, 1, 12),
            transcript:
                'A long enough transcript to count as a saved reflection.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'Work pressure showed up again today.',
              repeatedSignal: 'signal',
            ),
          ),
        );
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('first_save_rescue_card')), findsNothing);
      expect(find.text('Try a 10-second test'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loop explanation hides once a recording is saved',
        (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'e1',
            createdAt: DateTime(2026, 6, 1, 12),
            transcript:
                'A long enough transcript to count as a saved reflection.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'Work pressure showed up again today.',
              repeatedSignal: 'signal',
            ),
          ),
        );
      });
      await pumpRecordScreen(tester);
      expect(
        find.byKey(const Key('first_session_explanation_card')),
        findsNothing,
      );
      expect(find.text('How ArchiveMe works'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Two-day activation engine', () {
    const engine = TwoDayActivationEngine();
    final now = DateTime(2026, 6, 11, 9);
    final yesterday = DateTime(2026, 6, 10, 18);
    final threeDaysAgo = DateTime(2026, 6, 8, 18);
    final today = DateTime(2026, 6, 11, 8);

    test('day 1 plan for a brand-new user', () {
      final path = engine.build(entryCount: 0, now: now);
      expect(path.stage, TwoDayActivationStage.dayOneIntro);
      expect(path.title, 'Try ArchiveMe for 2 days');
      expect(path.lines, const [
        'Today: record one small thing.',
        'Tomorrow: check whether it returned, faded, or changed.',
        'That is enough.',
      ]);
    });

    test('day 1 complete only after the very first save', () {
      final first = engine.buildPostSave(entryCount: 1);
      expect(first.stage, TwoDayActivationStage.dayOneComplete);
      expect(first.title, 'Day 1 complete');
      expect(first.lines, const [
        'Tomorrow, ArchiveMe can compare this with what shows up next.',
      ]);
      expect(engine.buildPostSave(entryCount: 0).show, isFalse);
      expect(engine.buildPostSave(entryCount: 2).show, isFalse);
    });

    test('day 2 return moment when yesterday holds the only save', () {
      final path = engine.build(
        entryCount: 1,
        entryDates: [yesterday],
        now: now,
      );
      expect(path.stage, TwoDayActivationStage.dayTwoReturn);
      expect(path.title, 'Day 2: check what changed');
      expect(path.lines, const [
        'See whether yesterday\u2019s thread returned, faded, or changed.',
      ]);
    });

    test('missed days get cautious copy, never guilt', () {
      final path = engine.build(
        entryCount: 1,
        entryDates: [threeDaysAgo],
        now: now,
      );
      expect(path.stage, TwoDayActivationStage.dayTwoReturn);
      expect(path.lines, const [
        'See whether an earlier recording returned, faded, or changed.',
      ]);
    });

    test('nothing on the day of the first save itself', () {
      final path = engine.build(
        entryCount: 1,
        entryDates: [today],
        now: now,
      );
      expect(path.show, isFalse);
    });

    test('hides after the second-day return moment is complete', () {
      final path = engine.build(
        entryCount: 2,
        entryDates: [yesterday, today],
        now: now,
      );
      expect(path.show, isFalse);
    });

    test('hides at three or more entries', () {
      final path = engine.build(
        entryCount: 3,
        entryDates: [threeDaysAgo, yesterday, today],
        now: now,
      );
      expect(path.show, isFalse);
    });

    test('unreliable dates fall back to count-only cautious copy', () {
      final futureDate = now.add(const Duration(days: 2));
      for (final dates in [
        <DateTime>[],
        [futureDate],
      ]) {
        final path = engine.build(entryCount: 1, entryDates: dates, now: now);
        expect(path.stage, TwoDayActivationStage.dayTwoReturn);
        expect(path.lines, const [
          'See whether an earlier recording returned, faded, or changed.',
        ]);
      }
    });

    test('no streak, guilt, banned words, or VoiceMemory in the copy', () {
      final copy = [
        TwoDayActivationPath.dayOneTitle,
        ...TwoDayActivationPath.dayOneLines,
        TwoDayActivationPath.dayOneCompleteTitle,
        TwoDayActivationPath.dayOneCompleteLine,
        TwoDayActivationPath.dayTwoTitle,
        TwoDayActivationPath.dayTwoLine,
        TwoDayActivationPath.dayTwoCautiousLine,
      ].join(' ');
      final lower = copy.toLowerCase();
      for (final banned in const [
        'streak',
        'must',
        'should',
        'task',
        'homework',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnos',
        'definitely',
        'missed',
        'guilt',
        'come back',
        'every day',
        'don\u2019t break',
      ]) {
        expect(lower, isNot(contains(banned)),
            reason: '2-day path copy must not contain "$banned"');
      }
      expect(copy, isNot(contains('VoiceMemory')));
    });
  });

  group('Two-day activation card', () {
    testWidgets('renders the day 1 plan with no buttons', (tester) async {
      const engine = TwoDayActivationEngine();
      await _pumpCard(
        tester,
        TwoDayActivationCard(
          path: engine.build(entryCount: 0, now: DateTime(2026, 6, 11)),
        ),
      );

      expect(find.byKey(const Key('two_day_activation_card')), findsOneWidget);
      expect(find.text('Try ArchiveMe for 2 days'), findsOneWidget);
      expect(find.text('Today: record one small thing.'), findsOneWidget);
      expect(
        find.text('Tomorrow: check whether it returned, faded, or changed.'),
        findsOneWidget,
      );
      expect(find.text('That is enough.'), findsOneWidget);
      // Passive card — no buttons, nothing to block or require.
      expect(find.byWidgetPredicate((w) => w is ButtonStyleButton),
          findsNothing);
    });

    testWidgets('renders nothing without a stage', (tester) async {
      await _pumpCard(
        tester,
        TwoDayActivationCard(path: TwoDayActivationPath.none()),
      );
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
    });

    testWidgets('day 1 closure coexists with the Done for today receipt',
        (tester) async {
      const twoDay = TwoDayActivationEngine();
      final receipt = const DoneForTodayReceiptEngine()
          .build(saved: true, now: DateTime(2026, 6, 11, 12));
      await _pumpCard(
        tester,
        Column(
          children: [
            DoneForTodayReceiptCard(receipt: receipt),
            const SizedBox(height: 16),
            TwoDayActivationCard(path: twoDay.buildPostSave(entryCount: 1)),
          ],
        ),
      );

      // Done for today still appears — the 2-day closure sits below it.
      final doneCard = find.byKey(const Key('done_for_today_receipt_card'));
      final twoDayCard = find.byKey(const Key('two_day_activation_card'));
      expect(doneCard, findsOneWidget);
      expect(find.text('Done for today'), findsOneWidget);
      expect(twoDayCard, findsOneWidget);
      expect(find.text('Day 1 complete'), findsOneWidget);
      expect(
        find.text(
          'Tomorrow, ArchiveMe can compare this with what shows up next.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(doneCard).dy,
        lessThan(tester.getTopLeft(twoDayCard).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Record screen 2-day path visibility', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_two_day_path_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpRecordScreen(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> seedEntries(List<DateTime> dates) async {
      for (var i = 0; i < dates.length; i++) {
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'seed_$i',
            createdAt: dates[i],
            transcript:
                'A long enough transcript to count as a saved reflection.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'Work pressure showed up again today.',
              repeatedSignal: 'signal',
            ),
          ),
        );
      }
    }

    testWidgets('day 1 plan appears for a new user', (tester) async {
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('two_day_activation_card')), findsOneWidget);
      expect(find.text('Try ArchiveMe for 2 days'), findsOneWidget);
      expect(find.text('Today: record one small thing.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('day 2 return copy appears when yesterday holds one save',
        (tester) async {
      await tester.runAsync(() async {
        await seedEntries([
          DateTime.now().subtract(const Duration(days: 1)),
        ]);
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('two_day_activation_card')), findsOneWidget);
      expect(find.text('Day 2: check what changed'), findsOneWidget);
      expect(
        find.text(
          'See whether yesterday\u2019s thread returned, faded, or changed.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the path never blocks recording', (tester) async {
      await tester.runAsync(() async {
        await seedEntries([
          DateTime.now().subtract(const Duration(days: 1)),
        ]);
      });
      await pumpRecordScreen(tester);
      // The day-2 card and the normal record entry actions coexist.
      expect(find.byKey(const Key('two_day_activation_card')), findsOneWidget);
      expect(find.byType(CaptureEntryActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides once the archive holds three or more entries',
        (tester) async {
      await tester.runAsync(() async {
        await seedEntries([
          DateTime.now().subtract(const Duration(days: 3)),
          DateTime.now().subtract(const Duration(days: 2)),
          DateTime.now().subtract(const Duration(days: 1)),
        ]);
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides after the second-day return moment is complete',
        (tester) async {
      await tester.runAsync(() async {
        await seedEntries([
          DateTime.now().subtract(const Duration(days: 1)),
          DateTime.now(),
        ]);
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
      expect(tester.takeException(), isNull);
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
