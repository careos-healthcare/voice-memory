import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/before_yes_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/before_yes_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_engine.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/before_you_say_yes_card.dart';

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
      transcript: transcript ??
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

BeforeYesPauseResult _visibleResult() => const BeforeYesPauseEngine().build(
      const BeforeYesPauseInput(
        capacityWedgeActive: true,
        sampleMode: false,
        realSavedMomentCount: 3,
        capacityEvidenceCount: 3,
        capacityLoopHasCard: true,
        costLaterCheckinVisible: false,
        recordedCostCount: 0,
      ),
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

void main() {
  const engine = BeforeYesPauseEngine();
  const loopEngine = CapacityLoopEngine();

  group('BeforeYesPauseEngine', () {
    test('hidden for generic users', () {
      final result = engine.build(
        const BeforeYesPauseInput(
          capacityWedgeActive: false,
          sampleMode: false,
          realSavedMomentCount: 5,
          capacityEvidenceCount: 5,
          capacityLoopHasCard: true,
          costLaterCheckinVisible: false,
          recordedCostCount: 2,
        ),
      );
      expect(result.showOnRecord, isFalse);
      expect(result.showOnArchiveHome, isFalse);
      expect(result.showOnCapacityLoop, isFalse);
    });

    test('visible for capacity-yes active loop/cohort on record', () {
      final result = engine.build(
        const BeforeYesPauseInput(
          capacityWedgeActive: true,
          sampleMode: false,
          realSavedMomentCount: 1,
          capacityEvidenceCount: 1,
          capacityLoopHasCard: false,
          costLaterCheckinVisible: false,
          recordedCostCount: 0,
        ),
      );
      expect(result.showOnRecord, isTrue);
    });

    test('archive home hidden when cost later check-in is stronger action', () {
      final result = engine.build(
        const BeforeYesPauseInput(
          capacityWedgeActive: true,
          sampleMode: false,
          realSavedMomentCount: 3,
          capacityEvidenceCount: 3,
          capacityLoopHasCard: true,
          costLaterCheckinVisible: true,
          recordedCostCount: 1,
        ),
      );
      expect(result.showOnArchiveHome, isFalse);
      expect(result.showOnRecord, isTrue);
    });

    test('archive home hidden during early wedge activation', () {
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('real_0'), _capacityEntry('real_1')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        capacityLoopHasCard: true,
        costLaterCheckinVisible: false,
      );
      expect(result.showOnArchiveHome, isFalse);
      expect(result.showOnCapacityLoop, isTrue);
    });

    test('archive home visible with loop/cost evidence after 3 moments', () {
      final result = engine.buildFromJournal(
        entries: [
          _capacityEntry('real_0'),
          _capacityEntry('real_1'),
          _capacityEntry('real_2'),
        ],
        capacityLoopActive: true,
        capacityCohortActive: false,
        capacityLoopHasCard: true,
        costLaterCheckinVisible: false,
      );
      expect(result.showOnArchiveHome, isTrue);
      expect(result.showOnCapacityLoop, isTrue);
    });

    test('hidden for sample/demo-only entries on archive home', () {
      final loop = loopEngine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
        costRecords: const [],
      );
      final result = engine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
        capacityLoopHasCard: loop.hasCard,
        costLaterCheckinVisible: false,
        sampleMode: true,
      );
      expect(result.showOnArchiveHome, isFalse);
      expect(result.showOnRecord, isFalse);
    });

    test('prompt includes Before label', () {
      final result = _visibleResult();
      expect(result.title, 'Before');
      expect(result.recordPrompt, contains('about to agree'));
    });

    test('CTA includes Pause before yes', () {
      final result = _visibleResult();
      expect(result.pauseCtaLabel, 'Pause before yes');
    });

    test('Capacity Loop section includes Before next yes', () {
      final result = _visibleResult();
      expect(result.loopSectionTitle, 'Before next yes');
      expect(result.loopSectionBody, contains('pull to agree'));
    });

    test('record handoff uses capacity-specific prompt', () {
      final route = BeforeYesCopy.recordRouteWithPrompt(BeforeYesCopy.recordPrompt);
      expect(route, contains(Uri.encodeComponent(BeforeYesCopy.recordPrompt)));
      expect(BeforeYesCopy.recordPrompt, contains('hard to pause'));
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy([
        BeforeYesCopy.title,
        BeforeYesCopy.body,
        BeforeYesCopy.pauseCta,
        BeforeYesCopy.alreadyYesCta,
        BeforeYesCopy.recordPrompt,
        BeforeYesCopy.loopSectionTitle,
        BeforeYesCopy.loopSectionBody,
      ]);
    });
  });

  group('BeforeYouSayYesCard widget', () {
    testWidgets('shows title and pause CTA for wedge users', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BeforeYouSayYesCard.test(
              result: _visibleResult(),
              onPauseBeforeYes: () {},
              onAlreadySaidYes: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Before'), findsOneWidget);
      expect(find.text('Pause before yes'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.textContaining(_privateSnippet), findsNothing);
    });

    testWidgets('hidden in sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BeforeYouSayYesCard.test(
              result: _visibleResult(),
              onPauseBeforeYes: () {},
              onAlreadySaidYes: () {},
              sampleMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('before_you_say_yes_card_hidden')), findsOneWidget);
    });

    testWidgets('compact archive card hides inline prompt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BeforeYouSayYesCard.test(
              compact: true,
              result: _visibleResult(),
              onPauseBeforeYes: () {},
              onAlreadySaidYes: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('before_you_say_yes_card_prompt')), findsNothing);
    });
  });

  group('Archive Home priority', () {
    test('does not overload when cost later check-in is visible', () {
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
      expect(ranked, contains(ArchiveHomeSectionId.capacityCostLaterCheckin));
      expect(ranked, isNot(contains(ArchiveHomeSectionId.beforeYouSayYesPause)));
    });

    test('before yes ranks after cost check-in when both eligible', () {
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
          capacityActivationFitVisible: false,
          beforeYouSayYesPauseVisible: true,
          capacityWeeklyReviewVisible: false,
          capacityBoundaryResponseVisible: false,
          thenVsNowVisible: false,
          archiveCalendarVisible: false,
          reviewRitualVisible: false,
          milestoneShareVisible: false,
        ),
      );
      final ranked = [...plan.primarySections, ...plan.secondarySections];
      expect(ranked, contains(ArchiveHomeSectionId.beforeYouSayYesPause));
      expect(
        ranked.indexOf(ArchiveHomeSectionId.capacityLoop),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.beforeYouSayYesPause)),
      );
    });
  });
}
