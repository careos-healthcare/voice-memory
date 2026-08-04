import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_analytics.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_exercise/daily_archive_exercise_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_copy.dart';
import 'package:voicememory_mobile/features/memory/entry_memory_mode.dart';
import 'package:voicememory_mobile/features/next_action/next_best_action_copy.dart';
import 'package:voicememory_mobile/features/proof_specificity/proof_specificity_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_engine.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_model.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/low_evidence/low_evidence_engine.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as weekly_review_surface;
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:voicememory_mobile/widgets/record/daily_archive_memory_card.dart';

import 'support/widget_test_pump.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: localAudioPath ?? '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeRelatedRepeatEntries() => [
  _entry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _fourRelatedRepeatEntries() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'The meeting invite came in and I said yes again with no capacity left for it.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

JournalEntry _genericTestEntry({String id = 'g1'}) =>
    _entry(id: id, transcript: 'This is a test to check function');

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: _placeholder,
  durationSeconds: 20,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _fiveRelatedRepeatEntries() => [
  ..._fourRelatedRepeatEntries(),
  _entry(
    id: 'e5',
    transcript:
        'I said yes again even though I had no capacity for one more ask today.',
    createdAt: DateTime(2026, 6, 14, 12),
  ),
];

void main() {
  setUp(() {
    DailyArchiveMemoryAnalytics.resetForTest();
  });

  tearDown(() {
    VisualAuditOverrides.setRecordPresentation(null);
  });

  group('DailyArchiveMemoryCopy', () {
    test('spec copy is stable', () {
      expect(DailyArchiveMemoryCopy.watchTitle, 'Did this come back?');
      expect(
        DailyArchiveMemoryCopy.watchBody,
        'Last time, your watch target was:',
      );
      expect(
        DailyArchiveMemoryCopy.footer,
        'Record if it came back, changed, faded, or disappeared.',
      );
      expect(DailyArchiveMemoryCopy.recordCta, 'Record what happened');
      expect(DailyArchiveMemoryCopy.typeInsteadCta, 'Type instead');
      expect(DailyArchiveMemoryCopy.notTodayCta, 'Not today');
      expect(
        DailyArchiveMemoryCopy.viewPatternDetailsCta,
        'View pattern details',
      );
      expect(DailyArchiveMemoryCopy.fallbackTitle, 'Your archive is ready');
      expect(
        DailyArchiveMemoryCopy.fallbackBody,
        'Record one real moment from today. ArchiveMe will compare it with what came before.',
      );
    });

    test('watch copy uses a single-quoted watch target', () {
      expect(
        DailyArchiveMemoryCopy.watchSubtext('checking again'),
        "Last time, your watch target was: 'checking again'",
      );
      expect(
        DailyArchiveMemoryCopy.quotedWatchPhrase('checking again'),
        "'checking again'",
      );
    });

    test('no advice or coaching language', () {
      final joined = [
        DailyArchiveMemoryCopy.watchTitle,
        DailyArchiveMemoryCopy.watchBody,
        DailyArchiveMemoryCopy.footer,
        DailyArchiveMemoryCopy.fallbackBody,
      ].join(' ').toLowerCase();

      expect(ProofSurfaceAdviceGuard.passes(joined), isTrue);
      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('revenuecat')));
    });
  });

  group('DailyArchiveMemoryGates', () {
    test('hidden at entry count zero', () {
      expect(
        DailyArchiveMemoryGates.shouldShow(
          loaded: true,
          entryCount: 0,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          memory: const DailyArchiveMemoryResult(
            title: DailyArchiveMemoryCopy.fallbackTitle,
            body: DailyArchiveMemoryCopy.fallbackBody,
            hasWatchTarget: false,
            canShowPatternDetail: false,
          ),
          showReturnDayFlow: false,
          showReturnTomorrowCueReady: false,
          showLowEvidenceGuidance: false,
          showWeeklyArchiveReview: false,
          firstProofLoopActive: false,
        ),
        isFalse,
      );
    });

    test('hidden during post-save recording and first proof loop', () {
      final memory = DailyArchiveMemoryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      for (final isPostSave in [true, false]) {
        expect(
          DailyArchiveMemoryGates.shouldShow(
            loaded: true,
            entryCount: 3,
            isReady: true,
            isRecording: true,
            isPostSave: isPostSave,
            memory: memory,
            showReturnDayFlow: false,
            showReturnTomorrowCueReady: false,
            showLowEvidenceGuidance: false,
            showWeeklyArchiveReview: false,
            firstProofLoopActive: false,
          ),
          isFalse,
        );
      }

      expect(
        DailyArchiveMemoryGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          isPostSave: true,
          memory: memory,
          showReturnDayFlow: false,
          showReturnTomorrowCueReady: false,
          showLowEvidenceGuidance: false,
          showWeeklyArchiveReview: false,
          firstProofLoopActive: false,
        ),
        isFalse,
      );

      expect(
        DailyArchiveMemoryGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          memory: memory,
          showReturnDayFlow: false,
          showReturnTomorrowCueReady: false,
          showLowEvidenceGuidance: false,
          showWeeklyArchiveReview: false,
          firstProofLoopActive: true,
        ),
        isTrue,
      );
    });

    test('active watch target takes priority over other ready guidance', () {
      final memory = DailyArchiveMemoryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );

      for (final blocked in [
        (
          showReturnDayFlow: true,
          showLowEvidenceGuidance: false,
          showWeeklyArchiveReview: false,
        ),
        (
          showReturnDayFlow: false,
          showLowEvidenceGuidance: true,
          showWeeklyArchiveReview: false,
        ),
        (
          showReturnDayFlow: false,
          showLowEvidenceGuidance: false,
          showWeeklyArchiveReview: true,
        ),
      ]) {
        expect(
          DailyArchiveMemoryGates.shouldShow(
            loaded: true,
            entryCount: 3,
            isReady: true,
            isRecording: false,
            isPostSave: false,
            memory: memory,
            showReturnDayFlow: blocked.showReturnDayFlow,
            showReturnTomorrowCueReady: false,
            showLowEvidenceGuidance: blocked.showLowEvidenceGuidance,
            showWeeklyArchiveReview: blocked.showWeeklyArchiveReview,
            firstProofLoopActive: false,
          ),
          isTrue,
        );
      }
    });
  });

  group('DailyArchiveMemoryEngine', () {
    test('returns null for entry count zero archive', () {
      expect(
        DailyArchiveMemoryEngine.build(
          entries: const [],
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('shown for returning user with grounded watch target', () {
      final result = DailyArchiveMemoryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      expect(result.hasWatchTarget, isTrue);
      expect(result.title, DailyArchiveMemoryCopy.watchTitle);
      expect(result.body, DailyArchiveMemoryCopy.watchBody);
      expect(result.watchPhrase, isNotNull);
      expect(result.watchPhrase, isNotEmpty);
      expect(result.footer, DailyArchiveMemoryCopy.footer);
      expect(
        FirstProofMomentEngine.build(entries: _threeRelatedRepeatEntries()),
        isNotNull,
      );
    });

    test('active target uses its source saved moment quote', () {
      final entries = [
        _entry(
          id: 'older',
          transcript: 'I kept checking messages after I wanted to stop.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'newer',
          transcript: 'I said yes before checking whether I had capacity.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
      ];
      final result = DailyArchiveMemoryEngine.build(
        entries: entries,
        pendingWatchFor: WatchForItem(
          id: 'watch-1',
          createdAt: DateTime(2026, 6, 10),
          targetDate: DateTime(2026, 6, 11),
          sourceReflectionId: 'older',
          text: 'Notice whether checking comes back.',
          chips: const ['checking'],
          status: WatchForStatus.pending,
          result: WatchForResult.none,
        ),
      )!;

      expect(result.hasWatchTarget, isTrue);
      expect(
        result.watchPhrase,
        'I kept checking messages after I wanted to stop.',
      );
    });

    test('uses latest saved moment when no explicit target exists', () {
      final result = DailyArchiveMemoryEngine.build(
        entries: [
          _entry(
            id: 'u1',
            transcript:
                'A calm afternoon walk helped me slow down before dinner tonight.',
          ),
        ],
        viewingConfirmedRepeatOrTimeline: false,
      )!;

      expect(result.hasWatchTarget, isTrue);
      expect(result.title, DailyArchiveMemoryCopy.watchTitle);
      expect(result.body, DailyArchiveMemoryCopy.watchBody);
      expect(
        result.watchPhrase,
        'A calm afternoon walk helped me slow down before dinner tonight.',
      );
    });

    test('generic test pending and degraded entries do not produce target', () {
      expect(
        DailyArchiveMemoryEngine.build(
          entries: [
            _genericTestEntry(),
            _genericTestEntry(id: 'g2'),
          ],
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
      expect(
        DailyArchiveMemoryEngine.build(
          entries: [
            _degradedVoiceEntry(),
            _degradedVoiceEntry(id: 'v2'),
          ],
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('pattern detail availability follows existing engine', () {
      final result = DailyArchiveMemoryEngine.build(
        entries: _fourRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      expect(
        PatternDetailEngine.canShow(
          entries: _fourRelatedRepeatEntries(),
          viewingConfirmedRepeatOrTimeline: true,
        ),
        result.canShowPatternDetail,
      );
    });
  });

  group('DailyArchiveMemoryCard', () {
    testWidgets('renders watch and fallback states', (tester) async {
      const watch = DailyArchiveMemoryResult(
        title: DailyArchiveMemoryCopy.watchTitle,
        body: DailyArchiveMemoryCopy.watchBody,
        watchPhrase: 'saying yes before checking your capacity',
        footer: DailyArchiveMemoryCopy.footer,
        hasWatchTarget: true,
        canShowPatternDetail: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DailyArchiveMemoryCard(
              memory: watch,
              entryCount: 3,
              source: 'record',
              onRecord: () {},
              onViewPatternDetails: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('daily_archive_memory_card')),
        findsOneWidget,
      );
      expect(find.text(DailyArchiveMemoryCopy.watchTitle), findsOneWidget);
      expect(
        find.text(
          DailyArchiveMemoryCopy.quotedWatchPhrase(
            'saying yes before checking your capacity',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(DailyArchiveMemoryCopy.recordCta), findsOneWidget);
      expect(
        find.text(DailyArchiveMemoryCopy.viewPatternDetailsCta),
        findsOneWidget,
      );
    });

    testWidgets('focused target offers permanent reminder suppression', (
      tester,
    ) async {
      var suppressed = false;
      const watch = DailyArchiveMemoryResult(
        title: DailyArchiveMemoryCopy.watchTitle,
        body: DailyArchiveMemoryCopy.watchBody,
        watchPhrase: 'saying yes before checking your capacity',
        footer: DailyArchiveMemoryCopy.footer,
        hasWatchTarget: true,
        canShowPatternDetail: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DailyArchiveMemoryCard(
              memory: watch,
              entryCount: 3,
              source: 'record',
              showFocusedCaptureActions: true,
              onRecord: () {},
              onNotToday: () {},
              onDontRemindAgain: () => suppressed = true,
            ),
          ),
        ),
      );

      expect(
        find.text(DailyArchiveMemoryCopy.dontRemindAgainCta),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('daily_archive_memory_dont_remind_again_cta')),
      );
      await tester.pump();
      expect(suppressed, isTrue);
    });
  });

  group('DailyArchiveMemoryAnalytics', () {
    test('metadata only without transcript text', () {
      final events = <String, Map<String, Object>>{};
      DailyArchiveMemoryAnalytics.captureForTest = (event, props) {
        events[event] = props;
      };

      DailyArchiveMemoryAnalytics.seen(
        source: 'record',
        entryCount: 3,
        hasWatchTarget: true,
      );
      DailyArchiveMemoryAnalytics.ctaTapped(
        source: 'record',
        entryCount: 3,
        actionType: 'record_what_happened',
      );
      DailyArchiveMemoryAnalytics.ctaTapped(
        source: 'record',
        entryCount: 3,
        actionType: 'view_pattern_details',
      );

      expect(
        events[DailyArchiveMemoryAnalytics.seenEvent]!['has_watch_target'],
        1,
      );
      expect(
        events[DailyArchiveMemoryAnalytics.seenEvent]!['source'],
        'record',
      );
      expect(events.containsKey('transcript'), isFalse);
      for (final props in events.values) {
        expect(props.containsKey('transcript'), isFalse);
        expect(
          props.values.whereType<String>(),
          isNot(contains('saying yes before checking your capacity')),
        );
      }
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'vm_daily_archive_memory_',
      );
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        prefsPath: '${tempDir.path}/prefs.json',
        skipRevenueCat: true,
      );
    });

    setUp(() async {
      await AppServices.instance.journalStore.replaceAll(const []);
    });

    tearDownAll(() async {
      await AppServices.disposeForTest();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> pumpRecord(
      WidgetTester tester, {
      int entryCount = 5,
      bool waitForPermissionRefresh = false,
    }) async {
      if (entryCount > 0) {
        final entries = entryCount >= 3
            ? _fiveRelatedRepeatEntries().take(entryCount)
            : [
                _entry(
                  id: 'u1',
                  transcript:
                      'A calm afternoon walk helped me slow down before dinner tonight.',
                ),
              ];
        await tester.runAsync(
          () => AppServices.instance.journalStore.replaceAll(entries.toList()),
        );
      }
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      final readyFinder = entryCount == 0
          ? find.byKey(const Key('capture_entry_record_cta'))
          : find.byKey(const Key('daily_archive_memory_card'));
      if (readyFinder.evaluate().isEmpty) {
        await pumpUntilFound(tester, readyFinder);
      }
      if (waitForPermissionRefresh) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('hidden at entry count zero', (tester) async {
      await pumpRecord(tester, entryCount: 0);

      expect(find.byKey(const Key('daily_archive_memory_card')), findsNothing);
    });

    testWidgets('one saved moment shows focused watch target actions', (
      tester,
    ) async {
      await pumpRecord(tester, entryCount: 1);

      expect(
        find.byKey(const Key('daily_archive_memory_watch_headline')),
        findsOneWidget,
      );
      expect(find.text(DailyArchiveMemoryCopy.watchTitle), findsOneWidget);
      expect(
        find.textContaining('Last time, your watch target was:'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_record_cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_type_instead_cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_not_today_cta')),
        findsOneWidget,
      );
    });

    testWidgets('focused watch surface hides competing guidance', (
      tester,
    ) async {
      await pumpRecord(tester);

      expect(
        find.byKey(const Key('daily_archive_memory_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_watch_prompt')),
        findsOneWidget,
      );
      expect(find.textContaining('Did this come back?'), findsOneWidget);
      expect(find.text(DailyArchiveExerciseCopy.recordLabel), findsNothing);
      expect(
        find.text(DailyArchiveExerciseCopy.openBetaFeedbackCta),
        findsNothing,
      );
      expect(
        find.textContaining(
          ProofSpecificityCopy.captureFreedomLineCompact.split('.').first,
        ),
        findsNothing,
      );
      for (final line in NextBestActionCopy.allVisibleStrings) {
        if (line.startsWith('Next:')) {
          expect(find.text(line), findsNothing);
        }
      }
      expect(
        find.textContaining(
          EntryMemoryModeCopy.advancedSaveOptionsCollapsedHelper
              .split('.')
              .first,
        ),
        findsNothing,
      );
      expect(find.text(ConsumerUiCopy.recordTitle), findsNothing);
      expect(find.text(FirstWeekLoopCopy.title), findsNothing);
      expect(find.text(FirstWeekLoopCopy.label), findsNothing);
      expect(find.text('Day 1 of 7'), findsNothing);
      expect(find.textContaining('What is on your mind'), findsNothing);
      expect(find.byKey(const Key('capture_context_tag_card')), findsNothing);
      expect(find.byKey(const Key('entry_options_section')), findsNothing);
    });

    testWidgets('shown for returning user with watch target', (tester) async {
      await pumpRecord(tester);

      expect(
        find.byKey(const Key('daily_archive_memory_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_watch_prompt')),
        findsOneWidget,
      );
      expect(find.textContaining('Did this come back?'), findsOneWidget);
    });

    testWidgets('active watch target takes priority over weekly review', (
      tester,
    ) async {
      await pumpRecord(tester, entryCount: 3);

      expect(
        weekly_review_surface.WeeklyArchiveReviewEngine.shouldShow(
          entries: _threeRelatedRepeatEntries(),
        ),
        isTrue,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_watch_headline')),
        findsOneWidget,
      );
    });

    testWidgets('focused watch card is primary capture surface', (
      tester,
    ) async {
      await pumpRecord(tester);

      expect(
        find.byKey(const Key('daily_archive_memory_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_watch_prompt')),
        findsOneWidget,
      );
      expect(find.textContaining('Did this come back?'), findsOneWidget);
      expect(
        find.byKey(const Key('daily_archive_memory_record_cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_type_instead_cta')),
        findsOneWidget,
      );
      expect(find.text('Record moment'), findsNothing);
      expect(find.text('Log pressure moment'), findsNothing);
      expect(find.text(ConsumerUiCopy.recordTitle), findsNothing);
    });

    testWidgets(
      'record CTA uses existing capture flow without duplicate CTAs',
      (tester) async {
        await pumpRecord(tester, waitForPermissionRefresh: true);

        expect(
          find.byKey(const Key('daily_archive_memory_record_cta')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('daily_archive_memory_record_cta')),
        );
        await tester.pump();
        expect(find.byKey(const Key('capture_entry_record_cta')), findsNothing);
      },
    );

    testWidgets('Not today dismisses watch card without streak pressure', (
      tester,
    ) async {
      await pumpRecord(tester, waitForPermissionRefresh: true);

      expect(
        find.byKey(const Key('daily_archive_memory_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily_archive_memory_not_today_cta')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('daily_archive_memory_not_today_cta')),
      );
      await pumpUntilAbsent(
        tester,
        find.byKey(const Key('daily_archive_memory_card')),
      );

      expect(find.byKey(const Key('daily_archive_memory_card')), findsNothing);
      expect(find.text('Day 1 of 7'), findsNothing);
      expect(find.text(FirstWeekLoopCopy.label), findsNothing);
      expect(find.textContaining('What is on your mind'), findsNothing);
      expect(find.textContaining('streak'), findsNothing);
      expect(find.textContaining('missed'), findsNothing);
      expect(find.textContaining('homework'), findsNothing);
      expect(find.byKey(const Key('capture_context_tag_card')), findsNothing);
      expect(find.byKey(const Key('entry_options_section')), findsNothing);
    });

    testWidgets('view pattern details opens sheet when available', (
      tester,
    ) async {
      await pumpRecord(tester, waitForPermissionRefresh: true);

      if (find
          .byKey(const Key('daily_archive_memory_pattern_details_cta'))
          .evaluate()
          .isEmpty) {
        return;
      }

      await tester.tap(
        find.byKey(const Key('daily_archive_memory_pattern_details_cta')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PatternDetailSheet), findsOneWidget);
    });
  });

  group('Protected areas', () {
    test('first proof and weekly review engines unchanged', () {
      expect(
        FirstProofMomentEngine.build(entries: _threeRelatedRepeatEntries()),
        isNotNull,
      );
      expect(
        weekly_review_surface.WeeklyArchiveReviewEngine.shouldShow(
          entries: _fourRelatedRepeatEntries(),
        ),
        isTrue,
      );
      expect(
        LowEvidenceEngine.buildForRecordReady(entries: [_genericTestEntry()]),
        isNotNull,
      );
      expect(
        ReturnDayFlowEngine.build(
          entries: _fourRelatedRepeatEntries(),
          now: DateTime(2026, 6, 14, 12),
        ),
        isNotNull,
      );
    });
  });
}
