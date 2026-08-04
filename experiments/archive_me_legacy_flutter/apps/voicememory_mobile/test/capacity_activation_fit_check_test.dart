import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_store.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capacity_activation_fit_card.dart';

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

List<JournalEntry> _entries(int count) =>
    List.generate(count, (i) => _capacityEntry('real_$i'));

CapacityActivationFitResult _pendingResult({int count = 3}) =>
    CapacityActivationFitResult(
      hasCard: true,
      showOnArchiveHome: true,
      showOnCapacityLoop: true,
      showAnsweredLineOnCapacityLoop: false,
      title: CapacityActivationFitCopy.cardTitle,
      body: CapacityActivationFitCopy.cardBody,
      primaryCtaLabel: CapacityActivationFitCopy.saveFeedbackCta,
      secondaryCtaLabel: CapacityActivationFitCopy.skipCta,
      answeredSummaryLine: '',
      activationEntryCount: count,
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

ArchiveHomePriorityInput _priorityInput({
  int savedEntryCount = 3,
  bool capacityCostLaterCheckinVisible = false,
  bool capacityActivationFitVisible = false,
  bool beforeYouSayYesPauseVisible = false,
  bool capacityWeeklyReviewVisible = false,
}) => ArchiveHomePriorityInput(
  savedEntryCount: savedEntryCount,
  usableEvidenceCount: savedEntryCount,
  depthLevel: ArchiveDepthLevel.notStarted,
  returnChangesAvailable: false,
  weeklyReviewAvailable: false,
  sampleMode: false,
  proPreviewPromoVisible: false,
  showEmptySample: false,
  firstWeekPathVisible: savedEntryCount < 7,
  dailyArchiveExerciseVisible: true,
  archiveClarityProgressVisible: true,
  capacityThreeMomentActivationVisible: false,
  capacityLoopVisible: false,
  capacityPullReasonVisible: false,
  capacityDecisionOutcomeVisible: false,
  capacityCostLaterCheckinVisible: capacityCostLaterCheckinVisible,
  capacityActivationFitVisible: capacityActivationFitVisible,
  beforeYouSayYesPauseVisible: beforeYouSayYesPauseVisible,
  capacityWeeklyReviewVisible: capacityWeeklyReviewVisible,
  capacityBoundaryResponseVisible: false,
  thenVsNowVisible: false,
  archiveCalendarVisible: false,
  reviewRitualVisible: false,
  milestoneShareVisible: false,
);

Future<void> _resetStore(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_capacity_activation_fit_journal_$stamp.json',
    prefsPath: '/tmp/vm_capacity_activation_fit_prefs_$stamp.json',
  );
  await CapacityActivationFitStore.resetForTest();
}

