import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/archive_health_score.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/archive_health_card.dart';

JournalEntry _voiceEntry({
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

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
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
);

JournalEntry _blankEntry({String id = 'b1'}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: 'too short',
  durationSeconds: 5,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _distinctEntries(int count) => List.generate(
  count,
  (i) => _voiceEntry(
    id: 'e$i',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired moment $i.',
    createdAt: DateTime(2026, 6, 9 + i, 12),
  ),
);

const _privateNote = 'This is not about work - it is more about family.';

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

  group('ArchiveHealthScoreEngine', () {
    test('0 usable entries does not show misleading health score', () {
      final score = ArchiveHealthScoreEngine.build(entries: const []);
      expect(score.showCard, isFalse);
      expect(score.usableMomentCount, 0);
      expect(score.statusLine, isEmpty);
    });

    test('1 usable entry shows thin evidence', () {
      final score = ArchiveHealthScoreEngine.build(
        entries: _distinctEntries(1),
      );
      expect(score.showCard, isTrue);
      expect(score.stage, ArchiveHealthStage.thin);
      expect(score.statusLine, VisibleArchiveProofCopy.archiveHealthThinStatus);
      expect(score.whatToAddNextLine, contains('one more'));
    });

    test('2 usable entries shows starting to compare', () {
      final score = ArchiveHealthScoreEngine.build(
        entries: _distinctEntries(2),
      );
      expect(score.stage, ArchiveHealthStage.startingToCompare);
      expect(
        score.statusLine,
        VisibleArchiveProofCopy.archiveHealthStartingStatus,
      );
    });

    test('3 usable entries shows cautious first belief readiness', () {
      final score = ArchiveHealthScoreEngine.build(
        entries: _distinctEntries(3),
      );
      expect(score.stage, ArchiveHealthStage.firstBeliefReady);
      expect(
        score.statusLine,
        VisibleArchiveProofCopy.archiveHealthFirstBeliefStatus,
      );
      expect(score.statusBody, contains('not conclusions'));
    });

    test('4 usable entries shows belief update readiness', () {
      final score = ArchiveHealthScoreEngine.build(
        entries: _distinctEntries(4),
      );
      expect(score.stage, ArchiveHealthStage.beliefUpdateReady);
      expect(
        score.statusLine,
        VisibleArchiveProofCopy.archiveHealthBeliefUpdateStatus,
      );
    });

    test('5+ usable entries shows review readiness', () {
      final score = ArchiveHealthScoreEngine.build(
        entries: _distinctEntries(5),
      );
      expect(score.stage, ArchiveHealthStage.reviewReady);
      expect(
        score.statusLine,
        VisibleArchiveProofCopy.archiveHealthReviewStatus,
      );
    });

    test('degraded and blank entries do not count', () {
      final score = ArchiveHealthScoreEngine.build(
        entries: [
          ..._distinctEntries(2),
          _degradedVoiceEntry(id: 'd1'),
          _blankEntry(id: 'b1'),
        ],
      );
      expect(score.usableMomentCount, 2);
      expect(score.excludedEntryCount, 2);
      expect(score.stage, ArchiveHealthStage.startingToCompare);
    });

    test('duplicate entries reduce evidence quality', () {
      const shared =
          'I felt pressure at work before saying yes again even when I was tired.';
      final score = ArchiveHealthScoreEngine.build(
        entries: List.generate(
          5,
          (i) => _voiceEntry(
            id: 'e$i',
            transcript: shared,
            createdAt: DateTime(2026, 6, 9 + i, 12),
          ),
        ),
      );
      expect(score.usableMomentCount, 5);
      expect(score.duplicateEntryCount, greaterThan(0));
      expect(
        score.evidenceQualityLine,
        VisibleArchiveProofCopy.archiveHealthThinStatus,
      );
      expect(
        score.needsMoreEvidenceLines,
        contains(VisibleArchiveProofCopy.archiveHealthDuplicateLine),
      );
      expect(score.confidenceBand, isNot(ArchiveHealthConfidenceBand.stronger));
    });

    test('Not quite feedback lowers confidence and adds caution', () {
      ArchiveInsightFeedbackStore.record(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        ArchiveInsightFeedbackChoice.notQuite,
      );
      final score = ArchiveHealthScoreEngine.build(
        entries: _distinctEntries(4),
      );
      expect(
        score.needsMoreEvidenceLines,
        contains(VisibleArchiveProofCopy.archiveHealthNotQuiteLine),
      );
      expect(score.cautionLine, isNotNull);
      expect(score.confidenceBand, ArchiveHealthConfidenceBand.cautious);
    });

    test('Feels right feedback does not create certainty', () {
      for (var i = 0; i < 5; i++) {
        ArchiveInsightFeedbackStore.record(
          ArchiveInsightFeedbackStore.targetId(
            ArchiveInsightTarget.beliefUpdate,
          ),
          ArchiveInsightFeedbackChoice.feelsRight,
        );
      }
      final score = ArchiveHealthScoreEngine.build(
        entries: _distinctEntries(5),
      );
      _expectNoBannedCopy([
        score.statusLine,
        score.statusBody,
        score.evidenceQualityLine,
        score.whatToAddNextLine,
        if (score.cautionLine != null) score.cautionLine!,
        ...score.needsMoreEvidenceLines,
      ]);
      expect(score.confidenceBand, isNot(ArchiveHealthConfidenceBand.low));
      expect(
        score.evidenceQualityLine.toLowerCase(),
        isNot(contains('certain')),
      );
    });

    test('correction notes do not appear in share-safe proof', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        'beliefUpdate',
        _privateNote,
      );
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: _distinctEntries(5),
      );
      final shareText = proof.lines.join('\n');
      expect(
        shareText.toLowerCase(),
        isNot(contains(_privateNote.toLowerCase())),
      );
      expect(shareText.toLowerCase(), isNot(contains('your note:')));
    });

    test('dashboard copy avoids banned language', () {
      _expectNoBannedCopy([
        VisibleArchiveProofCopy.archiveHealthTitle,
        VisibleArchiveProofCopy.archiveHealthSubtitle,
        VisibleArchiveProofCopy.archiveHealthThinStatus,
        VisibleArchiveProofCopy.archiveHealthStartingStatus,
        VisibleArchiveProofCopy.archiveHealthFirstBeliefStatus,
        VisibleArchiveProofCopy.archiveHealthBeliefUpdateStatus,
        VisibleArchiveProofCopy.archiveHealthReviewStatus,
        VisibleArchiveProofCopy.archiveHealthCautionFeedback,
      ]);
    });
  });

  group('ArchiveHealthCard', () {
    testWidgets('hidden score renders nothing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveHealthCard(score: ArchiveHealthScore.hidden()),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('archive_health_card')), findsNothing);
    });

    testWidgets('visible score renders sections', (tester) async {
      final score = ArchiveHealthScoreEngine.build(
        entries: _distinctEntries(3),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SingleChildScrollView(child: ArchiveHealthCard(score: score)),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('archive_health_card')), findsOneWidget);
      expect(find.text('Archive health'), findsOneWidget);
      expect(
        find.byKey(const Key('archive_health_usable_count')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
      expect(
        find.byKey(const Key('archive_health_quality_line')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_health_add_next_line')),
        findsOneWidget,
      );
      _expectNoBannedCopy(
        tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? ''),
      );
    });
  });
}
