import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_analytics.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_engine.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_model.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/low_evidence/low_evidence_engine.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_engine.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as weeklyReviewSurface;
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:voicememory_mobile/widgets/record/daily_archive_memory_card.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? localAudioPath,
}) =>
    JournalEntry(
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

JournalEntry _genericTestEntry({String id = 'g1'}) => _entry(
      id: id,
      transcript: 'This is a test to check function',
    );

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
  setUp(() async {
    DailyArchiveMemoryAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() {
    VisualAuditOverrides.setRecordPresentation(null);
  });

  group('DailyArchiveMemoryCopy', () {
    test('spec copy is stable', () {
      expect(DailyArchiveMemoryCopy.watchTitle, 'Did this come back?');
      expect(
        DailyArchiveMemoryCopy.watchBody,
        'Last time, this was the thread to watch:',
      );
      expect(
        DailyArchiveMemoryCopy.footer,
        'Record if it came back, changed, or disappeared.',
      );
      expect(DailyArchiveMemoryCopy.recordCta, 'Record what happened');
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
        isFalse,
      );
    });

    test('does not stack with higher-priority guidance', () {
      final memory = DailyArchiveMemoryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );

      for (final blocked in [
        (showReturnDayFlow: true, showLowEvidenceGuidance: false, showWeeklyArchiveReview: false),
        (showReturnDayFlow: false, showLowEvidenceGuidance: true, showWeeklyArchiveReview: false),
        (showReturnDayFlow: false, showLowEvidenceGuidance: false, showWeeklyArchiveReview: true),
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
          isFalse,
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

    test('fallback for usable entry without grounded target', () {
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

      expect(result.hasWatchTarget, isFalse);
      expect(result.title, DailyArchiveMemoryCopy.fallbackTitle);
      expect(result.body, DailyArchiveMemoryCopy.fallbackBody);
      expect(result.watchPhrase, isNull);
    });

    test('generic test pending and degraded entries do not produce target', () {
      expect(
        DailyArchiveMemoryEngine.build(
          entries: [_genericTestEntry(), _genericTestEntry(id: 'g2')],
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

      expect(find.byKey(const Key('daily_archive_memory_card')), findsOneWidget);
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

      expect(events[DailyArchiveMemoryAnalytics.seenEvent]!['has_watch_target'], 1);
      expect(events[DailyArchiveMemoryAnalytics.seenEvent]!['source'], 'record');
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
    Future<void> pumpRecord(WidgetTester tester, {int entryCount = 5}) async {
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
        await tester.runAsync(() async {
          for (final entry in entries) {
            await AppServices.instance.journalStore.save(entry);
          }
        });
      }
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('hidden at entry count zero', (tester) async {
      await pumpRecord(tester, entryCount: 0);

      expect(find.byKey(const Key('daily_archive_memory_card')), findsNothing);
    });

    testWidgets('shown for returning user with watch target', (tester) async {
      await pumpRecord(tester);

      expect(find.byKey(const Key('daily_archive_memory_card')), findsOneWidget);
      expect(find.text(DailyArchiveMemoryCopy.watchTitle), findsOneWidget);
    });

    testWidgets('hidden when weekly review takes priority', (tester) async {
      await pumpRecord(tester, entryCount: 3);

      expect(
        weeklyReviewSurface.WeeklyArchiveReviewEngine.shouldShow(
          entries: _threeRelatedRepeatEntries(),
        ),
        isTrue,
      );
      expect(find.byKey(const Key('daily_archive_memory_card')), findsNothing);
    });

    testWidgets('focused watch card is primary capture surface', (tester) async {
      await pumpRecord(tester);

      expect(find.byKey(const Key('daily_archive_memory_card')), findsOneWidget);
      expect(find.text('Did this come back?'), findsOneWidget);
      expect(find.byKey(const Key('daily_archive_memory_record_cta')), findsOneWidget);
      expect(find.byKey(const Key('daily_archive_memory_type_instead_cta')), findsOneWidget);
      expect(find.text('Record moment'), findsNothing);
      expect(find.text('Log pressure moment'), findsNothing);
      expect(find.text(ConsumerUiCopy.recordTitle), findsNothing);
    });

    testWidgets('record CTA uses existing capture flow without duplicate CTAs', (
      tester,
    ) async {
      await pumpRecord(tester);

      expect(find.byKey(const Key('daily_archive_memory_record_cta')), findsOneWidget);
      await tester.tap(find.byKey(const Key('daily_archive_memory_record_cta')));
      await tester.pump();
      expect(find.byKey(const Key('capture_entry_record_cta')), findsNothing);
    });

    testWidgets('view pattern details opens sheet when available', (tester) async {
      await pumpRecord(tester);

      if (find.byKey(const Key('daily_archive_memory_pattern_details_cta')).evaluate().isEmpty) {
        return;
      }

      await tester.tap(find.byKey(const Key('daily_archive_memory_pattern_details_cta')));
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
        weeklyReviewSurface.WeeklyArchiveReviewEngine.shouldShow(
          entries: _fourRelatedRepeatEntries(),
        ),
        isTrue,
      );
      expect(
        LowEvidenceEngine.buildForRecordReady(
          entries: [_genericTestEntry()],
        ),
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
