import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_copy.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_engine.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_models.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_store.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
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

const _forbiddenTone = [
  'always',
  'never',
  'proves',
  'diagnoses',
  'archiveme knows',
  'you are',
];

const _privateSnippet = 'felt pressure at work before saying yes';

JournalEntry _capacityEntry(
  String id, {
  DateTime? createdAt,
  String? transcript,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 15, 12),
  transcript:
      transcript ??
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
}) => CapacityPullReasonRecord(
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

CapacityDecisionOutcomeRecord _outcomeRecord(
  String entryId,
  String outcomeId,
) => CapacityDecisionOutcomeRecord(
  sourceEntryId: entryId,
  outcomeId: outcomeId,
  status: CapacityDecisionOutcomeStatus.answered,
  createdAt: DateTime(2026, 6, 15, 12),
  updatedAt: DateTime(2026, 6, 15, 12),
);

CapacityActivationFitRecord _fitRecord(String responseId) =>
    CapacityActivationFitRecord(
      responseId: responseId,
      source: CapacityActivationFitSource.capacityLoopActivation,
      activationEntryCount: 3,
      status: CapacityActivationFitStatus.answered,
      createdAt: DateTime(2026, 6, 15, 12),
      updatedAt: DateTime(2026, 6, 16, 12),
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
    for (final word in _forbiddenTone) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
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

  group('ArchiveDailyChangeEngine sharpened responses', () {
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

      expect(result.hasFeature, isFalse);
    });

    test('repeated urgency + later cost produces sharper combined copy', () {
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
          _pullReason('real_1', [
            CapacityPullReasonIds.soundedUrgent,
          ], updatedAt: DateTime(2026, 6, 16, 13)),
        ],
        costRecords: [_laterCostRecord('real_0')],
        outcomeRecords: const [],
        boundarySelection: null,
        weeklyReviewAvailable: false,
      );

      expect(
        result.responseType,
        ArchiveDailyChangeResponseType.repeatedPullWithLaterCost,
      );
      expect(
        result.changeLine,
        ArchiveDailyChangeCopy.urgencyWithLaterCostLine,
      );
      expect(result.changeLine, contains('later cost'));
      expect(
        result.alternativeLabel,
        ArchiveDailyChangeCopy.labelDelayBeforeReplying,
      );
      expect(result.alternativeNextMove, ArchiveDailyChangeCopy.altUrgency);
    });

    test(
      'repeated responsibility + said yes produces sharper combined copy',
      () {
        final entries = [
          _capacityEntry('real_0'),
          _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
          _capacityEntry('real_2', createdAt: DateTime(2026, 6, 16, 14)),
        ];
        final result = engine.buildFromJournal(
          entries: entries,
          capacityLoopActive: true,
          capacityCohortActive: false,
          state: ArchiveDailyChangeState.empty,
          pullReasonRecords: [
            _pullReason('real_0', [CapacityPullReasonIds.feltResponsible]),
            _pullReason('real_1', [CapacityPullReasonIds.feltResponsible]),
          ],
          costRecords: const [],
          outcomeRecords: [
            _outcomeRecord('real_0', CapacityDecisionOutcomeIds.saidYes),
          ],
          boundarySelection: null,
          weeklyReviewAvailable: false,
        );

        expect(
          result.responseType,
          ArchiveDailyChangeResponseType.repeatedPullWithSaidYes,
        );
        expect(
          result.changeLine,
          ArchiveDailyChangeCopy.responsibilityWithSaidYesLine,
        );
        expect(
          result.alternativeLabel,
          ArchiveDailyChangeCopy.labelCheckCapacityBeforeAnswering,
        );
        expect(
          result.alternativeNextMove,
          ArchiveDailyChangeCopy.altResponsibility,
        );
      },
    );

    test('delayed/no outcome produces pattern changed copy', () {
      final entries = [
        _capacityEntry('real_0'),
        _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
        _capacityEntry('real_2', createdAt: DateTime(2026, 6, 16, 14)),
      ];
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        state: ArchiveDailyChangeState.empty,
        pullReasonRecords: [
          _pullReason('real_0', [CapacityPullReasonIds.soundedUrgent]),
        ],
        costRecords: const [],
        outcomeRecords: [
          _outcomeRecord('real_0', CapacityDecisionOutcomeIds.delayed),
        ],
        boundarySelection: null,
        weeklyReviewAvailable: false,
      );

      expect(
        result.responseType,
        ArchiveDailyChangeResponseType.patternInterrupted,
      );
      expect(result.changeLine, ArchiveDailyChangeCopy.patternInterruptedLine);
      expect(
        result.alternativeLabel,
        ArchiveDailyChangeCopy.labelDelayBeforeReplying,
      );
      expect(result.alternativeNextMove, ArchiveDailyChangeCopy.altUrgency);
    });

    test('fewer than 3 moments produces still forming copy', () {
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
      );

      expect(
        result.responseType,
        ArchiveDailyChangeResponseType.waitingForNextMoment,
      );
      expect(
        result.changeLine,
        ArchiveDailyChangeCopy.waitingForNextMomentLine,
      );
      expect(
        result.alternativeLabel,
        ArchiveDailyChangeCopy.labelMarkPullFirst,
      );
    });

    test(
      'fit/partly response produces partly fitting copy when new moment added',
      () {
        final entries = [
          _capacityEntry('real_0'),
          _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
        ];
        final result = engine.build(
          ArchiveDailyChangeInput(
            sampleMode: false,
            capacityWedgeActive: true,
            realSavedMomentCount: 2,
            capacityMomentCount: 2,
            capacityEvidenceCount: 2,
            mostCommonPullReasonId: CapacityPullReasonIds.soundedUrgent,
            pullReasonRecordCount: 1,
            state: ArchiveDailyChangeState.empty,
            entries: entries,
            pullReasonRecords: [
              _pullReason('real_0', [CapacityPullReasonIds.soundedUrgent]),
            ],
            costRecords: const [],
            outcomeRecords: const [],
            boundarySelection: null,
            activationFitRecord: _fitRecord(
              CapacityActivationFitResponseIds.partly,
            ),
            weeklyReviewAvailable: false,
          ),
        );

        expect(
          result.responseType,
          ArchiveDailyChangeResponseType.fitPartlyNewMoment,
        );
        expect(
          result.changeLine,
          ArchiveDailyChangeCopy.fitPartlyNewMomentLine,
        );
        expect(result.alternativeLabel, isNotEmpty);
      },
    );

    test('selected boundary response is preferred in alternative', () {
      final entries = [
        _capacityEntry('real_0'),
        _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
        _capacityEntry('real_2', createdAt: DateTime(2026, 6, 16, 14)),
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
          _pullReason('real_0', [CapacityPullReasonIds.feltResponsible]),
          _pullReason('real_1', [CapacityPullReasonIds.feltResponsible]),
        ],
        costRecords: const [],
        outcomeRecords: [
          _outcomeRecord('real_0', CapacityDecisionOutcomeIds.saidYes),
        ],
        boundarySelection: selection,
        weeklyReviewAvailable: false,
      );

      expect(
        result.alternativeNextMove,
        CapacityBoundaryResponseCopy.textForId(
          CapacityBoundaryResponseIds.needPauseBeforeYes,
        ),
      );
      expect(result.alternativeLabel, ArchiveDailyChangeCopy.labelDefaultPause);
    });

    test('no pull reason produces pull is still unclear copy', () {
      final entries = [
        _capacityEntry('real_0'),
        _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
        _capacityEntry('real_2', createdAt: DateTime(2026, 6, 16, 14)),
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

      expect(
        result.responseType,
        ArchiveDailyChangeResponseType.noPullReasonYet,
      );
      expect(result.changeLine, ArchiveDailyChangeCopy.noPullReasonLine);
      expect(result.alternativeLabel, ArchiveDailyChangeCopy.labelMarkPull);
    });

    test('copy safety across visible strings', () {
      _expectNoBannedCopy(ArchiveDailyChangeCopy.allVisibleStrings());
    });
  });

  group('ArchiveDailyChangeCard widget', () {
    testWidgets('shows sharpened label and body', (tester) async {
      const result = ArchiveDailyChangeResult(
        hasFeature: true,
        showOnArchiveHome: true,
        showOnCapacityLoop: true,
        showOnWeeklyReview: false,
        responseType: ArchiveDailyChangeResponseType.repeatedPullWithLaterCost,
        title: ArchiveDailyChangeCopy.title,
        changeLine:
            'Urgency has appeared more than once, and at least one yes moment had a later cost.',
        repeatedLine: 'What repeated: urgency.',
        alternativeLabel: ArchiveDailyChangeCopy.labelDelayAnswer,
        alternativeNextMove: ArchiveDailyChangeCopy.bodyDelayBeforeReplying,
        watchNextLine: ArchiveDailyChangeCopy.watchUrgentResponsible,
        alternativeSectionTitle: ArchiveDailyChangeCopy.alternativeSectionTitle,
        loopSectionTitle: ArchiveDailyChangeCopy.loopSectionTitle,
        weeklySectionTitle: ArchiveDailyChangeCopy.weeklySectionTitle,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ArchiveDailyChangeCard(result: result)),
        ),
      );

      expect(find.text('Your archive changed today'), findsOneWidget);
      expect(
        find.text(ArchiveDailyChangeCopy.labelDelayAnswer),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveDailyChangeCopy.bodyDelayBeforeReplying),
        findsOneWidget,
      );
    });

    testWidgets('does not render private transcript text', (tester) async {
      const result = ArchiveDailyChangeResult(
        hasFeature: true,
        showOnArchiveHome: true,
        showOnCapacityLoop: true,
        showOnWeeklyReview: false,
        responseType: ArchiveDailyChangeResponseType.stillForming,
        title: ArchiveDailyChangeCopy.title,
        changeLine: ArchiveDailyChangeCopy.stillFormingLine,
        repeatedLine: '',
        alternativeLabel: ArchiveDailyChangeCopy.labelSaveOneMore,
        alternativeNextMove: ArchiveDailyChangeCopy.bodyOneMoreMoment,
        watchNextLine: ArchiveDailyChangeCopy.watchHardToDelay,
        alternativeSectionTitle: ArchiveDailyChangeCopy.alternativeSectionTitle,
        loopSectionTitle: ArchiveDailyChangeCopy.loopSectionTitle,
        weeklySectionTitle: ArchiveDailyChangeCopy.weeklySectionTitle,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ArchiveDailyChangeCard(result: result)),
        ),
      );

      expect(find.textContaining(_privateSnippet), findsNothing);
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
      expect(
        plan.primarySections,
        contains(ArchiveHomeSectionId.archiveDailyChange),
      );
      expect(plan.primarySections.length, lessThanOrEqualTo(4));
    });
  });

  group('ArchiveDailyChangeStore', () {
    test('persists lastSeenAt and dismissedAt only', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);
      final seenAt = DateTime(2026, 6, 16, 12).toUtc();
      await ArchiveDailyChangeStore.instance().markSeen(seenAt);
      expect(ArchiveDailyChangeStore.cached.lastSeenAt, seenAt);

      final dismissedAt = DateTime(2026, 6, 16, 13).toUtc();
      await ArchiveDailyChangeStore.instance().dismiss(dismissedAt);
      expect(ArchiveDailyChangeStore.cached.dismissedAt, dismissedAt);
    });
  });
}
