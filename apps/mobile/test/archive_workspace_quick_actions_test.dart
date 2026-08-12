import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/archive_health_action_plan.dart';
import 'package:archiveme_mobile/features/activation/archive_health_score.dart';
import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';

import 'support/flush_sensitive_stores.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_layout.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_quick_actions.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/activation/context_insights.dart';
import 'package:archiveme_mobile/features/activation/evidence_attention_filters.dart';
import 'package:archiveme_mobile/features/activation/insight_quality_dashboard.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/archive_workspace_quick_actions_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

ArchiveWorkspaceQuickActions _quickActions(List<JournalEntry> entries) {
  final archiveHome = ArchiveHomeSummaryEngine.build(entries: entries);
  final evidenceMap = ArchiveEvidenceMapEngine.build(entries: entries);
  final weeklyReview = entries.length >= 5
      ? WeeklyArchiveReviewEngine.build(entries: entries)
      : null;
  final shareProof = const ShareableArchiveProofEngine().buildFromJournal(
    entries: entries,
  );
  final workspaceLayout = ArchiveWorkspaceLayoutEngine.build(
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
    weeklyReview: weeklyReview,
    shareProof: shareProof,
  );

  return ArchiveWorkspaceQuickActionsEngine.build(
    entries: entries,
    archiveHome: archiveHome,
    workspaceLayout: workspaceLayout,
    evidenceMapVisible: evidenceMap.showCard,
    weeklyReview: weeklyReview,
    shareProof: shareProof,
  );
}

