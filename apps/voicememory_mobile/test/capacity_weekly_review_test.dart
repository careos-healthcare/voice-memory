import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_weekly_review_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_weekly_review_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_weekly_review_gates.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_weekly_review_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capacity_weekly_review_card.dart';

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

JournalEntry _capacityEntry(String id) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
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

CapacityDecisionOutcomeRecord _outcome(
  String entryId,
  String outcomeId,
) =>
    CapacityDecisionOutcomeRecord(
      sourceEntryId: entryId,
      outcomeId: outcomeId,
      status: CapacityDecisionOutcomeStatus.answered,
      createdAt: DateTime(2026, 6, 12),
      updatedAt: DateTime(2026, 6, 12),
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

CapacityWeeklyReviewResult _visibleResult() =>
    const CapacityWeeklyReviewEngine().build(
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
      ),
    );

void main() {
  const engine = CapacityWeeklyReviewEngine();

  group('CapacityWeeklyReviewGates', () {
    test('hidden with no real entries', () {
      expect(
        CapacityWeeklyReviewGates.shouldBuildReview(
          const CapacityWeeklyReviewGateInput(
            sampleMode: false,
            realSavedMomentCount: 0,
            capacityEvidenceCount: 0,
            capacityWedgeActive: true,
            capacityMomentCount: 0,
            outcomeOrCostRecordCount: 0,
          ),
        ),
        isFalse,
      );
    });

    test('appears with enough capacity evidence', () {
      expect(
        CapacityWeeklyReviewGates.shouldBuildReview(
          const CapacityWeeklyReviewGateInput(
            sampleMode: false,
            realSavedMomentCount: 3,
            capacityEvidenceCount: 3,
            capacityWedgeActive: true,
            capacityMomentCount: 3,
            outcomeOrCostRecordCount: 0,
          ),
        ),
        isTrue,
      );
    });

    test('appears with enough decision/cost records', () {
      expect(
        CapacityWeeklyReviewGates.shouldBuildReview(
          const CapacityWeeklyReviewGateInput(
            sampleMode: false,
            realSavedMomentCount: 1,
            capacityEvidenceCount: 1,
            capacityWedgeActive: true,
            capacityMomentCount: 1,
            outcomeOrCostRecordCount: 2,
          ),
        ),
        isTrue,
      );
    });

    test('archive home suppresses when pending pull reason/outcome/cost exists', () {
      expect(
        CapacityWeeklyReviewGates.showOnArchiveHome(
          hasReview: true,
          sampleMode: false,
          pendingPullReason: true,
          pendingDecisionOutcome: false,
          pendingCostCheckin: false,
          beforeYesPauseOnHome: false,
        ),
        isFalse,
      );
      expect(
        CapacityWeeklyReviewGates.showOnArchiveHome(
          hasReview: true,
          sampleMode: false,
          pendingPullReason: false,
          pendingDecisionOutcome: true,
          pendingCostCheckin: false,
          beforeYesPauseOnHome: false,
        ),
        isFalse,
      );
      expect(
        CapacityWeeklyReviewGates.showOnArchiveHome(
          hasReview: true,
          sampleMode: false,
          pendingPullReason: false,
          pendingDecisionOutcome: false,
          pendingCostCheckin: true,
          beforeYesPauseOnHome: false,
        ),
        isFalse,
      );
    });
  });

  group('CapacityWeeklyReviewEngine', () {
    test('hidden for sample/demo-only entries', () {
      final result = engine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
      );
      expect(result.hasReview, isFalse);
    });

    test('hidden in ScreenshotMode via sampleMode flag', () {
      final result = engine.build(
        const CapacityWeeklyReviewInput(
          sampleMode: true,
          realSavedMomentCount: 3,
          capacityWedgeActive: true,
          capacityMomentCount: 3,
          capacityEvidenceCount: 3,
          outcomeRecordedCount: 0,
          laterCostRecordedCount: 0,
          hasPatternChangeOutcomes: false,
          allAnsweredOutcomesAreYes: false,
          hasAnsweredOutcomes: false,
          pendingDecisionOutcome: false,
          pendingCostCheckin: false,
          beforeYesPauseOnHome: false,
          pendingPullReasonOnHome: false,
        ),
      );
      expect(result.hasReview, isFalse);
    });

    test('shows Your yes pattern this week', () {
      final result = _visibleResult();
      expect(result.title, 'Your yes pattern this week');
    });

    test('shows Built from N saved moments', () {
      final result = _visibleResult();
      expect(result.evidenceCountLabel, 'Built from 3 saved moments');
    });

    test('shows outcome count safely', () {
      final result = _visibleResult();
      expect(result.outcomeLine, 'You marked 2 outcomes after pausing.');
    });

    test('shows later cost count safely', () {
      final result = _visibleResult();
      expect(result.laterCostLine, 'Later cost recorded on 1 moment.');
    });

    test('shows pattern changed copy when delayed/no outcomes exist', () {
      final entries = [
        _capacityEntry('real_0'),
        _capacityEntry('real_1'),
        _capacityEntry('real_2'),
      ];
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        outcomeRecords: [
          _outcome('real_0', CapacityDecisionOutcomeIds.saidNo),
        ],
      );
      expect(result.whatChanged, CapacityWeeklyReviewCopy.patternMayHaveChanged);
    });

    test('shows pattern repeated copy when all outcomes are said_yes', () {
      final entries = [
        _capacityEntry('real_0'),
        _capacityEntry('real_1'),
        _capacityEntry('real_2'),
      ];
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        outcomeRecords: [
          _outcome('real_0', CapacityDecisionOutcomeIds.saidYes),
          _outcome('real_1', CapacityDecisionOutcomeIds.saidYes),
        ],
      );
      expect(
        result.whatChanged,
        CapacityWeeklyReviewCopy.patternMostlyRepeating,
      );
    });

    test('does not expose transcript text', () {
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('real_0'), _capacityEntry('real_1'), _capacityEntry('real_2')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        outcomeRecords: [
          _outcome('real_0', CapacityDecisionOutcomeIds.delayed),
        ],
        costRecords: [
          CapacityCostRecord(
            sourceEntryId: 'real_0',
            costTypeIds: const [CapacityCostTypeIds.energy],
            status: CapacityCostRecordStatus.answered,
            createdAt: DateTime(2026, 6, 12),
            updatedAt: DateTime(2026, 6, 12),
          ),
        ],
      );
      final visible = [
        result.title,
        result.subtitle,
        result.evidenceCountLabel,
        result.outcomeLine,
        result.laterCostLine,
        result.whatRepeated,
        result.whatChanged,
        result.laterCostSection,
        result.watchNext,
      ].where((line) => line.isNotEmpty);
      for (final line in visible) {
        expect(line.toLowerCase(), isNot(contains(_privateSnippet)));
      }
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy(CapacityWeeklyReviewCopy.allVisibleStrings());
    });
  });

  group('CapacityWeeklyReviewCard widget', () {
    testWidgets('renders weekly review card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityWeeklyReviewCard.test(result: _visibleResult()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Your yes pattern this week'), findsOneWidget);
      expect(find.text('Review this week'), findsOneWidget);
    });

    testWidgets('hidden in sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityWeeklyReviewCard.test(
              result: _visibleResult(),
              sampleMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('capacity_weekly_review_card_hidden')),
        findsOneWidget,
      );
    });
  });

  group('Archive Home priority', () {
    test('weekly review ranks after before-you-say-yes pause', () {
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
          capacityPullReasonVisible: false,
          capacityDecisionOutcomeVisible: false,
          capacityCostLaterCheckinVisible: false,
          beforeYouSayYesPauseVisible: false,
          capacityWeeklyReviewVisible: true,
          capacityBoundaryResponseVisible: false,
          thenVsNowVisible: false,
          archiveCalendarVisible: false,
          reviewRitualVisible: false,
          milestoneShareVisible: false,
        ),
      );
      final ranked = [...plan.primarySections, ...plan.secondarySections];
      expect(ranked, contains(ArchiveHomeSectionId.capacityWeeklyReview));
      expect(
        ranked.indexOf(ArchiveHomeSectionId.beforeYouSayYesPause),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.capacityWeeklyReview)),
      );
    });
  });

  group('Routing', () {
    test('route registered in app router', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/capacity-weekly-review'"));
    });

    test('sensitive route guard includes capacity weekly review', () {
      expect(
        SensitiveRoutes.isSensitiveRoute('/capacity-weekly-review'),
        isTrue,
      );
    });
  });
}
