import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/archive_evidence_map.dart';
import 'package:voicememory_mobile/features/activation/archive_health_action_plan.dart';
import 'package:voicememory_mobile/features/activation/archive_health_score.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_layout.dart';
import 'package:voicememory_mobile/features/activation/belief_history_timeline.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/activation/context_insights.dart';
import 'package:voicememory_mobile/features/activation/evidence_attention_filters.dart';
import 'package:voicememory_mobile/features/activation/weekly_archive_review.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
}) =>
    JournalEntry(
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
  final beliefHistory =
      entries.length >= 5 ? BeliefHistoryTimelineEngine.build(entries: entries) : null;
  final weeklyReview =
      entries.length >= 5 ? WeeklyArchiveReviewEngine.build(entries: entries) : null;
  final shareProof =
      const ShareableArchiveProofEngine().buildFromJournal(entries: entries);

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
  setUp(ArchiveInsightFeedbackStore.resetForTest);

  group('ArchiveWorkspaceLayoutEngine', () {
    test('0 entries does not show noisy evidence workspace', () {
      final layout = _layout(const []);
      expect(layout.stage, ArchiveWorkspaceStage.empty);
      expect(layout.evidenceQuality.show, isFalse);
      expect(layout.reviewHistory.show, isFalse);
      expect(layout.showArchiveHealth, isFalse);
      expect(layout.showEvidenceMap, isFalse);
      expect(layout.showInsightQualityLink, isFalse);
    });

    test('1 entry shows action guidance but not evidence or review stack', () {
      final layout = _layout(_distinctWorkEntries(1));
      expect(layout.stage, ArchiveWorkspaceStage.one);
      expect(layout.showActionPlan, isTrue);
      expect(layout.evidenceQuality.show, isFalse);
      expect(layout.reviewHistory.show, isFalse);
      expect(layout.showContextInsights, isFalse);
      expect(layout.showEvidenceMap, isFalse);
      expect(layout.showInsightQualityLink, isFalse);
    });

    test('2 entries shows needs attention but not review/history', () {
      final layout = _layout(_distinctWorkEntries(2));
      expect(layout.stage, ArchiveWorkspaceStage.two);
      expect(layout.needsAttention.show, isTrue);
      expect(layout.showActionPlan, isTrue);
      expect(layout.evidenceQuality.show, isFalse);
      expect(layout.reviewHistory.show, isFalse);
      expect(layout.showBeliefHistory, isFalse);
      expect(layout.showWeeklyReview, isFalse);
    });

    test('3 entries can show evidence quality but not weekly review', () {
      final layout = _layout(_distinctWorkEntries(3));
      expect(layout.stage, ArchiveWorkspaceStage.evidenceReady);
      expect(layout.evidenceQuality.show, isTrue);
      expect(layout.showArchiveHealth, isTrue);
      expect(layout.reviewHistory.show, isFalse);
      expect(layout.showWeeklyReview, isFalse);
    });

    test('5+ entries can show review and history', () {
      final layout = _layout(_distinctWorkEntries(5));
      expect(layout.stage, ArchiveWorkspaceStage.reviewReady);
      expect(layout.reviewHistory.show, isTrue);
      expect(layout.showBeliefHistory, isTrue);
      expect(layout.showWeeklyReview, isTrue);
      expect(
        layout.reviewHistory.heading,
        VisibleArchiveProofCopy.archiveWorkspaceReviewHistoryHeading,
      );
    });

    test('section headings render when sections have content', () {
      final layout = _layout(_distinctWorkEntries(5));
      expect(
        layout.needsAttention.heading,
        VisibleArchiveProofCopy.archiveWorkspaceNeedsAttentionHeading,
      );
      expect(
        layout.evidenceQuality.heading,
        VisibleArchiveProofCopy.archiveWorkspaceEvidenceQualityHeading,
      );
      expect(
        layout.controls.heading,
        VisibleArchiveProofCopy.archiveWorkspaceControlsHeading,
      );
    });

    test('review section stays hidden before five balanced entries', () {
      final layout = _layout([
        _voiceEntry(
          id: 'e1',
          transcript:
              'I felt pressure at work before saying yes again even when I was tired moment one.',
          captureContextTag: CaptureContextTagIds.work,
        ),
        _voiceEntry(
          id: 'e2',
          transcript:
              'Work kept pulling me back after I wanted to stop for the day moment two.',
          createdAt: DateTime(2026, 6, 11),
          captureContextTag: CaptureContextTagIds.work,
        ),
        _voiceEntry(
          id: 'e3',
          transcript:
              'Home felt loud before I could settle into the evening moment three.',
          createdAt: DateTime(2026, 6, 10),
          captureContextTag: CaptureContextTagIds.home,
        ),
        _voiceEntry(
          id: 'e4',
          transcript:
              'Home felt loud again before I could settle into the evening moment four.',
          createdAt: DateTime(2026, 6, 9),
          captureContextTag: CaptureContextTagIds.home,
        ),
      ]);
      expect(layout.evidenceQuality.show, isTrue);
      expect(layout.reviewHistory.show, isFalse);
      expect(layout.showAttentionFilters, isFalse);
    });

    test('standalone share proof stays lower priority before five entries', () {
      final layout = _layout(_distinctWorkEntries(3));
      expect(layout.showStandaloneShareProof, isFalse);
    });

    test('archive home share proof suppresses duplicate standalone card', () {
      final entries = _distinctWorkEntries(5);
      final archiveHome = ArchiveHomeSummaryEngine.build(entries: entries);
      expect(archiveHome.showShareProof, isTrue);

      final layout = _layout(entries);
      expect(layout.showStandaloneShareProof, isFalse);
    });

    test('copy avoids banned language', () {
      _expectNoBannedCopy([
        VisibleArchiveProofCopy.archiveWorkspaceNeedsAttentionHeading,
        VisibleArchiveProofCopy.archiveWorkspaceEvidenceQualityHeading,
        VisibleArchiveProofCopy.archiveWorkspaceReviewHistoryHeading,
        VisibleArchiveProofCopy.archiveWorkspaceControlsHeading,
      ]);
    });
  });
}
