import 'package:archiveme_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:archiveme_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:archiveme_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_store.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_loop_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_loop_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_store.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_entries.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/capacity_decision_outcome_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

CapacityDecisionOutcomeRecord _answeredOutcome(
  String entryId,
  String outcomeId,
) => CapacityDecisionOutcomeRecord(
  sourceEntryId: entryId,
  outcomeId: outcomeId,
  status: CapacityDecisionOutcomeStatus.answered,
  createdAt: DateTime(2026, 6, 12),
  updatedAt: DateTime(2026, 6, 12),
);

CapacityDecisionOutcomeResult _visibleResult({String pendingId = 'real_0'}) =>
    CapacityDecisionOutcomeResult(
      hasCard: true,
      showOnArchiveHome: true,
      title: CapacityDecisionOutcomeCopy.cardTitle,
      body: CapacityDecisionOutcomeCopy.cardBody,
      helperText: CapacityDecisionOutcomeCopy.cardHelper,
      primaryCtaLabel: CapacityDecisionOutcomeCopy.saveOutcomeCta,
      secondaryCtaLabel: CapacityDecisionOutcomeCopy.skipCta,
      pendingEntryId: pendingId,
      recordedOutcomeCount: 0,
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
    journalPath: '/tmp/vm_capacity_outcome_journal_$stamp.json',
    prefsPath: '/tmp/vm_capacity_outcome_prefs_$stamp.json',
  );
  await CapacityDecisionOutcomeStore.resetForTest();
}

void main() {
  const outcomeEngine = CapacityDecisionOutcomeEngine();
  const loopEngine = CapacityLoopEngine();

  group('CapacityDecisionOutcomeEngine', () {
    test('hidden with no real entries', () {
      final result = outcomeEngine.buildFromJournal(
        entries: const [],
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('hidden for sample/demo-only entries', () {
      final result = outcomeEngine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('appears for capacity-yes user after pull reason recorded', () {
      final entries = [_capacityEntry('real_0')];
      CapacityPullReasonStore.seedForTest([
        CapacityPullReasonRecord(
          sourceEntryId: 'real_0',
          reasonIds: const [CapacityPullReasonIds.soundedUrgent],
          status: CapacityPullReasonStatus.answered,
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
        ),
      ]);
      final result = outcomeEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isTrue);
      expect(result.title, 'What did you choose?');
      expect(result.pendingEntryId, 'real_0');
    });

    test('hidden until pull reason answered or skipped', () {
      CapacityPullReasonStore.seedForTest(const []);
      final entries = [_capacityEntry('real_0')];
      final result = outcomeEngine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('hidden in ScreenshotMode', () {
      final result = outcomeEngine.build(
        const CapacityDecisionOutcomeInput(
          realSavedMomentCount: 1,
          capacityEvidenceCount: 1,
          capacityWedgeActive: true,
          sampleMode: true,
          records: [],
          pendingEntryId: 'real_0',
        ),
      );
      expect(result.hasCard, isFalse);
    });

    test('generic users do not see card too early', () {
      final result = outcomeEngine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: false,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isFalse);
    });

    test('hidden when all moments already have records', () {
      final result = outcomeEngine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: [
          _answeredOutcome('real_0', CapacityDecisionOutcomeIds.saidYes),
        ],
      );
      expect(result.hasCard, isFalse);
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy(CapacityDecisionOutcomeCopy.allVisibleStrings());
    });
  });

  group('CapacityDecisionOutcomeStore', () {
    test('stores outcome locally and links to sourceEntryId', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityDecisionOutcomeStore.instance().saveAnswered(
        sourceEntryId: 'entry_a',
        outcomeId: CapacityDecisionOutcomeIds.saidNo,
      );

      final records = await CapacityDecisionOutcomeStore.instance().loadAll();
      expect(records, hasLength(1));
      expect(records.first.sourceEntryId, 'entry_a');
      expect(records.first.outcomeId, CapacityDecisionOutcomeIds.saidNo);
    });

    test('outcome does not store transcript text', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityDecisionOutcomeStore.instance().saveAnswered(
        sourceEntryId: 'entry_b',
        outcomeId: CapacityDecisionOutcomeIds.delayed,
      );

      final json = (await CapacityDecisionOutcomeStore.instance().loadAll())
          .first
          .toJson();
      expect(json.keys, containsAll(['sourceEntryId', 'outcomeId', 'status']));
      expect(json.toString(), isNot(contains(_privateSnippet)));
      expect(json.toString(), isNot(contains('transcript')));
    });

    test('skip/dismiss works', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await CapacityDecisionOutcomeStore.instance().saveSkipped(
        sourceEntryId: 'entry_c',
      );
      final record = await CapacityDecisionOutcomeStore.instance()
          .recordForEntry('entry_c');
      expect(record?.status, CapacityDecisionOutcomeStatus.skipped);
    });
  });

  group('CapacityLoopEngine outcome integration', () {
    test('loop card shows safe outcome count', () {
      CapacityDecisionOutcomeStore.seedForTest([
        _answeredOutcome('real_0', CapacityDecisionOutcomeIds.saidYes),
        _answeredOutcome('real_1', CapacityDecisionOutcomeIds.saidNo),
      ]);

      final result = loopEngine.buildFromJournal(
        entries: [_capacityEntry('real_0'), _capacityEntry('real_1')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        outcomeRecords: CapacityDecisionOutcomeStore.cached,
      );

      expect(result.costLater, contains('Outcome marked on 2 moments'));
      expect(result.outcomeEvidenceLabel, contains('You marked 2 outcomes'));
      expect(result.outcomeEvidenceLabel, contains('pattern may have changed'));
      expect(result.costLater.toLowerCase(), isNot(contains(_privateSnippet)));
    });

    test('loop strengthen prompt when no outcomes recorded', () {
      CapacityDecisionOutcomeStore.seedForTest(const []);
      CapacityPullReasonStore.seedForTest(const []);

      final result = loopEngine.buildFromJournal(
        entries: [_capacityEntry('real_0'), _capacityEntry('real_1')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        outcomeRecords: const [],
        pullReasonRecords: const [],
      );

      expect(
        result.pullReasonSummary,
        contains(CapacityPullReasonCopy.loopStrengthenPrompt),
      );
    });

    test('share copy does not include outcome details', () {
      expect(
        CapacityLoopCopy.shareCopy.toLowerCase(),
        isNot(contains('said no')),
      );
      expect(
        CapacityLoopCopy.shareCopy.toLowerCase(),
        isNot(contains('transcript')),
      );
    });
  });

  group('CapacityDecisionOutcomeCard widget', () {
    testWidgets('renders outcome card copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityDecisionOutcomeCard.test(
              result: _visibleResult(),
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('What did you choose?'), findsOneWidget);
      expect(find.text('Save outcome'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
      expect(find.textContaining(_privateSnippet), findsNothing);
    });

    testWidgets('hidden in sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityDecisionOutcomeCard.test(
              result: _visibleResult(),
              onSaved: () {},
              sampleMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('capacity_decision_outcome_card_hidden')),
        findsOneWidget,
      );
    });
  });

  group('Archive Home priority', () {
    test('decision outcome ranks before cost later check-in', () {
      const priorityEngine = ArchiveHomePriorityEngine();
      final plan = priorityEngine.build(
        const ArchiveHomePriorityInput(
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
        ranked.indexOf(ArchiveHomeSectionId.capacityDecisionOutcome),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.capacityCostLaterCheckin)),
      );
    });
  });
}