import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/archive_evidence_map.dart';
import 'package:voicememory_mobile/features/activation/archive_health_action_plan.dart';
import 'package:voicememory_mobile/features/activation/archive_health_score.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_hint_store.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_hints.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_layout.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/activation/context_insights.dart';
import 'package:voicememory_mobile/features/activation/evidence_attention_filters.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/archive_workspace_hint_card.dart';

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

ArchiveWorkspaceLayout _layoutForEntries(List<JournalEntry> entries) {
  final archiveHome = ArchiveHomeSummaryEngine.build(entries: entries);
  final evidenceMap = ArchiveEvidenceMapEngine.build(entries: entries);
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
    evidenceMap: evidenceMap,
    beliefHistory: null,
    weeklyReview: null,
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
  setUp(() async {
    ArchiveInsightFeedbackStore.resetForTest();
    ArchiveWorkspaceHintStore.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('ArchiveWorkspaceHintsEngine', () {
    test('intro hint appears when workspace is visible', () {
      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layoutForEntries(const []),
      );
      expect(hints.introHint, isNotNull);
      expect(hints.introHint!.isIntro, isTrue);
      expect(
        hints.introHint!.title,
        VisibleArchiveProofCopy.archiveWorkspaceHintIntroTitle,
      );
    });

    test('0 entries does not show noisy section hints', () {
      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layoutForEntries(const []),
      );
      expect(hints.needsAttentionHint, isNull);
      expect(hints.evidenceQualityHint, isNull);
      expect(hints.reviewHistoryHint, isNull);
    });

    test('section hints only appear when their section is visible', () {
      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layoutForEntries(_distinctWorkEntries(3)),
      );
      expect(hints.needsAttentionHint, isNotNull);
      expect(hints.evidenceQualityHint, isNotNull);
      expect(hints.reviewHistoryHint, isNull);
    });

    test('no more than one large hint appears at once', () {
      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layoutForEntries(_distinctWorkEntries(5)),
      );
      expect(hints.introHint?.compact, isFalse);
      expect(hints.sectionHints.every((hint) => hint.compact), isTrue);
    });

    test('dismissed hint does not reappear after reload', () async {
      ArchiveWorkspaceHintStore.dismiss(ArchiveWorkspaceHintIds.intro);
      await ArchiveWorkspaceHintStore.flushForTest();
      await ArchiveWorkspaceHintStore.ensureLoaded();

      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layoutForEntries(_distinctWorkEntries(3)),
      );
      expect(hints.introHint, isNull);
      expect(
        ArchiveWorkspaceHintStore.dismissedForTest(),
        contains(ArchiveWorkspaceHintIds.intro),
      );
    });

    test('copy avoids banned language', () {
      final hints = ArchiveWorkspaceHintsEngine.build(
        layout: _layoutForEntries(_distinctWorkEntries(5)),
      );
      _expectNoBannedCopy([
        if (hints.introHint?.title case final title?) title,
        if (hints.introHint?.body case final body?) body,
        ...hints.sectionHints.map((hint) => hint.body),
        VisibleArchiveProofCopy.archiveWorkspaceHintIntroTitle,
        VisibleArchiveProofCopy.archiveWorkspaceHintIntroBody,
        VisibleArchiveProofCopy.archiveWorkspaceHintNeedsAttentionBody,
        VisibleArchiveProofCopy.archiveWorkspaceHintEvidenceQualityBody,
        VisibleArchiveProofCopy.archiveWorkspaceHintReviewHistoryBody,
        VisibleArchiveProofCopy.archiveWorkspaceHintSectionPrompt,
      ]);
    });
  });

  group('ArchiveWorkspaceHintStore', () {
    test('dismissal persists locally', () async {
      ArchiveWorkspaceHintStore.dismiss(ArchiveWorkspaceHintIds.intro);
      await ArchiveWorkspaceHintStore.flushForTest();
      ArchiveWorkspaceHintStore.resetForTest();
      await ArchiveWorkspaceHintStore.ensureLoaded();

      expect(
        ArchiveWorkspaceHintStore.isDismissed(ArchiveWorkspaceHintIds.intro),
        isTrue,
      );
    });
  });

  group('ArchiveWorkspaceHintCard', () {
    testWidgets('hint can be dismissed', (tester) async {
      var dismissed = false;
      const hint = ArchiveWorkspaceHint(
        hintId: ArchiveWorkspaceHintIds.intro,
        title: VisibleArchiveProofCopy.archiveWorkspaceHintIntroTitle,
        body: VisibleArchiveProofCopy.archiveWorkspaceHintIntroBody,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveWorkspaceHintCard(
              hint: hint,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_workspace_hint_intro')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('archive_workspace_hint_dismiss_intro')),
      );
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });
}
