import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_copy.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_engine.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_models.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_store.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_daily_change_card.dart';

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
  'fake stats',
  'testimonial',
];

const _privateSnippet = 'felt pressure at work before saying yes';

JournalEntry _capacityEntry(
  String id, {
  DateTime? createdAt,
  String? transcript,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 15, 12),
      transcript: transcript ??
          'I said yes again with no capacity left even though I was tired today.',
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

CapacityPullReasonRecord _pullReason(
  String entryId,
  List<String> reasonIds, {
  DateTime? updatedAt,
}) =>
    CapacityPullReasonRecord(
      sourceEntryId: entryId,
      reasonIds: reasonIds,
      status: CapacityPullReasonStatus.answered,
      createdAt: updatedAt ?? DateTime(2026, 6, 15, 12),
      updatedAt: updatedAt ?? DateTime(2026, 6, 15, 12),
    );

CapacityCostRecord _laterCostRecord(String entryId, {DateTime? updatedAt}) =>
    CapacityCostRecord(
      sourceEntryId: entryId,
      costTypeIds: const [CapacityCostTypeIds.energy],
      status: CapacityCostRecordStatus.answered,
      createdAt: updatedAt ?? DateTime(2026, 6, 15, 12),
      updatedAt: updatedAt ?? DateTime(2026, 6, 15, 12),
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
    expect(lower, isNot(contains(_privateSnippet)));
  }
}

Future<void> _resetStore(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_archive_daily_change_journal_$stamp.json',
    prefsPath: '/tmp/vm_archive_daily_change_prefs_$stamp.json',
  );
  await ArchiveDailyChangeStore.resetForTest();
}

