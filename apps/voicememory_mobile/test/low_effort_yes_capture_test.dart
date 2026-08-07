import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_three_moment_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/low_effort_yes_capture_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/low_effort_yes_capture_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/low_effort_yes_capture_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/yes_capture_timing.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capacity_three_moment_card.dart';
import 'package:voicememory_mobile/widgets/low_effort_yes_capture_card.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'subscribe now',
  'buy now',
  'pro is active',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'guilt',
  'streak',
];

const _privateSnippet = 'felt pressure at work before saying yes';

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
    expect(lower, isNot(contains('archiveme knows')));
    expect(lower, isNot(contains('burnout')));
    expect(lower, isNot(contains(_privateSnippet)));
  }
}

Future<void> _resetStores(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_low_effort_yes_capture_journal_$stamp.json',
    prefsPath: '/tmp/vm_low_effort_yes_capture_prefs_$stamp.json',
  );
  await CapacityPullReasonStore.resetForTest();
  await CapacityDecisionOutcomeStore.resetForTest();
}

LowEffortYesCaptureResult _visibleResult() =>
    const LowEffortYesCaptureEngine().build(
      const LowEffortYesCaptureInput(
        capacityWedgeActive: true,
        sampleMode: false,
        screenshotMode: false,
      ),
    );

void main() {
  const engine = LowEffortYesCaptureEngine();
  const loopEngine = CapacityLoopEngine();
  const threeMomentEngine = CapacityThreeMomentEngine();

  group('LowEffortYesCaptureEngine', () {
    test('quick save hidden for generic users without capacity context', () {
      final result = engine.build(
        const LowEffortYesCaptureInput(
          capacityWedgeActive: false,
          sampleMode: false,
          screenshotMode: false,
        ),
      );
      expect(result.showCard, isFalse);
    });

    test('quick save visible for capacity-yes users', () {
      final result = engine.build(
        const LowEffortYesCaptureInput(
          capacityWedgeActive: true,
          sampleMode: false,
          screenshotMode: false,
        ),
      );
      expect(result.showCard, isTrue);
      expect(result.title, 'Quick yes moment');
      expect(result.timingIds, LowEffortYesCaptureCopy.timingIds());
      expect(result.timingSectionTitle, 'When is this moment?');
    });

    test('quick save hidden in ScreenshotMode', () {
      final result = engine.build(
        const LowEffortYesCaptureInput(
          capacityWedgeActive: true,
          sampleMode: false,
          screenshotMode: true,
        ),
      );
      expect(result.showCard, isFalse);
    });

    test('quick save hidden for sample/demo-only mode', () {
      final result = engine.build(
        const LowEffortYesCaptureInput(
          capacityWedgeActive: true,
          sampleMode: true,
          screenshotMode: false,
        ),
      );
      expect(result.showCard, isFalse);
    });

    test('copy includes required strings', () {
      expect(
        LowEffortYesCaptureCopy.allVisibleStrings(),
        contains('Quick yes moment'),
      );
      expect(
        LowEffortYesCaptureCopy.allVisibleStrings().any(
          (text) => text.contains('No need to explain everything'),
        ),
        isTrue,
      );
      expect(
        LowEffortYesCaptureCopy.allVisibleStrings(),
        contains(LowEffortYesCaptureCopy.dashboardSignalAvailable),
      );
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy(LowEffortYesCaptureCopy.allVisibleStrings());
    });

    test('selected pull reason is saved using fixed IDs', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStores(stamp);

      final saveResult = await engine.saveQuickCapture(
        journal: AppServices.instance.journalStore,
        request: const LowEffortYesCaptureSaveRequest(
          pullReasonId: CapacityPullReasonIds.soundedUrgent,
          timingId: YesCaptureTimingIds.beforeYes,
          outcomeId: CapacityDecisionOutcomeIds.saidYes,
        ),
      );

      final pullRecords = await CapacityPullReasonStore.instance().loadAll();
      expect(saveResult.savedPullReason, isTrue);
      expect(pullRecords, hasLength(1));
      expect(pullRecords.first.reasonIds, [
        CapacityPullReasonIds.soundedUrgent,
      ]);
    });

    test('selected decision outcome is saved using fixed IDs', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStores(stamp);

      await engine.saveQuickCapture(
        journal: AppServices.instance.journalStore,
        request: const LowEffortYesCaptureSaveRequest(
          pullReasonId: CapacityPullReasonIds.feltResponsible,
          timingId: YesCaptureTimingIds.afterYes,
          outcomeId: CapacityDecisionOutcomeIds.delayed,
        ),
      );

      final outcomeRecords = await CapacityDecisionOutcomeStore.instance()
          .loadAll();
      expect(outcomeRecords, hasLength(1));
      expect(
        outcomeRecords.first.outcomeId,
        CapacityDecisionOutcomeIds.delayed,
      );
    });

    test(
      'quick capture creates capacity moment without transcript text',
      () async {
        final stamp = DateTime.now().microsecondsSinceEpoch.toString();
        await _resetStores(stamp);

        await engine.saveQuickCapture(
          journal: AppServices.instance.journalStore,
          request: const LowEffortYesCaptureSaveRequest(
            pullReasonId: CapacityPullReasonIds.wantedOpportunity,
            timingId: YesCaptureTimingIds.laterCost,
          ),
        );

        final entries = await AppServices.instance.journalStore.loadAll();
        expect(entries, hasLength(1));
        final entry = entries.first;
        expect(entry.transcript, isEmpty);
        expect(
          entry.captureContextTag,
          LowEffortYesCaptureIds.contextTagForTiming(
            YesCaptureTimingIds.laterCost,
          ),
        );
        expect(
          loopEngine.eligibleCapacityEntryIds(entries),
          contains(entry.id),
        );
      },
    );

    test('no private transcript text is stored', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStores(stamp);

      await engine.saveQuickCapture(
        journal: AppServices.instance.journalStore,
        request: const LowEffortYesCaptureSaveRequest(
          pullReasonId: CapacityPullReasonIds.somethingElse,
          timingId: YesCaptureTimingIds.beforeYes,
        ),
      );

      final entries = await AppServices.instance.journalStore.loadAll();
      for (final entry in entries) {
        expect(entry.transcript, isEmpty);
        expect(
          entry.transcript.toLowerCase(),
          isNot(contains(_privateSnippet)),
        );
      }
    });
  });

  group('LowEffortYesCaptureCard', () {
    testWidgets('hidden for generic users without capacity context', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LowEffortYesCaptureCard(
              result: const LowEffortYesCaptureEngine().build(
                const LowEffortYesCaptureInput(
                  capacityWedgeActive: false,
                  sampleMode: false,
                  screenshotMode: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('low_effort_yes_capture_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('visible for capacity-yes users', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LowEffortYesCaptureCard(result: _visibleResult()),
          ),
        ),
      );

      expect(
        find.byKey(const Key('low_effort_yes_capture_card')),
        findsOneWidget,
      );
      expect(find.text('Quick yes moment'), findsOneWidget);
      expect(
        find.textContaining('No need to explain everything'),
        findsOneWidget,
      );
    });

    testWidgets('hidden when engine returns hidden (screenshot path)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LowEffortYesCaptureCard(
              result: const LowEffortYesCaptureEngine().build(
                const LowEffortYesCaptureInput(
                  capacityWedgeActive: true,
                  sampleMode: false,
                  screenshotMode: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('low_effort_yes_capture_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('hidden for sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LowEffortYesCaptureCard(
              result: _visibleResult(),
              sampleMode: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('low_effort_yes_capture_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('normal recording remains available via Record instead', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: LowEffortYesCaptureCard(result: _visibleResult()),
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) =>
                const Scaffold(body: Text('record screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(
        find.byKey(const Key('low_effort_yes_capture_card_record_instead')),
      );
      await tester.pumpAndSettle();

      expect(find.text('record screen'), findsOneWidget);
    });

    testWidgets('routes to quick capture screen', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: LowEffortYesCaptureCard(result: _visibleResult()),
            ),
          ),
          GoRoute(
            path: '/quick-yes-capture',
            builder: (context, state) =>
                const Scaffold(body: Text('quick capture screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(
        find.byKey(const Key('low_effort_yes_capture_card_quick_save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('quick capture screen'), findsOneWidget);
    });
  });

  group('CapacityThreeMoment quick capture path', () {
    test('3-moment activation exposes quick save at 0/3 only', () {
      final zero = threeMomentEngine.buildFromJournal(
        entries: const [],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(zero.showQuickSaveSecondary, isTrue);
      expect(zero.quickSaveRoute, LowEffortYesCaptureCopy.route);

      final one = threeMomentEngine.buildFromJournal(
        entries: [
          JournalEntry(
            id: 'real_0',
            createdAt: DateTime(2026, 6, 12, 12),
            transcript: 'I felt pulled to agree again.',
            durationSeconds: 30,
            localAudioPath: '/tmp/real_0.m4a',
            reflection: const Reflection(
              mood: 'neutral',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: '',
              concreteObservation: 'Work pressure showed up in this moment.',
              repeatedSignal: '',
            ),
          ),
        ],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(one.showQuickSaveSecondary, isFalse);
    });

    test('3-moment activation hides quick save at target', () {
      final entries = List.generate(
        3,
        (i) => JournalEntry(
          id: 'real_$i',
          createdAt: DateTime(2026, 6, 12, 12 + i),
          transcript: 'I said yes again with no capacity left.',
          durationSeconds: 30,
          localAudioPath: '/tmp/real_$i.m4a',
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 2,
            recurringThemes: ['work'],
            exactLanguagePattern: '',
            concreteObservation: 'Work pressure showed up in this moment.',
            repeatedSignal: '',
          ),
        ),
      );
      final result = threeMomentEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(result.showQuickSaveSecondary, isFalse);
    });

    test('hidden for sample/demo-only entries', () {
      final result = threeMomentEngine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
      );
      expect(result.hasCard, isFalse);
    });

    testWidgets('3-moment card routes to quick capture', (tester) async {
      final result = threeMomentEngine.buildFromJournal(
        entries: const [],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: CapacityThreeMomentCard(result: result)),
          ),
          GoRoute(
            path: '/quick-yes-capture',
            builder: (context, state) =>
                const Scaffold(body: Text('quick capture screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(
        find.byKey(const Key('capacity_three_moment_card_quick_save_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('quick capture screen'), findsOneWidget);
    });
  });

  group('Routing and guards', () {
    test('quick capture route is sensitive', () {
      expect(
        SensitiveRoutes.isSensitiveRoute(LowEffortYesCaptureCopy.route),
        isTrue,
      );
    });
  });
}