List<ArchiveWorkspaceQuickActionKind> _kinds(
  ArchiveWorkspaceQuickActions actions,
) => actions.actions.map((action) => action.kind).toList();

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
  setUp(() async => ArchiveInsightFeedbackStore.resetForTest());

  tearDown(() async {
    await flushSensitiveStoresForTest();
  });

  group('ArchiveWorkspaceQuickActionsEngine', () {
    test('0 entries does not show quick actions', () {
      final actions = _quickActions(const []);
      expect(actions.showCard, isFalse);
    });

    test('1 entry does not duplicate archive home add-moment guidance', () {
      final actions = _quickActions(_distinctWorkEntries(1));
      expect(actions.showCard, isFalse);
    });

    test('2 entries with untagged usable entries shows Tag untagged entries', () {
      final actions = _quickActions([
        _voiceEntry(
          id: 'e1',
          transcript:
              'I felt pressure at work before saying yes again even when I was tired moment one.',
          captureContextTag: CaptureContextTagIds.work,
        ),
        _voiceEntry(
          id: 'e2',
          transcript:
              'Another untagged moment before I could leave for the day moment two.',
          createdAt: DateTime(2026, 6, 11),
        ),
      ]);
      expect(_kinds(actions), [ArchiveWorkspaceQuickActionKind.tagUntagged]);
      expect(
        actions.actions.first.resolveRoute(),
        ArchiveEvidenceMapNavigation.contextPath(
          ArchiveEvidenceMapRowIds.untagged,
        ),
      );
    });

    test(
      '2 entries does not duplicate archive home add-moment quick action',
      () {
        final actions = _quickActions(_distinctWorkEntries(2));
        expect(
          _kinds(actions),
          isNot(contains(ArchiveWorkspaceQuickActionKind.addMoment)),
        );
      },
    );

    test('3+ entries shows View evidence map', () {
      final actions = _quickActions(_distinctWorkEntries(3));
      expect(
        _kinds(actions),
        contains(ArchiveWorkspaceQuickActionKind.viewEvidenceMap),
      );
      final mapAction = actions.actions.firstWhere(
        (action) =>
            action.kind == ArchiveWorkspaceQuickActionKind.viewEvidenceMap,
      );
      expect(mapAction.resolveRoute(), '/archive-belief');
    });

    test('corrections and Not quite show Review corrections', () {
      ArchiveInsightFeedbackStore.record(
        'weeklyReview',
        ArchiveInsightFeedbackChoice.notQuite,
      );
      final actions = _quickActions(_distinctWorkEntries(3));
      expect(
        _kinds(actions),
        contains(ArchiveWorkspaceQuickActionKind.reviewCorrections),
      );
      final corrections = actions.actions.firstWhere(
        (action) =>
            action.kind == ArchiveWorkspaceQuickActionKind.reviewCorrections,
      );
      expect(corrections.resolveRoute(), InsightQualityNavigation.route);
    });

    test('hidden insights do not create a separate quick action', () {
      ArchiveInsightFeedbackStore.hide('weeklyReview');
      final actions = _quickActions(_distinctWorkEntries(3));
      expect(
        _kinds(actions),
        isNot(contains(ArchiveWorkspaceQuickActionKind.reviewCorrections)),
      );
    });

    test('5+ entries shows View weekly review', () {
      final actions = _quickActions(_distinctWorkEntries(5));
      expect(
        _kinds(actions),
        contains(ArchiveWorkspaceQuickActionKind.viewWeeklyReview),
      );
      final reviewAction = actions.actions.firstWhere(
        (action) =>
            action.kind == ArchiveWorkspaceQuickActionKind.viewWeeklyReview,
      );
      expect(reviewAction.resolveRoute(), WeeklyArchiveReviewNavigation.route);
    });

    test('max 3 actions are visible', () {
      ArchiveInsightFeedbackStore.record(
        'weeklyReview',
        ArchiveInsightFeedbackChoice.notQuite,
      );
      final actions = _quickActions([
        ..._distinctWorkEntries(3),
        _voiceEntry(
          id: 'e4',
          transcript:
              'Another untagged moment before I could leave for the day moment four.',
          createdAt: DateTime(2026, 6, 13),
        ),
      ]);
      expect(actions.actions.length, lessThanOrEqualTo(3));
    });

    test('actions appear in stable priority order', () {
      ArchiveInsightFeedbackStore.record(
        'weeklyReview',
        ArchiveInsightFeedbackChoice.notQuite,
      );
      final actions = _quickActions([
        _voiceEntry(
          id: 'e1',
          transcript:
              'I felt pressure at work before saying yes again even when I was tired moment one.',
          captureContextTag: CaptureContextTagIds.work,
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
              'Home felt loud before I could settle into the evening moment three.',
          createdAt: DateTime(2026, 6, 10),
          captureContextTag: CaptureContextTagIds.home,
        ),
      ]);
      expect(_kinds(actions), [
        ArchiveWorkspaceQuickActionKind.tagUntagged,
        ArchiveWorkspaceQuickActionKind.reviewCorrections,
        ArchiveWorkspaceQuickActionKind.viewEvidenceMap,
      ]);
    });

    test('degraded entries do not trigger usable evidence cleanup', () {
      final actions = _quickActions([
        _degradedVoiceEntry(captureContextTag: CaptureContextTagIds.work),
        _voiceEntry(
          id: 'e1',
          transcript:
              'I felt pressure at work before saying yes again even when I was tired moment one.',
          captureContextTag: CaptureContextTagIds.work,
        ),
      ]);
      expect(
        _kinds(actions),
        isNot(contains(ArchiveWorkspaceQuickActionKind.tagUntagged)),
      );
    });

    test(
      'share proof action stays hidden when archive home already shows proof',
      () {
        final actions = _quickActions(_distinctWorkEntries(5));
        expect(
          _kinds(actions),
          isNot(contains(ArchiveWorkspaceQuickActionKind.shareProofSafely)),
        );
      },
    );

    test('copy avoids banned language', () {
      final actions = _quickActions(_distinctWorkEntries(5));
      _expectNoBannedCopy([
        actions.title,
        ...actions.actions.map((action) => action.label),
        VisibleArchiveProofCopy.archiveWorkspaceQuickActionsTitle,
        VisibleArchiveProofCopy.archiveWorkspaceQuickActionAddMoment,
        VisibleArchiveProofCopy.archiveWorkspaceQuickActionTagUntagged,
        VisibleArchiveProofCopy.archiveWorkspaceQuickActionReviewCorrections,
        VisibleArchiveProofCopy.archiveWorkspaceQuickActionViewEvidenceMap,
        VisibleArchiveProofCopy.archiveWorkspaceQuickActionViewWeeklyReview,
        VisibleArchiveProofCopy.archiveWorkspaceQuickActionShareProofSafely,
      ]);
    });
  });

  group('ArchiveWorkspaceQuickActionsCard navigation', () {
    testWidgets('tapping Tag untagged routes to untagged drilldown', (
      tester,
    ) async {
      final actions = _quickActions([
        _voiceEntry(
          id: 'e1',
          transcript:
              'I felt pressure at work before saying yes again even when I was tired moment one.',
          captureContextTag: CaptureContextTagIds.work,
        ),
        _voiceEntry(
          id: 'e2',
          transcript:
              'Another untagged moment before I could leave for the day moment two.',
          createdAt: DateTime(2026, 6, 11),
        ),
      ]);
      late String location;

      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: ArchiveWorkspaceQuickActionsCard(
                quickActions: actions,
                onActionTap: (action) {
                  final route = action.resolveRoute();
                  if (route != null) context.push(route);
                },
              ),
            ),
          ),
          GoRoute(
            path: ArchiveEvidenceMapNavigation.contextRoute,
            builder: (context, state) {
              location = state.uri.toString();
              return const Scaffold(body: Text('drilldown'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('archive_workspace_quick_action_tagUntagged')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(location, '/archive-evidence-map/context/untagged');
    });
  });
}