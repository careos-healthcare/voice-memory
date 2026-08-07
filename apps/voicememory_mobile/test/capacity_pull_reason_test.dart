import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_weekly_review_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_weekly_review_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_weekly_review_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capacity_pull_reason_card.dart';

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

JournalEntry _capacityEntry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      transcript ??
      'I $_privateSnippet again and said yes with no capacity left.',
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

CapacityPullReasonRecord _answeredPullReason(
  String entryId,
  List<String> reasonIds,
) => CapacityPullReasonRecord(
  sourceEntryId: entryId,
  reasonIds: reasonIds,
  status: CapacityPullReasonStatus.answered,
  createdAt: DateTime(2026, 6, 12),
  updatedAt: DateTime(2026, 6, 12),
);

CapacityPullReasonRecord _skippedPullReason(String entryId) =>
    CapacityPullReasonRecord(
      sourceEntryId: entryId,
      reasonIds: const [],
      status: CapacityPullReasonStatus.skipped,
      createdAt: DateTime(2026, 6, 12),
      updatedAt: DateTime(2026, 6, 12),
    );

CapacityPullReasonResult _visibleResult({String pendingId = 'real_0'}) =>
    CapacityPullReasonResult(
      hasCard: true,
      showOnArchiveHome: true,
      title: CapacityPullReasonCopy.cardTitle,
      body: CapacityPullReasonCopy.cardBody,
      primaryCtaLabel: CapacityPullReasonCopy.saveReasonCta,
      secondaryCtaLabel: CapacityPullReasonCopy.skipCta,
      pendingEntryId: pendingId,
      recordedReasonCount: 0,
    );

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

Future<void> _resetStore(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_capacity_pull_reason_journal_$stamp.json',
    prefsPath: '/tmp/vm_capacity_pull_reason_prefs_$stamp.json',
  );
  await CapacityPullReasonStore.resetForTest();
}

