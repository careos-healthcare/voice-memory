import 'package:archiveme_mobile/features/archive_proof/archive_belief_surface.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/early_archive/helpful_action_appeared_engine.dart';
import 'package:archiveme_mobile/features/pattern_confidence/pattern_confidence_copy.dart';
import 'package:archiveme_mobile/features/pattern_confidence/pattern_confidence_engine.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:archiveme_mobile/features/pattern_lifecycle/pattern_lifecycle_analytics.dart';
import 'package:archiveme_mobile/features/pattern_lifecycle/pattern_lifecycle_copy.dart';
import 'package:archiveme_mobile/features/pattern_lifecycle/pattern_lifecycle_engine.dart';
import 'package:archiveme_mobile/features/pattern_lifecycle/pattern_lifecycle_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_model.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_belief_surface_card.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_lifecycle_badge.dart';
import 'package:archiveme_mobile/widgets/weekly_review/weekly_archive_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _twoRelatedRepeatEntries() => [
  _entry(
    id: 'e1',
    transcript: _strongRepeat,
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
];

List<JournalEntry> _threeRelatedRepeatEntries() => [
  ..._twoRelatedRepeatEntries(),
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

List<JournalEntry> _fourWithDifferentLatestPhrase() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'I checked my calendar before answering when they asked me to take on more work.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) => RepeatReturnCheckRecord(
  entryId: entryId,
  choice: choice,
  entryCountAtCapture: 4,
  createdAt: DateTime(2026, 6, 13),
);

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await ComeBackTomorrowV2Store.resetForTest(null);
    PatternLifecycleAnalytics.resetForTest();
    // AppServices.resetForTest must run first so the prefs-backed reset below
    // writes into this test's fresh sandbox and not the previous test's
    // already-disposed one.
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await WhatChangedV2Store.resetForTest();
  });

  tearDown(() => sandbox.dispose());
  group('PatternLifecycleEngine', () {
    test('2 related entries resolve Forming', () {
      final lifecycle = PatternLifecycleEngine.build(
        entries: _twoRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(lifecycle, isNotNull);
      expect(lifecycle!.state, PatternLifecycleState.forming);
      expect(lifecycle.label, PatternLifecycleCopy.formingLabel);
      expect(lifecycle.contributingEntryIds, ['e1', 'e2']);
    });

    test('3 related entries resolve Repeated', () {
      final lifecycle = PatternLifecycleEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(lifecycle, isNotNull);
      expect(lifecycle!.state, PatternLifecycleState.repeated);
      expect(lifecycle.label, PatternLifecycleCopy.repeatedLabel);
      expect(lifecycle.contributingEntryIds, ['e1', 'e2', 'e3']);
    });

    test('active watch target resolves Watching', () {
      ComeBackTomorrowV2Store.seedForTest(
        const ActiveWatchTarget(
          watchKey: 'said yes again',
          groundedPhrase: 'said yes again',
          createdDateKey: '2026-06-12',
          source: 'second_related_save',
          quietSignalDismissed: true,
        ),
      );
      final lifecycle = PatternLifecycleEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
        now: DateTime(2026, 6, 12, 18),
      );
      expect(lifecycle, isNotNull);
      expect(lifecycle!.state, PatternLifecycleState.watching);
      expect(lifecycle.label, PatternLifecycleCopy.watchingLabel);
    });

    test('different response resolves Changing', () {
      final lifecycle = PatternLifecycleEngine.build(
        entries: _fourWithDifferentLatestPhrase(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(lifecycle, isNotNull);
      expect(lifecycle!.state, PatternLifecycleState.changing);
      expect(lifecycle.label, PatternLifecycleCopy.changingLabel);
    });

    test('helped action resolves Changing', () {
      final entries = [
        ..._threeRelatedRepeatEntries(),
        _entry(
          id: 'e4',
          transcript:
              'I walked outside for ten minutes before replying to the extra ask.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ];
      final lifecycle = PatternLifecycleEngine.build(
        entries: entries,
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
        helpfulActionCapturedMilestone: true,
      );
      final helpful = HelpfulActionAppearedEngine.build(
        entries: entries,
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
        helpfulActionCapturedMilestone: true,
      );
      expect(helpful, isNotNull);
      expect(lifecycle?.state, PatternLifecycleState.changing);
    });

    test('softer answer resolves Softening', () async {
      final entries = _fourRelatedRepeatEntries();
      await WhatChangedV2Store.instance().saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );
      final lifecycle = PatternLifecycleEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(lifecycle, isNotNull);
      expect(lifecycle!.state, PatternLifecycleState.softening);
      expect(lifecycle.label, PatternLifecycleCopy.softeningLabel);
    });

    test('lower urgency resolves Softening', () {
      final entries = [
        ..._fourRelatedRepeatEntries(),
        _entry(
          id: 'e5',
          transcript:
              'Same yes pattern came back but it felt less urgent and easier to stop.',
          createdAt: DateTime(2026, 6, 14, 12),
        ),
      ];
      final lifecycle = PatternLifecycleEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(lifecycle, isNotNull);
      expect(lifecycle!.state, PatternLifecycleState.softening);
    });

    test('quiet signal resolves Quiet', () {
      ComeBackTomorrowV2Store.seedForTest(
        const ActiveWatchTarget(
          watchKey: 'said yes again',
          groundedPhrase: 'said yes again',
          createdDateKey: '2026-06-10',
          source: 'second_related_save',
        ),
      );
      final now = DateTime(2026, 6, 15, 12);
      final entries = [
        _entry(
          id: '1',
          transcript: _strongRepeat,
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: '2',
          transcript: 'A quiet lunch with a friend — nothing about work.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
        _entry(
          id: '3',
          transcript: 'Went for a walk and noticed the weather.',
          createdAt: DateTime(2026, 6, 14, 12),
        ),
      ];
      final lifecycle = PatternLifecycleEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
        now: now,
      );
      expect(lifecycle, isNotNull);
      expect(lifecycle!.state, PatternLifecycleState.quiet);
      expect(lifecycle.label, PatternLifecycleCopy.quietLabel);
    });

    test('priority Softening beats Watching', () async {
      ComeBackTomorrowV2Store.seedForTest(
        const ActiveWatchTarget(
          watchKey: 'said yes again',
          groundedPhrase: 'said yes again',
          createdDateKey: '2026-06-12',
          source: 'second_related_save',
        ),
      );
      final entries = _fourRelatedRepeatEntries();
      await WhatChangedV2Store.instance().saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );
      final lifecycle = PatternLifecycleEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(lifecycle?.state, PatternLifecycleState.softening);
    });

    test('priority Changing beats Repeated', () {
      final lifecycle = PatternLifecycleEngine.build(
        entries: _fourWithDifferentLatestPhrase(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(lifecycle?.state, PatternLifecycleState.changing);
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
          _fourWithDifferentLatestPhrase(),
        ),
        isTrue,
      );
    });

    test('hidden for generic test entries', () {
      expect(
        PatternLifecycleEngine.build(
          entries: [
            _entry(id: 'g1', transcript: 'This is a test to check function'),
            _entry(id: 'g2', transcript: 'This is a second test for pressure'),
          ],
        ),
        isNull,
      );
    });

    test('hidden for pending transcript entries', () {
      expect(
        PatternLifecycleEngine.build(
          entries: [
            JournalEntry(
              id: 'p1',
              createdAt: DateTime(2026, 6, 12),
              transcript: '',
              durationSeconds: 20,
              localAudioPath: '/tmp/p1.m4a',
              reflection: const Reflection(
                mood: 'neutral',
                emotionalIntensity: 0,
                recurringThemes: [],
                exactLanguagePattern: '',
                concreteObservation: '',
                repeatedSignal: '',
              ),
            ),
          ],
        ),
        isNull,
      );
    });

    test('hidden for degraded placeholder transcript', () {
      expect(
        PatternLifecycleEngine.build(
          entries: [_entry(id: 'p1', transcript: _placeholder)],
        ),
        isNull,
      );
    });

    test('no percentages or fake scores in copy', () {
      for (final line in PatternLifecycleCopy.allVisibleStrings()) {
        expect(line, isNot(contains('%')));
        expect(line.toLowerCase(), isNot(contains('score')));
      }
    });

    test('no advice diagnosis solved fixed cured healed language', () {
      final blob = PatternLifecycleCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('diagnos')));
      expect(blob, isNot(contains('solved')));
      expect(blob, isNot(contains('fixed')));
      expect(blob, isNot(contains('cured')));
      expect(blob, isNot(contains('healed')));
      expect(blob, isNot(contains('you always')));
      for (final line in PatternLifecycleCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('lifecycle does not duplicate Pattern Confidence copy', () {
      for (final lifecycleLine in PatternLifecycleCopy.allVisibleStrings()) {
        for (final confidenceLine
            in PatternConfidenceCopy.allVisibleStrings()) {
          if (lifecycleLine == confidenceLine) {
            continue;
          }
          expect(lifecycleLine, isNot(equals(confidenceLine)));
        }
      }
      final confidence = PatternConfidenceEngine.build(
        entries: _twoRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      final lifecycle = PatternLifecycleEngine.build(
        entries: _twoRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(confidence, isNotNull);
      expect(lifecycle, isNotNull);
      expect(confidence!.body, isNot(equals(lifecycle!.body)));
    });
  });

  group('PatternLifecycleBadge', () {
    testWidgets('analytics metadata only', (tester) async {
      final captured = <({String event, Map<String, Object> properties})>[];
      PatternLifecycleAnalytics.captureForTest = (event, properties) =>
          captured.add((event: event, properties: properties));

      const lifecycle = PatternLifecycle(
        state: PatternLifecycleState.watching,
        label: PatternLifecycleCopy.watchingLabel,
        body: PatternLifecycleCopy.watchingBody,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternLifecycleBadge(
              lifecycle: lifecycle,
              entryCount: 3,
              source: 'pattern_detail',
            ),
          ),
        ),
      );
      await tester.pump();

      final seen = captured
          .where((e) => e.event == PatternLifecycleAnalytics.seenEvent)
          .toList();
      expect(seen, isNotEmpty);
      expect(seen.first.properties['lifecycle_state'], 'watching');
      final blob = seen.first.properties.entries
          .map((e) => '${e.key}:${e.value}')
          .join(' ');
      expect(blob.toLowerCase(), isNot(contains('said yes')));
    });

    testWidgets('view evidence is absent without contributing ids', (
      tester,
    ) async {
      const lifecycle = PatternLifecycle(
        state: PatternLifecycleState.watching,
        label: PatternLifecycleCopy.watchingLabel,
        body: PatternLifecycleCopy.watchingBody,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternLifecycleBadge(
              lifecycle: lifecycle,
              entryCount: 3,
              source: 'pattern_detail',
              skipAnalytics: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pattern_lifecycle_view_evidence')),
        findsNothing,
      );
    });

    testWidgets('view evidence fires when contributing ids are present', (
      tester,
    ) async {
      var opened = false;
      final lifecycle = PatternLifecycle(
        state: PatternLifecycleState.repeated,
        label: PatternLifecycleCopy.repeatedLabel,
        body: PatternLifecycleCopy.repeatedBody,
        contributingEntryIds: const ['e1', 'e2', 'e3'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternLifecycleBadge(
              lifecycle: lifecycle,
              entryCount: 3,
              source: 'pattern_detail',
              skipAnalytics: true,
              onViewEvidence: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pump();

      final cta = find.byKey(const Key('pattern_lifecycle_view_evidence'));
      expect(cta, findsOneWidget);
      expect(find.textContaining('View evidence'), findsOneWidget);
      await tester.tap(cta);
      await tester.pump();
      expect(opened, isTrue);
    });
  });

  group('surface integration', () {
    testWidgets('Pattern Detail shows lifecycle row', (tester) async {
      final detail = PatternDetailBuildInput(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      ).buildDetail()!;
      final lifecycle = PatternLifecycleEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternDetailSheet(
              detail: detail,
              buildInput: PatternDetailBuildInput(
                entries: _threeRelatedRepeatEntries(),
                viewingConfirmedRepeatOrTimeline: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(lifecycle, isNotNull);
      expect(
        find.byKey(Key('pattern_lifecycle_badge_${lifecycle!.state.name}')),
        findsOneWidget,
      );
      expect(find.text(lifecycle.lifecycleRowLabel), findsOneWidget);
    });

    testWidgets('Patterns tab shows lifecycle badge', (tester) async {
      const lifecycle = PatternLifecycle(
        state: PatternLifecycleState.repeated,
        label: PatternLifecycleCopy.repeatedLabel,
        body: PatternLifecycleCopy.repeatedBody,
      );
      const surface = ArchiveBeliefSurface(
        shouldShow: true,
        isPreview: false,
        isPrimaryAfterFirstProof: true,
        headline: 'Headline',
        beliefSummary: 'Belief summary',
        evidenceSummary: 'Evidence summary',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveBeliefSurfaceCard(
              surface: surface,
              onRecordNext: () {},
              patternLifecycle: lifecycle,
              entryCount: 3,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pattern_lifecycle_badge_repeated')),
        findsOneWidget,
      );
      expect(find.text('Lifecycle: Repeated'), findsOneWidget);
    });

    testWidgets('Weekly Review shows lifecycle if available', (tester) async {
      const lifecycle = PatternLifecycle(
        state: PatternLifecycleState.repeated,
        label: PatternLifecycleCopy.repeatedLabel,
        body: PatternLifecycleCopy.repeatedBody,
      );
      const review = WeeklyArchiveReviewResult(
        state: WeeklyArchiveReviewState.full,
        title: 'Weekly review',
        subtitle: 'Three moments this week',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: WeeklyArchiveReviewSheet(
              review: review,
              entryCount: 3,
              patternLifecycle: lifecycle,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pattern_lifecycle_badge_repeated')),
        findsOneWidget,
      );
      expect(find.text(PatternLifecycleCopy.repeatedBody), findsOneWidget);
    });
  });
}
