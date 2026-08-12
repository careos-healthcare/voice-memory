import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/archive_health_action_plan.dart';
import 'package:archiveme_mobile/features/activation/archive_health_score.dart';
import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_hint_store.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_hints.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_layout.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_quick_actions.dart';
import 'package:archiveme_mobile/features/activation/belief_history_timeline.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/activation/context_insights.dart';
import 'package:archiveme_mobile/features/activation/evidence_attention_filters.dart';
import 'package:archiveme_mobile/features/activation/insight_quality_dashboard.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flush_sensitive_stores.dart';
import 'support/test_storage_sandbox.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
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
  captureContextTag: captureContextTag,
);

JournalEntry _degradedVoiceEntry({
  String id = 'd1',
  String? captureContextTag,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
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
  captureContextTag: captureContextTag,
);

List<JournalEntry> _distinctWorkEntries(int count) {
  final transcripts = [
    'I felt pressure at work before saying yes again even when I was tired moment one.',
    'Work kept pulling me back after I wanted to stop for the day moment two.',
    'I noticed the same hurry showing up before I answered anyone moment three.',
    'The deadline pressure returned, but I caught it earlier this time moment four.',
    'Another work moment before I could leave for the day moment five.',
  ];
  return List.generate(
    count,
    (index) => _voiceEntry(
      id: 'e${index + 1}',
      transcript: transcripts[index],
      createdAt: DateTime(2026, 6, 9 + index, 12),
      captureContextTag: index.isEven
          ? CaptureContextTagIds.work
          : CaptureContextTagIds.home,
    ),
  );
}

ArchiveWorkspaceLayout _layout(List<JournalEntry> entries) {
  final archiveHome = ArchiveHomeSummaryEngine.build(entries: entries);
  final beliefHistory = entries.length >= 5
      ? BeliefHistoryTimelineEngine.build(entries: entries)
      : null;
  final weeklyReview = entries.length >= 5
      ? WeeklyArchiveReviewEngine.build(entries: entries)
      : null;
  final shareProof = const ShareableArchiveProofEngine().buildFromJournal(
    entries: entries,
  );

  return ArchiveWorkspaceLayoutEngine.build(
    entries: entries,
    archiveHome: archiveHome,
    attentionFilters: EvidenceAttentionFiltersEngine.build(
      entries: entries,
      omitKinds: const {EvidenceAttentionFilterKind.sameContext},
    ),
    actionPlan: ArchiveHealthActionPlanEngine.build(entries: entries),
    archiveHealth: ArchiveHealthScoreEngine.build(entries: entries),
    contextInsights: ContextInsightsEngine.build(entries: entries),
    evidenceMap: ArchiveEvidenceMapEngine.build(entries: entries),
    beliefHistory: beliefHistory,
    weeklyReview: weeklyReview,
    shareProof: shareProof,
  );
}

ArchiveWorkspaceQuickActions _quickActions(List<JournalEntry> entries) {
  final archiveHome = ArchiveHomeSummaryEngine.build(entries: entries);
  final layout = _layout(entries);
  final evidenceMap = ArchiveEvidenceMapEngine.build(entries: entries);
  final weeklyReview = entries.length >= 5
      ? WeeklyArchiveReviewEngine.build(entries: entries)
      : null;
  final shareProof = const ShareableArchiveProofEngine().buildFromJournal(
    entries: entries,
  );

  return ArchiveWorkspaceQuickActionsEngine.build(
    entries: entries,
    archiveHome: archiveHome,
    workspaceLayout: layout,
    evidenceMapVisible: evidenceMap.showCard,
    weeklyReview: weeklyReview,
    shareProof: shareProof,
  );
}

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
];

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
  }
}

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await ArchiveInsightFeedbackStore.resetForTest();
    ArchiveWorkspaceHintStore.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() async {
    await flushSensitiveStoresForTest();
    sandbox.dispose();
  });
  group('Archive workspace entry-count ladder', () {
    test('zero-entry workspace is not noisy', () {
      final layout = _layout(const []);
      final quickActions = _quickActions(const []);
      final hints = ArchiveWorkspaceHintsEngine.build(layout: layout);
      final home = ArchiveHomeSummaryEngine.build(entries: const []);

      expect(layout.stage, ArchiveWorkspaceStage.empty);
      expect(layout.evidenceQuality.show, isFalse);
      expect(layout.reviewHistory.show, isFalse);
      expect(quickActions.showCard, isFalse);
      expect(hints.needsAttentionHint, isNull);
      expect(hints.evidenceQualityHint, isNull);
      expect(home.stage, ArchiveHomeStage.empty);
    });

    test('one-entry workspace only shows appropriate action guidance', () {
      final entries = _distinctWorkEntries(1);
      final layout = _layout(entries);
      final quickActions = _quickActions(entries);
      final hints = ArchiveWorkspaceHintsEngine.build(layout: layout);
      final home = ArchiveHomeSummaryEngine.build(entries: entries);

      expect(layout.stage, ArchiveWorkspaceStage.one);
      expect(layout.showActionPlan, isFalse);
      expect(layout.needsAttention.show, isFalse);
      expect(layout.evidenceQuality.show, isFalse);
      expect(layout.reviewHistory.show, isFalse);
      expect(quickActions.showCard, isFalse);
      expect(hints.needsAttentionHint, isNull);
      expect(home.primaryAction, ArchiveHomeAction.addMoment);
      expect(home.suppressDuplicatePayoffCards, isTrue);
    });

    test('two-entry workspace avoids premature belief/review copy', () {
      final entries = _distinctWorkEntries(2);
      final layout = _layout(entries);
      final home = ArchiveHomeSummaryEngine.build(entries: entries);

      expect(layout.stage, ArchiveWorkspaceStage.two);
      expect(layout.reviewHistory.show, isFalse);
      expect(layout.showBeliefHistory, isFalse);
      expect(layout.showWeeklyReview, isFalse);
      expect(layout.evidenceQuality.show, isFalse);
      expect(home.stage, ArchiveHomeStage.two);
      expect(home.suppressDuplicatePayoffCards, isTrue);
      _expectNoBannedCopy([home.title, home.body]);
    });

    test(
      '3-entry workspace unlocks evidence quality but not weekly review',
      () {
        final entries = _distinctWorkEntries(3);
        final layout = _layout(entries);
        final quickActions = _quickActions(entries);

        expect(layout.evidenceQuality.show, isTrue);
        expect(layout.showEvidenceMap, isTrue);
        expect(layout.reviewHistory.show, isFalse);
        expect(layout.showWeeklyReview, isFalse);
        expect(
          quickActions.actions
              .map((action) => action.kind)
              .contains(ArchiveWorkspaceQuickActionKind.viewWeeklyReview),
          isFalse,
        );
      },
    );

    test('4-entry workspace still hides review/history', () {
      final layout = _layout(_distinctWorkEntries(4));
      expect(layout.evidenceQuality.show, isTrue);
      expect(layout.reviewHistory.show, isFalse);
    });

    test('5-entry workspace unlocks review/history', () {
      final entries = _distinctWorkEntries(5);
      final layout = _layout(entries);
      final quickActions = _quickActions(entries);

      expect(layout.reviewHistory.show, isTrue);
      expect(layout.showBeliefHistory, isTrue);
      expect(layout.showWeeklyReview, isTrue);
      expect(
        quickActions.actions.any(
          (action) =>
              action.kind == ArchiveWorkspaceQuickActionKind.viewWeeklyReview,
        ),
        isTrue,
      );
    });
  });

  group('Archive workspace quick actions and hints', () {
    test('quick actions stay max 3', () async {
      final entries = [
        _voiceEntry(
          id: 'e1',
          transcript:
              'I felt pressure at work before saying yes again even when I was tired moment one.',
        ),
        _voiceEntry(
          id: 'e2',
          transcript:
              'Another untagged moment before I could leave for the day moment two.',
          createdAt: DateTime(2026, 6, 11),
        ),
        _voiceEntry(
          id: 'e3',
          transcript:
              'I noticed the same hurry showing up before I answered anyone moment three.',
          createdAt: DateTime(2026, 6, 10),
        ),
        _voiceEntry(
          id: 'e4',
          transcript:
              'The deadline pressure returned, but I caught it earlier this time moment four.',
          createdAt: DateTime(2026, 6, 9),
        ),
        _voiceEntry(
          id: 'e5',
          transcript:
              'Another work moment before I could leave for the day moment five.',
          createdAt: DateTime(2026, 6, 8),
        ),
      ];
      await ArchiveInsightFeedbackStore.record(
        'beliefEvidence',
        ArchiveInsightFeedbackChoice.notQuite,
      );
      await ArchiveInsightFeedbackStore.saveCorrectionNote(
        'beliefEvidence',
        'This felt more about hurry than pressure.',
      );

      final quickActions = _quickActions(entries);
      expect(quickActions.actions.length, lessThanOrEqualTo(3));
    });

    test('hint dismissal persists across reload', () async {
      ArchiveWorkspaceHintStore.dismiss(ArchiveWorkspaceHintIds.intro);
      await ArchiveWorkspaceHintStore.flushForTest();
      ArchiveWorkspaceHintStore.resetForTest();
      await ArchiveWorkspaceHintStore.ensureLoaded();

      expect(
        ArchiveWorkspaceHintStore.isDismissed(ArchiveWorkspaceHintIds.intro),
        isTrue,
      );

      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layout(_distinctWorkEntries(3)),
      );
      expect(hints.introHint, isNull);
    });

    test('dismissed section hints stay hidden when section is visible', () {
      ArchiveWorkspaceHintStore.dismiss(
        ArchiveWorkspaceHintIds.evidenceQuality,
      );
      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layout(_distinctWorkEntries(3)),
      );
      expect(hints.evidenceQualityHint, isNull);
      expect(hints.introHint, isNotNull);
    });
  });

  group('Archive workspace evidence map and tags', () {
    test('map drilldown routes still work', () {
      final map = ArchiveEvidenceMapEngine.build(
        entries: _distinctWorkEntries(3),
      );
      expect(map.showCard, isTrue);
      expect(
        ArchiveEvidenceMapNavigation.contextPath(CaptureContextTagIds.work),
        '/archive-evidence-map/context/${CaptureContextTagIds.work}',
      );
      expect(
        ArchiveEvidenceMapNavigation.contextPath(
          ArchiveEvidenceMapRowIds.untagged,
        ),
        '/archive-evidence-map/context/${ArchiveEvidenceMapRowIds.untagged}',
      );
    });

    test('context tag edit changes evidence map counts', () {
      final untagged = [
        _voiceEntry(
          id: 'e1',
          transcript:
              'I felt pressure at work before saying yes again even when I was tired moment one.',
        ),
        _voiceEntry(
          id: 'e2',
          transcript:
              'Another untagged moment before I could leave for the day moment two.',
          createdAt: DateTime(2026, 6, 11),
        ),
        _voiceEntry(
          id: 'e3',
          transcript:
              'I noticed the same hurry showing up before I answered anyone moment three.',
          createdAt: DateTime(2026, 6, 10),
        ),
      ];
      final before = ArchiveEvidenceMapEngine.build(entries: untagged);
      final untaggedBefore = before.rows
          .firstWhere((row) => row.rowId == ArchiveEvidenceMapRowIds.untagged)
          .count;

      final tagged = [
        untagged[0],
        untagged[1].copyWith(captureContextTag: CaptureContextTagIds.work),
        untagged[2],
      ];
      final after = ArchiveEvidenceMapEngine.build(entries: tagged);
      final untaggedAfter = after.rows
          .firstWhere((row) => row.rowId == ArchiveEvidenceMapRowIds.untagged)
          .count;
      final workAfter = after.rows
          .firstWhere((row) => row.rowId == CaptureContextTagIds.work)
          .count;

      expect(untaggedBefore, greaterThan(untaggedAfter));
      expect(workAfter, 1);
    });

    test('untagged drilldown filter resolves route', () {
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Another untagged moment before I could leave for the day moment two.',
            createdAt: DateTime(2026, 6, 11),
          ),
        ],
      );
      final untagged = filters.filters.firstWhere(
        (filter) => filter.kind == EvidenceAttentionFilterKind.untagged,
      );
      expect(
        untagged.resolveRoute(),
        ArchiveEvidenceMapNavigation.contextPath(
          ArchiveEvidenceMapRowIds.untagged,
        ),
      );
    });

    test('degraded entries do not inflate workspace counts', () {
      final mixed = [..._distinctWorkEntries(2), _degradedVoiceEntry()];
      final layout = _layout(mixed);
      expect(layout.eligibleCount, 2);
      expect(layout.stage, ArchiveWorkspaceStage.two);
      expect(layout.evidenceQuality.show, isFalse);
    });
  });

  group('Archive workspace feedback and routes', () {
    test('insight quality route still works', () {
      expect(InsightQualityNavigation.route, '/insight-quality');
    });

    test('not quite feedback unlocks insight quality link at two entries', () async {
      await ArchiveInsightFeedbackStore.record(
        'beliefEvidence',
        ArchiveInsightFeedbackChoice.notQuite,
      );
      final layout = _layout(_distinctWorkEntries(2));
      expect(layout.showInsightQualityLink, isTrue);
    });

    test('correction note and hidden insight do not break quick actions', () async {
      await ArchiveInsightFeedbackStore.record(
        'beliefEvidence',
        ArchiveInsightFeedbackChoice.notQuite,
      );
      await ArchiveInsightFeedbackStore.saveCorrectionNote(
        'beliefEvidence',
        'This felt more about hurry than pressure.',
      );
      await ArchiveInsightFeedbackStore.hide('contextInsight');

      final quickActions = _quickActions(_distinctWorkEntries(3));
      expect(quickActions.showCard, isTrue);
      expect(
        quickActions.actions.any(
          (action) =>
              action.kind == ArchiveWorkspaceQuickActionKind.reviewCorrections,
        ),
        isTrue,
      );
    });
  });

  group('Archive workspace share-safe privacy', () {
    test(
      'share-safe proof excludes tags/map/filter data and raw transcripts',
      () {
        const engine = ShareableArchiveProofEngine();
        const sensitive =
            'Maria told me about the divorce paperwork at the hospital again';
        final entries = List.generate(
          5,
          (i) => _voiceEntry(
            id: 'e$i',
            transcript: sensitive,
            createdAt: DateTime(2026, 6, 9 + i, 12),
            captureContextTag: i.isEven
                ? CaptureContextTagIds.work
                : CaptureContextTagIds.home,
          ),
        );
        final proof = engine.buildFromJournal(entries: entries);
        final shareText = proof.shareText.toLowerCase();

        expect(proof.hasProof, isTrue);
        expect(shareText, isNot(contains('maria')));
        expect(shareText, isNot(contains('divorce')));
        expect(shareText, isNot(contains('hospital')));
        expect(shareText, isNot(contains('work')));
        expect(shareText, isNot(contains('home')));
        expect(shareText, isNot(contains('untagged')));
        expect(shareText, isNot(contains('filter')));
        expect(shareText, isNot(contains('map')));
        expect(shareText, contains('no private entries shared.'));
      },
    );
  });

  group('Archive workspace copy guardrails', () {
    test('no diagnosis/therapy/certainty/streak/guilt language appears', () {
      _expectNoBannedCopy([
        VisibleArchiveProofCopy.archiveWorkspaceHintIntroTitle,
        VisibleArchiveProofCopy.archiveWorkspaceHintIntroBody,
        VisibleArchiveProofCopy.archiveWorkspaceHintNeedsAttentionBody,
        VisibleArchiveProofCopy.archiveWorkspaceHintEvidenceQualityBody,
        VisibleArchiveProofCopy.archiveWorkspaceHintReviewHistoryBody,
        VisibleArchiveProofCopy.archiveWorkspaceQuickActionsTitle,
        VisibleArchiveProofCopy.archiveWorkspaceNeedsAttentionHeading,
        VisibleArchiveProofCopy.archiveWorkspaceEvidenceQualityHeading,
        VisibleArchiveProofCopy.archiveWorkspaceReviewHistoryHeading,
        VisibleArchiveProofCopy.twoEntryBodyUngrounded,
        VisibleArchiveProofCopy.archiveHomeOneBody,
      ]);
    });
  });
}