void main() {
  const engine = CapacityActivationFitEngine();

  group('CapacityActivationFitEngine', () {
    test('hidden before 3 real capacity moments', () {
      final result = engine.buildFromJournal(
        entries: _entries(2),
        capacityLoopActive: true,
        capacityCohortActive: false,
        pendingPullReasonOnHome: false,
        pendingDecisionOutcomeOnHome: false,
        pendingCostCheckinOnHome: false,
        threeMomentActivationOnHome: false,
      );
      expect(result.hasCard, isFalse);
    });

    test('hidden for sample/demo-only entries', () {
      final result = engine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
        pendingPullReasonOnHome: false,
        pendingDecisionOutcomeOnHome: false,
        pendingCostCheckinOnHome: false,
        threeMomentActivationOnHome: false,
      );
      expect(result.hasCard, isFalse);
    });

    test('hidden in ScreenshotMode', () {
      final result = engine.build(
        CapacityActivationFitInput(
          sampleMode: true,
          capacityWedgeActive: true,
          capacityEvidenceCount: 3,
          capacityMomentCount: 3,
          pendingPullReasonOnHome: false,
          pendingDecisionOutcomeOnHome: false,
          pendingCostCheckinOnHome: false,
          threeMomentActivationOnHome: false,
        ),
      );
      expect(result.hasCard, isFalse);
    });

    test('appears at 3+ real capacity moments', () {
      final result = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        pendingPullReasonOnHome: false,
        pendingDecisionOutcomeOnHome: false,
        pendingCostCheckinOnHome: false,
        threeMomentActivationOnHome: false,
      );
      expect(result.hasCard, isTrue);
      expect(result.showOnCapacityLoop, isTrue);
      expect(result.showOnArchiveHome, isTrue);
      expect(result.title, 'Does this feel accurate?');
    });

    test('hidden on archive home when higher-priority cards pending', () {
      final result = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        pendingPullReasonOnHome: true,
        pendingDecisionOutcomeOnHome: false,
        pendingCostCheckinOnHome: false,
        threeMomentActivationOnHome: false,
      );
      expect(result.hasCard, isTrue);
      expect(result.showOnArchiveHome, isFalse);
      expect(result.showOnCapacityLoop, isTrue);
    });

    test('does not reappear after answered', () {
      final result = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        pendingPullReasonOnHome: false,
        pendingDecisionOutcomeOnHome: false,
        pendingCostCheckinOnHome: false,
        threeMomentActivationOnHome: false,
        record: CapacityActivationFitRecord(
          responseId: CapacityActivationFitResponseIds.fits,
          source: CapacityActivationFitSource.capacityLoopActivation,
          activationEntryCount: 3,
          status: CapacityActivationFitStatus.answered,
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
        ),
      );
      expect(result.hasCard, isFalse);
      expect(result.showOnArchiveHome, isFalse);
      expect(result.showAnsweredLineOnCapacityLoop, isTrue);
      expect(result.answeredSummaryLine, contains('fits'));
    });

    test('does not reappear after skipped', () {
      final result = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        pendingPullReasonOnHome: false,
        pendingDecisionOutcomeOnHome: false,
        pendingCostCheckinOnHome: false,
        threeMomentActivationOnHome: false,
        record: CapacityActivationFitRecord(
          responseId: '',
          source: CapacityActivationFitSource.capacityLoopActivation,
          activationEntryCount: 3,
          status: CapacityActivationFitStatus.skipped,
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
        ),
      );
      expect(result.hasCard, isFalse);
    });

    test('does not store private text in copy', () {
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('real_0', transcript: _privateSnippet)],
        capacityLoopActive: true,
        capacityCohortActive: false,
        pendingPullReasonOnHome: false,
        pendingDecisionOutcomeOnHome: false,
        pendingCostCheckinOnHome: false,
        threeMomentActivationOnHome: true,
      );
      expect(result.title.toLowerCase(), isNot(contains(_privateSnippet)));
      expect(result.body.toLowerCase(), isNot(contains(_privateSnippet)));
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy(CapacityActivationFitCopy.allVisibleStrings());
    });
  });

  group('CapacityActivationFitStore', () {
    test('stores fixed response locally', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityActivationFitStore.instance().saveAnswered(
        responseId: CapacityActivationFitResponseIds.partly,
        activationEntryCount: 3,
      );

      final record = CapacityActivationFitStore.cached;
      expect(record, isNotNull);
      expect(record!.responseId, CapacityActivationFitResponseIds.partly);
      expect(record.source, CapacityActivationFitSource.capacityLoopActivation);
      expect(record.activationEntryCount, 3);
      expect(record.status, CapacityActivationFitStatus.answered);
    });

    test('response does not store transcript text', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityActivationFitStore.instance().saveAnswered(
        responseId: CapacityActivationFitResponseIds.fits,
        activationEntryCount: 3,
      );

      final json = CapacityActivationFitStore.cached!.toJson();
      expect(json.toString().toLowerCase(), isNot(contains(_privateSnippet)));
    });

    test('skip/dismiss works', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityActivationFitStore.instance().saveSkipped(
        activationEntryCount: 3,
      );

      expect(CapacityActivationFitStore.cached?.isSkipped, isTrue);
      expect(CapacityActivationFitStore.hasCompleteRecord, isTrue);
    });
  });

  group('CapacityActivationFitCard', () {
    testWidgets('hidden in sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityActivationFitCard(
              result: _pendingResult(),
              sampleMode: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('capacity_activation_fit_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('does not expose transcript text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityActivationFitCard(
              result: _pendingResult(),
              compact: false,
            ),
          ),
        ),
      );

      expect(find.textContaining(_privateSnippet), findsNothing);
      expect(find.text('Yes, this fits'), findsOneWidget);
    });
  });

  group('Archive Home priority', () {
    const priorityEngine = ArchiveHomePriorityEngine();

    test('fit check follows cost check-in in sticky loop order', () {
      final ranked = [
        ...priorityEngine
            .build(
              _priorityInput(
                capacityCostLaterCheckinVisible: true,
                capacityActivationFitVisible: true,
                beforeYouSayYesPauseVisible: true,
              ),
            )
            .primarySections,
        ...priorityEngine
            .build(
              _priorityInput(
                capacityCostLaterCheckinVisible: true,
                capacityActivationFitVisible: true,
                beforeYouSayYesPauseVisible: true,
              ),
            )
            .secondarySections,
      ];

      expect(ranked, contains(ArchiveHomeSectionId.capacityActivationFit));
      expect(ranked, contains(ArchiveHomeSectionId.capacityCostLaterCheckin));
      expect(
        ranked.indexOf(ArchiveHomeSectionId.capacityCostLaterCheckin),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.capacityActivationFit)),
      );
      expect(
        ranked.indexOf(ArchiveHomeSectionId.capacityActivationFit),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.beforeYouSayYesPause)),
      );
    });

    test('respects primary card cap', () {
      final plan = priorityEngine.build(
        _priorityInput(
          capacityActivationFitVisible: true,
          capacityCostLaterCheckinVisible: true,
          beforeYouSayYesPauseVisible: true,
          capacityWeeklyReviewVisible: true,
        ),
      );
      expect(plan.primarySections.length, lessThanOrEqualTo(4));
    });
  });
}