void main() {
  const pullEngine = CapacityPullReasonEngine();
  const loopEngine = CapacityLoopEngine();
  const outcomeEngine = CapacityDecisionOutcomeEngine();

  group('CapacityPullReasonEngine', () {
    test('hidden with no real entries', () {
      final result = pullEngine.buildFromJournal(
        entries: const [],
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('hidden for sample/demo-only entries', () {
      final result = pullEngine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('appears for capacity-yes user after a real yes moment', () {
      final entries = [_capacityEntry('real_0')];
      final result = pullEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isTrue);
      expect(result.title, 'What pulled you toward yes?');
      expect(result.pendingEntryId, 'real_0');
    });

    test('hidden in ScreenshotMode', () {
      final result = pullEngine.build(
        CapacityPullReasonInput(
          realSavedMomentCount: 1,
          capacityEvidenceCount: 1,
          capacityWedgeActive: true,
          sampleMode: true,
          records: const [],
          pendingEntryId: 'real_0',
        ),
      );
      expect(result.hasCard, isFalse);
    });

    test('generic users do not see reason card too early', () {
      final result = pullEngine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: false,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('hidden when all moments already have records', () {
      final result = pullEngine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: [_skippedPullReason('real_0')],
      );
      expect(result.hasCard, isFalse);
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy(CapacityPullReasonCopy.allVisibleStrings());
    });
  });

  group('CapacityPullReasonStore', () {
    test('stores selected fixed reason IDs locally', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityPullReasonStore.instance().saveAnswered(
        sourceEntryId: 'entry_a',
        reasonIds: [
          CapacityPullReasonIds.soundedUrgent,
          CapacityPullReasonIds.feltResponsible,
        ],
      );

      final records = await CapacityPullReasonStore.instance().loadAll();
      expect(records, hasLength(1));
      expect(records.first.reasonIds, [
        CapacityPullReasonIds.soundedUrgent,
        CapacityPullReasonIds.feltResponsible,
      ]);
    });

    test('reason links to sourceEntryId', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityPullReasonStore.instance().saveAnswered(
        sourceEntryId: 'entry_b',
        reasonIds: [CapacityPullReasonIds.squeezeItIn],
      );

      final record = CapacityPullReasonStore.instance().cachedRecordForEntry(
        'entry_b',
      );
      expect(record?.sourceEntryId, 'entry_b');
    });

    test('reason record does not store transcript text', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityPullReasonStore.instance().saveAnswered(
        sourceEntryId: 'entry_c',
        reasonIds: [CapacityPullReasonIds.answeredTooQuickly],
      );

      final json = (await CapacityPullReasonStore.instance().loadAll()).first
          .toJson();
      expect(json.keys, containsAll(['sourceEntryId', 'reasonIds', 'status']));
      expect(json.toString(), isNot(contains(_privateSnippet)));
      expect(json.toString(), isNot(contains('transcript')));
    });

    test('skip/dismiss works', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityPullReasonStore.instance().saveSkipped(
        sourceEntryId: 'entry_d',
      );
      final record = CapacityPullReasonStore.instance().cachedRecordForEntry(
        'entry_d',
      );
      expect(record?.status, CapacityPullReasonStatus.skipped);
    });
  });

  group('CapacityLoopEngine pull reason integration', () {
    test('loop card shows safe most-common pull', () {
      CapacityPullReasonStore.seedForTest([
        _answeredPullReason('real_0', [CapacityPullReasonIds.soundedUrgent]),
        _answeredPullReason('real_1', [CapacityPullReasonIds.soundedUrgent]),
        _answeredPullReason('real_2', [CapacityPullReasonIds.feltResponsible]),
      ]);

      final result = loopEngine.buildFromJournal(
        entries: [
          _capacityEntry('real_0'),
          _capacityEntry('real_1'),
          _capacityEntry('real_2'),
        ],
        capacityLoopActive: true,
        capacityCohortActive: false,
        pullReasonRecords: CapacityPullReasonStore.cached,
      );

      expect(
        result.pullReasonSummary,
        contains('Most common pull: It sounded urgent'),
      );
      expect(
        result.pullReasonSummary.toLowerCase(),
        isNot(contains(_privateSnippet)),
      );
    });

    test('loop strengthen prompt when no reasons recorded', () {
      CapacityPullReasonStore.seedForTest(const []);

      final result = loopEngine.buildFromJournal(
        entries: [_capacityEntry('real_0'), _capacityEntry('real_1')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        pullReasonRecords: const [],
      );

      expect(
        result.pullReasonSummary,
        contains(CapacityPullReasonCopy.loopStrengthenPrompt),
      );
    });
  });

  group('CapacityWeeklyReviewEngine pull reason integration', () {
    test('shows safe pull reason section', () {
      CapacityPullReasonStore.seedForTest([
        _answeredPullReason('real_0', [CapacityPullReasonIds.soundedUrgent]),
        _answeredPullReason('real_1', [CapacityPullReasonIds.soundedUrgent]),
      ]);

      final result = const CapacityWeeklyReviewEngine().build(
        CapacityWeeklyReviewInput(
          sampleMode: false,
          realSavedMomentCount: 3,
          capacityWedgeActive: true,
          capacityMomentCount: 3,
          capacityEvidenceCount: 3,
          outcomeRecordedCount: 2,
          laterCostRecordedCount: 1,
          hasPatternChangeOutcomes: true,
          allAnsweredOutcomesAreYes: false,
          hasAnsweredOutcomes: true,
          pendingDecisionOutcome: false,
          pendingCostCheckin: false,
          beforeYesPauseOnHome: false,
          pendingPullReasonOnHome: false,
          pullReasonSummary: CapacityPullReasonEngine.weeklyPullSummary(
            CapacityPullReasonStore.cached,
          ),
        ),
      );

      expect(result.whatPulledYouIn, 'This week, urgency appeared most often.');
      expect(
        result.whatPulledYouIn.toLowerCase(),
        isNot(contains(_privateSnippet)),
      );
    });
  });

  group('CapacityBoundaryResponseEngine urgent pull note', () {
    test('shows cautious urgency fit note when pull is urgency', () {
      final result = const CapacityBoundaryResponseEngine().build(
        CapacityBoundaryResponseInput(
          sampleMode: false,
          realSavedMomentCount: 3,
          capacityWedgeActive: true,
          capacityMomentCount: 3,
          capacityEvidenceCount: 3,
          outcomeOrCostRecordCount: 2,
          pendingDecisionOutcome: false,
          pendingCostCheckin: false,
          beforeYesPauseOnHome: false,
          weeklyReviewOnHome: false,
          pendingPullReasonOnHome: false,
          mostCommonPullReasonId: CapacityPullReasonIds.soundedUrgent,
        ),
      );

      expect(
        result.recommendedResponseNote,
        CapacityPullReasonCopy.boundaryUrgentFitNote,
      );
    });
  });

  group('Decision outcome chain', () {
    test('decision outcome waits for pull reason', () {
      CapacityPullReasonStore.seedForTest(const []);
      final entries = [_capacityEntry('real_0')];
      final withoutPull = outcomeEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(withoutPull.hasCard, isFalse);

      CapacityPullReasonStore.seedForTest([_skippedPullReason('real_0')]);
      final withPull = outcomeEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(withPull.hasCard, isTrue);
    });
  });

  group('CapacityPullReasonCard widget', () {
    testWidgets('renders pull reason card copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityPullReasonCard.test(
              result: _visibleResult(),
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('What pulled you toward yes?'), findsOneWidget);
      expect(find.text('Save reason'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
      expect(find.textContaining(_privateSnippet), findsNothing);
    });

    testWidgets('hidden in sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityPullReasonCard.test(
              result: _visibleResult(),
              onSaved: () {},
              sampleMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('capacity_pull_reason_card_hidden')),
        findsOneWidget,
      );
    });
  });

  group('Archive Home priority', () {
    test('pull reason ranks before decision outcome', () {
      const priorityEngine = ArchiveHomePriorityEngine();
      final plan = priorityEngine.build(
        ArchiveHomePriorityInput(
          savedEntryCount: 4,
          usableEvidenceCount: 4,
          depthLevel: ArchiveDepthLevel.notStarted,
          returnChangesAvailable: false,
          weeklyReviewAvailable: false,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: false,
          firstWeekPathVisible: false,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          capacityLoopVisible: true,
          capacityThreeMomentActivationVisible: false,
          capacityPullReasonVisible: true,
          capacityDecisionOutcomeVisible: true,
          capacityCostLaterCheckinVisible: true,
          capacityActivationFitVisible: false,
          beforeYouSayYesPauseVisible: false,
          capacityWeeklyReviewVisible: false,
          capacityBoundaryResponseVisible: false,
          thenVsNowVisible: false,
          archiveCalendarVisible: false,
          reviewRitualVisible: false,
          milestoneShareVisible: false,
        ),
      );
      final ranked = [...plan.primarySections, ...plan.secondarySections];
      expect(
        ranked.indexOf(ArchiveHomeSectionId.capacityPullReason),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.capacityDecisionOutcome)),
      );
      expect(
        ranked.indexOf(ArchiveHomeSectionId.capacityDecisionOutcome),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.capacityCostLaterCheckin)),
      );
    });
  });

  group('Copy safety across related surfaces', () {
    test('no banned language in loop and weekly copy', () {
      _expectNoBannedCopy([
        CapacityLoopCopy.shareCopy,
        CapacityWeeklyReviewCopy.allVisibleStrings().join(' '),
        CapacityBoundaryResponseCopy.allVisibleStrings().join(' '),
      ]);
    });
  });
}