void main() {
  const engine = ArchiveDailyChangeEngine();

  group('ArchiveDailyChangeEngine', () {
    test('hidden for sample-only entries', () {
      final result = engine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState.empty,
        pullReasonRecords: const [],
        costRecords: const [],
        outcomeRecords: const [],
        boundarySelection: null,
        weeklyReviewAvailable: false,
      );

      expect(result.hasFeature, isFalse);
    });

    test('hidden in sample mode', () {
      final entries = [_capacityEntry('real_0')];
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState.empty,
        pullReasonRecords: const [],
        costRecords: const [],
        outcomeRecords: const [],
        boundarySelection: null,
        weeklyReviewAvailable: false,
        sampleMode: true,
      );

      expect(result.hasFeature, isFalse);
    });

    test('hidden when no changes since last seen', () {
      final entries = [_capacityEntry('real_0')];
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState(
          lastSeenAt: DateTime(2026, 6, 16, 12).toUtc(),
        ),
        pullReasonRecords: const [],
        costRecords: const [],
        outcomeRecords: const [],
        boundarySelection: null,
        weeklyReviewAvailable: false,
      );

      expect(result.hasFeature, isFalse);
    });

    test('shows title and change line after new yes moment', () {
      final entries = [
        _capacityEntry(
          'real_0',
          createdAt: DateTime(2026, 6, 16, 13),
        ),
      ];
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState.empty,
        pullReasonRecords: const [],
        costRecords: const [],
        outcomeRecords: const [],
        boundarySelection: null,
        weeklyReviewAvailable: false,
      );

      expect(result.title, 'Your archive changed today');
      expect(result.changeLine, ArchiveDailyChangeCopy.changeNewYesMoment);
      expect(result.showOnArchiveHome, isTrue);
    });

    test('shows urgency-based alternative when urgency is most common pull', () {
      final entries = [
        _capacityEntry('real_0'),
        _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
      ];
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState.empty,
        pullReasonRecords: [
          _pullReason('real_0', [CapacityPullReasonIds.soundedUrgent]),
          _pullReason(
            'real_1',
            [CapacityPullReasonIds.soundedUrgent],
            updatedAt: DateTime(2026, 6, 16, 13),
          ),
        ],
        costRecords: const [],
        outcomeRecords: const [],
        boundarySelection: null,
        weeklyReviewAvailable: false,
      );

      expect(result.alternativeNextMove, ArchiveDailyChangeCopy.alternativeUrgency);
    });

    test('shows responsibility-based alternative when responsibility is most common pull', () {
      final entries = [
        _capacityEntry('real_0'),
        _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
      ];
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState.empty,
        pullReasonRecords: [
          _pullReason('real_0', [CapacityPullReasonIds.feltResponsible]),
          _pullReason(
            'real_1',
            [CapacityPullReasonIds.feltResponsible],
            updatedAt: DateTime(2026, 6, 16, 13),
          ),
        ],
        costRecords: const [],
        outcomeRecords: const [],
        boundarySelection: null,
        weeklyReviewAvailable: false,
      );

      expect(
        result.alternativeNextMove,
        ArchiveDailyChangeCopy.alternativeResponsibility,
      );
    });

    test('prefers selected boundary response when available', () {
      final entries = [
        _capacityEntry('real_0'),
        _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
      ];
      final selection = CapacityBoundaryResponseSelection(
        responseId: CapacityBoundaryResponseIds.needPauseBeforeYes,
        selectedAt: DateTime(2026, 6, 16, 13),
      );
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState.empty,
        pullReasonRecords: [
          _pullReason('real_0', [CapacityPullReasonIds.soundedUrgent]),
        ],
        costRecords: const [],
        outcomeRecords: const [],
        boundarySelection: selection,
        weeklyReviewAvailable: false,
      );

      expect(
        result.alternativeNextMove,
        CapacityBoundaryResponseCopy.textForId(
          CapacityBoundaryResponseIds.needPauseBeforeYes,
        ),
      );
    });

    test('shows later cost change line when cost recorded since last seen', () {
      final lastSeen = DateTime(2026, 6, 15, 10).toUtc();
      final entries = [_capacityEntry('real_0')];
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState(lastSeenAt: lastSeen),
        pullReasonRecords: const [],
        costRecords: [
          _laterCostRecord(
            'real_0',
            updatedAt: DateTime(2026, 6, 16, 12),
          ),
        ],
        outcomeRecords: const [],
        boundarySelection: null,
        weeklyReviewAvailable: false,
      );

      expect(result.changeLine, ArchiveDailyChangeCopy.changeLaterCost);
    });

    test('copy safety across visible strings', () {
      _expectNoBannedCopy(ArchiveDailyChangeCopy.allVisibleStrings());
    });
  });

  group('ArchiveDailyChangeCard widget', () {
    testWidgets('shows title and change line', (tester) async {
      const result = ArchiveDailyChangeResult(
        hasFeature: true,
        showOnArchiveHome: true,
        showOnCapacityLoop: true,
        showOnWeeklyReview: false,
        title: ArchiveDailyChangeCopy.title,
        changeLine: ArchiveDailyChangeCopy.changeNewYesMoment,
        repeatedLine: 'What repeated: urgency.',
        alternativeNextMove: ArchiveDailyChangeCopy.alternativeUrgency,
        watchNextLine: ArchiveDailyChangeCopy.watchUrgentResponsible,
        alternativeSectionTitle: ArchiveDailyChangeCopy.alternativeSectionTitle,
        loopSectionTitle: ArchiveDailyChangeCopy.loopSectionTitle,
        weeklySectionTitle: ArchiveDailyChangeCopy.weeklySectionTitle,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveDailyChangeCard(result: result),
          ),
        ),
      );

      expect(find.text('Your archive changed today'), findsOneWidget);
      expect(find.text(ArchiveDailyChangeCopy.changeNewYesMoment), findsOneWidget);
      expect(find.text(ArchiveDailyChangeCopy.alternativeUrgency), findsOneWidget);
    });

    testWidgets('hidden in screenshot mode flag path via sampleMode engine', (
      tester,
    ) async {
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState.empty,
        pullReasonRecords: const [],
        costRecords: const [],
        outcomeRecords: const [],
        boundarySelection: null,
        weeklyReviewAvailable: false,
        sampleMode: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveDailyChangeCard(result: result),
          ),
        ),
      );

      expect(find.byKey(const Key('archive_daily_change_card_hidden')), findsOneWidget);
    });

    testWidgets('does not render private transcript text', (tester) async {
      const result = ArchiveDailyChangeResult(
        hasFeature: true,
        showOnArchiveHome: true,
        showOnCapacityLoop: true,
        showOnWeeklyReview: false,
        title: ArchiveDailyChangeCopy.title,
        changeLine: ArchiveDailyChangeCopy.changeNewYesMoment,
        repeatedLine: '',
        alternativeNextMove: ArchiveDailyChangeCopy.alternativeNoPullReason,
        watchNextLine: ArchiveDailyChangeCopy.watchHardToDelay,
        alternativeSectionTitle: ArchiveDailyChangeCopy.alternativeSectionTitle,
        loopSectionTitle: ArchiveDailyChangeCopy.loopSectionTitle,
        weeklySectionTitle: ArchiveDailyChangeCopy.weeklySectionTitle,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveDailyChangeCard(result: result),
          ),
        ),
      );

      expect(find.textContaining(_privateSnippet), findsNothing);
    });
  });

  group('ArchiveDailyChangeSection', () {
    testWidgets('shows capacity loop daily change section safely', (
      tester,
    ) async {
      const result = ArchiveDailyChangeResult(
        hasFeature: true,
        showOnArchiveHome: true,
        showOnCapacityLoop: true,
        showOnWeeklyReview: false,
        title: ArchiveDailyChangeCopy.title,
        changeLine: ArchiveDailyChangeCopy.changeUrgencyPull,
        repeatedLine: 'What repeated: urgency.',
        alternativeNextMove: ArchiveDailyChangeCopy.alternativeUrgency,
        watchNextLine: ArchiveDailyChangeCopy.watchUrgentResponsible,
        alternativeSectionTitle: ArchiveDailyChangeCopy.alternativeSectionTitle,
        loopSectionTitle: ArchiveDailyChangeCopy.loopSectionTitle,
        weeklySectionTitle: ArchiveDailyChangeCopy.weeklySectionTitle,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ArchiveDailyChangeSection(result: result),
          ),
        ),
      );

      expect(find.text(ArchiveDailyChangeCopy.loopSectionTitle), findsOneWidget);
      expect(find.text(ArchiveDailyChangeCopy.changeUrgencyPull), findsOneWidget);
      expect(find.text(ArchiveDailyChangeCopy.alternativeUrgency), findsOneWidget);
    });
  });

  group('Archive Home priority', () {
    test('primary area caps at summary plus three cards with daily change', () {
      const priorityEngine = ArchiveHomePriorityEngine();
      final plan = priorityEngine.build(
        ArchiveHomePriorityInput(
          savedEntryCount: 5,
          usableEvidenceCount: 5,
          depthLevel: ArchiveDepthLevel.startingToCompare,
          returnChangesAvailable: false,
          weeklyReviewAvailable: false,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: false,
          archiveDailyChangeVisible: true,
          firstWeekPathVisible: false,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          capacityThreeMomentActivationVisible: true,
          capacityLoopVisible: true,
          capacityPullReasonVisible: true,
          capacityDecisionOutcomeVisible: true,
          capacityCostLaterCheckinVisible: true,
          capacityActivationFitVisible: true,
          beforeYouSayYesPauseVisible: true,
          capacityWeeklyReviewVisible: true,
          capacityBoundaryResponseVisible: true,
          thenVsNowVisible: true,
          archiveCalendarVisible: true,
          reviewRitualVisible: true,
          milestoneShareVisible: true,
        ),
      );

      expect(plan.primarySections.first, ArchiveHomeSectionId.archiveSummary);
      expect(plan.primarySections, contains(ArchiveHomeSectionId.archiveDailyChange));
      expect(plan.primarySections.length, lessThanOrEqualTo(4));
    });
  });

  group('ArchiveDailyChangeStore', () {
    setUp(() async {
      await _resetStore('store');
    });

    test('persists lastSeenAt and dismissedAt only', () async {
      final seenAt = DateTime(2026, 6, 16, 12).toUtc();
      await ArchiveDailyChangeStore.instance().markSeen(seenAt);
      expect(ArchiveDailyChangeStore.cached.lastSeenAt, seenAt);

      final dismissedAt = DateTime(2026, 6, 16, 13).toUtc();
      await ArchiveDailyChangeStore.instance().dismiss(dismissedAt);
      expect(ArchiveDailyChangeStore.cached.dismissedAt, dismissedAt);
    });
  });
}
