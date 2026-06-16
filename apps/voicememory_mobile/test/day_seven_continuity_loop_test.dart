import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/first_session/day_seven_continuity_loop.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';
import 'package:voicememory_mobile/widgets/first_session/day_seven_continuity_card.dart';

import 'support/memory_pressure_stores.dart';

const _engine = DaySevenContinuityEngine();

JournalEntry _entry(String id, {DateTime? createdAt}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 1)),
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

PressureCheckInRecord _checkIn({
  required String id,
  required int daysAgo,
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
    optionId: 'could_not_stop',
    contextIds: const ['work'],
    fear: fear,
    transcript: 'pressure moment',
  );
}

/// A connected work thread that genuinely produces a weekly review.
List<PressureCheckInRecord> _reviewReadyRecords() => [
  _checkIn(id: 'a', daysAgo: 6),
  _checkIn(id: 'b', daysAgo: 3, fear: 'The deadline slipping'),
  _checkIn(id: 'c', daysAgo: 0, fear: 'Late emails piling up'),
];

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<({String event, Map<String, Object> properties})> eventsNamed(
    String name,
  ) => captured.where((e) => e.event == name).toList();

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('Engine visibility', () {
    test('nothing at 0 entries', () {
      final loop = _engine.build(entryCount: 0, hasWeeklyReview: false);
      expect(loop.show, isFalse);
      expect(loop.stage, DaySevenContinuityStage.none);
    });

    test('nothing after the first save only', () {
      final loop = _engine.build(entryCount: 1, hasWeeklyReview: false);
      expect(loop.show, isFalse);
      // Even a weekly review never surfaces continuity copy at 0–1 entries.
      expect(_engine.build(entryCount: 1, hasWeeklyReview: true).show, isFalse);
    });

    test('appears at 2 entries — the Day 2 return moment', () {
      final loop = _engine.build(entryCount: 2, hasWeeklyReview: false);
      expect(loop.show, isTrue);
      expect(loop.stage, DaySevenContinuityStage.earlyThread);
      expect(loop.stageId, 'early_thread');
      expect(loop.hasCta, isFalse);
    });

    test('building stage covers 3–6 entries', () {
      for (final count in [3, 4, 5, 6]) {
        final loop = _engine.build(entryCount: count, hasWeeklyReview: false);
        expect(
          loop.stage,
          DaySevenContinuityStage.buildingArchive,
          reason: 'entryCount=$count',
        );
        expect(loop.stageId, 'building_archive');
        expect(loop.hasCta, isFalse);
      }
    });

    test('hides at 7+ entries when no weekly review exists', () {
      for (final count in [7, 8, 20]) {
        expect(
          _engine.build(entryCount: count, hasWeeklyReview: false).show,
          isFalse,
          reason: 'entryCount=$count',
        );
      }
    });

    test('weekly review takes precedence at any count from 2 up', () {
      for (final count in [2, 4, 7, 20]) {
        final loop = _engine.build(entryCount: count, hasWeeklyReview: true);
        expect(
          loop.stage,
          DaySevenContinuityStage.weeklyReviewReady,
          reason: 'entryCount=$count',
        );
        expect(loop.stageId, 'weekly_review_ready');
        expect(loop.hasCta, isTrue);
      }
    });
  });

  group('Copy', () {
    test('2-entry copy is exact', () {
      final loop = _engine.build(entryCount: 2, hasWeeklyReview: false);
      expect(loop.title, 'Keep the thread visible');
      expect(
        loop.body,
        'One more recording this week can help ArchiveMe see what is '
        'returning, fading, or changing.',
      );
      expect(loop.helper, 'Only if it still feels worth checking.');
      expect(loop.ctaLabel, isEmpty);
    });

    test('3–5 entry copy is exact', () {
      final loop = _engine.build(entryCount: 4, hasWeeklyReview: false);
      expect(loop.title, 'Your archive is starting to compare');
      expect(
        loop.body,
        'ArchiveMe has enough evidence to notice early movement. A few more '
        'recordings can make the weekly review clearer.',
      );
      expect(loop.helper, 'No need to record everything.');
      expect(loop.ctaLabel, isEmpty);
    });

    test('weekly review ready copy is exact, with the only CTA', () {
      final loop = _engine.build(entryCount: 4, hasWeeklyReview: true);
      expect(loop.title, 'Your weekly review is ready');
      expect(loop.body, 'See what returned, faded, or changed this week.');
      expect(loop.helper, isEmpty);
      expect(loop.ctaLabel, 'View weekly review');
    });

    test('no streak/daily/guilt language, banned words, or VoiceMemory', () {
      final copy = [
        DaySevenContinuityEngine.earlyThreadTitle,
        DaySevenContinuityEngine.earlyThreadBody,
        DaySevenContinuityEngine.earlyThreadHelper,
        DaySevenContinuityEngine.buildingTitle,
        DaySevenContinuityEngine.buildingBody,
        DaySevenContinuityEngine.buildingHelper,
        DaySevenContinuityEngine.reviewReadyTitle,
        DaySevenContinuityEngine.reviewReadyBody,
        DaySevenContinuityEngine.reviewReadyCta,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'streak',
        'daily',
        'habit',
        'guilt',
        'missed',
        'behind',
        'task',
        'homework',
        'must',
        'should',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnose',
        'definitely',
        'therapy',
        'treatment',
        'voicememory',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'continuity copy must not contain "$banned"',
        );
      }
    });
  });

  group('Continuity card widget', () {
    Future<void> pumpCard(
      WidgetTester tester,
      DaySevenContinuityLoop loop, {
      int entryCount = 0,
      bool hasConnectedThread = false,
      VoidCallback? onViewWeeklyReview,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DaySevenContinuityCard(
              loop: loop,
              entryCount: entryCount,
              hasConnectedThread: hasConnectedThread,
              onViewWeeklyReview: onViewWeeklyReview ?? () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('passive while building — no CTA, no buttons at all', (
      tester,
    ) async {
      final loop = _engine.build(entryCount: 2, hasWeeklyReview: false);
      await pumpCard(tester, loop, entryCount: 2);
      expect(find.text(loop.title), findsOneWidget);
      expect(find.text(loop.body), findsOneWidget);
      expect(find.text(loop.helper), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('day_seven_continuity_card')),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
        findsNothing,
      );
    });

    testWidgets('CTA appears only when the weekly review exists', (
      tester,
    ) async {
      final loop = _engine.build(entryCount: 4, hasWeeklyReview: true);
      await pumpCard(tester, loop, entryCount: 4, hasConnectedThread: true);
      expect(find.byKey(const Key('day_seven_continuity_cta')), findsOneWidget);
      expect(find.text('View weekly review'), findsOneWidget);
    });

    testWidgets('seen fires once per session with safe properties only', (
      tester,
    ) async {
      final loop = _engine.build(entryCount: 2, hasWeeklyReview: false);
      await pumpCard(tester, loop, entryCount: 2);
      await pumpCard(tester, loop, entryCount: 2); // Rebuild — no repeat.

      final seen = eventsNamed(ActivationFunnelAnalytics.day7ContinuitySeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties, {
        'entry_count': 2,
        'has_connected_thread': 0,
        'stage': 'early_thread',
      });
    });

    testWidgets('CTA tap logs the event and opens the review', (tester) async {
      var opened = 0;
      final loop = _engine.build(entryCount: 5, hasWeeklyReview: true);
      await pumpCard(
        tester,
        loop,
        entryCount: 5,
        hasConnectedThread: true,
        onViewWeeklyReview: () => opened++,
      );
      await tester.tap(find.byKey(const Key('day_seven_continuity_cta')));
      expect(opened, 1);

      final tapped = eventsNamed(
        ActivationFunnelAnalytics.day7ContinuityWeeklyReviewTapped,
      );
      expect(tapped, hasLength(1));
      expect(tapped.single.properties, {
        'entry_count': 5,
        'has_connected_thread': 1,
        'stage': 'weekly_review_ready',
      });
    });

    testWidgets('no private content in any continuity payload', (tester) async {
      final loop = _engine.build(entryCount: 4, hasWeeklyReview: true);
      await pumpCard(tester, loop, entryCount: 4);
      await tester.tap(find.byKey(const Key('day_seven_continuity_cta')));

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(
          e.properties.keys.toSet().difference(
            ActivationFunnelAnalytics.allowedPropertyKeys,
          ),
          isEmpty,
        );
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        expect(flat, isNot(contains('deadline')));
        expect(flat, isNot(contains('voicememory')));
      }
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_day7_continuity_');
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

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      List<PressureCheckInRecord> checkIns = const [],
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 3600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: RecordScreen(
                pressureCheckInStore: MemoryPressureCheckInStore(
                  List.of(checkIns),
                ),
                suggestionAttributionStore: MemorySuggestionAttributionStore(),
                entitlementReader: FakeArchiveEntitlementReader(pro: false),
              ),
            ),
          ),
          GoRoute(
            path: '/pressure-insights',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('INSIGHTS_MARKER'))),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> seedEntries(int count) async {
      for (var i = 0; i < count; i++) {
        await AppServices.instance.journalStore.save(
          _entry(
            'seed_$i',
            createdAt: DateTime.now().subtract(Duration(days: count - i)),
          ),
        );
      }
    }

    testWidgets('no card at 0 entries', (tester) async {
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('day_seven_continuity_card')), findsNothing);
    });

    testWidgets('no card after the first save only', (tester) async {
      await tester.runAsync(() => seedEntries(1));
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('day_seven_continuity_card')), findsNothing);
    });

    testWidgets('early-thread card appears at 2 entries, without a CTA', (
      tester,
    ) async {
      await tester.runAsync(() => seedEntries(2));
      await pumpRecordScreen(tester);
      expect(
        find.byKey(const Key('day_seven_continuity_card')),
        findsOneWidget,
      );
      expect(find.text('Keep the thread visible'), findsOneWidget);
      expect(find.byKey(const Key('day_seven_continuity_cta')), findsNothing);
      // Recording is never blocked.
      expect(find.byType(CaptureEntryActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('review-ready card routes to the existing weekly review', (
      tester,
    ) async {
      await tester.runAsync(() => seedEntries(3));
      await pumpRecordScreen(tester, checkIns: _reviewReadyRecords());

      expect(find.text('Your weekly review is ready'), findsOneWidget);
      final cta = find.byKey(const Key('day_seven_continuity_cta'));
      expect(cta, findsOneWidget);

      await tester.ensureVisible(cta);
      await tester.pump();
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(find.text('INSIGHTS_MARKER'), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.day7ContinuityWeeklyReviewTapped),
        hasLength(1),
      );
    });

    testWidgets('hides at 7+ entries when no weekly review exists', (
      tester,
    ) async {
      await tester.runAsync(() => seedEntries(8));
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('day_seven_continuity_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
