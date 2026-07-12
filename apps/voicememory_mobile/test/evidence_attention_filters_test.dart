import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/archive_evidence_map.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/activation/evidence_attention_filters.dart';
import 'package:voicememory_mobile/features/activation/insight_quality_dashboard.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/evidence_attention_filters_card.dart';

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

JournalEntry _blankVoiceEntry({
  required String id,
  String? captureContextTag,
}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript: '   ',
      durationSeconds: 30,
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

JournalEntry _degradedVoiceEntry({
  String id = 'd1',
  String? captureContextTag,
}) =>
    JournalEntry(
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

List<EvidenceAttentionFilterKind> _kinds(EvidenceAttentionFilters filters) =>
    filters.filters.map((filter) => filter.kind).toList();

void main() {
  setUp(ArchiveInsightFeedbackStore.resetForTest);

  group('EvidenceAttentionFiltersEngine', () {
    test('no attention states hides card', () {
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
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
        ],
      );
      expect(filters.showCard, isFalse);
    });

    test('untagged usable entries show Untagged chip', () {
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
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
        ],
      );
      expect(_kinds(filters), contains(EvidenceAttentionFilterKind.untagged));
      expect(
        filters.filters.firstWhere(
          (filter) => filter.kind == EvidenceAttentionFilterKind.untagged,
        ).resolveRoute(),
        ArchiveEvidenceMapNavigation.contextPath(ArchiveEvidenceMapRowIds.untagged),
      );
    });

    test('single tagged context shows Same context chip', () {
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
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
        ],
      );
      expect(_kinds(filters), contains(EvidenceAttentionFilterKind.sameContext));
    });

    test('contexts with one moment show Thin contexts chip', () {
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
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
        ],
      );
      final thin = filters.filters.firstWhere(
        (filter) => filter.kind == EvidenceAttentionFilterKind.thinContexts,
      );
      expect(thin.contextTagId, CaptureContextTagIds.home);
      expect(
        thin.resolveRoute(),
        ArchiveEvidenceMapNavigation.contextPath(CaptureContextTagIds.home),
      );
    });

    test('correction notes show Corrections chip', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        'More about family than work.',
      );
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      expect(_kinds(filters), contains(EvidenceAttentionFilterKind.corrections));
      expect(
        filters.filters
            .firstWhere(
              (filter) => filter.kind == EvidenceAttentionFilterKind.corrections,
            )
            .resolveRoute(),
        InsightQualityNavigation.route,
      );
    });

    test('Not quite feedback shows Corrections chip', () {
      ArchiveInsightFeedbackStore.record(
        'weeklyReview',
        ArchiveInsightFeedbackChoice.notQuite,
      );
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      expect(_kinds(filters), contains(EvidenceAttentionFilterKind.corrections));
    });

    test('hidden targets show Hidden chip', () {
      ArchiveInsightFeedbackStore.hide('weeklyReview');
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      expect(_kinds(filters), contains(EvidenceAttentionFilterKind.hidden));
      expect(
        filters.filters
            .firstWhere((filter) => filter.kind == EvidenceAttentionFilterKind.hidden)
            .resolveRoute(),
        InsightQualityNavigation.route,
      );
    });

    test('degraded and blank entries do not trigger usable evidence chips', () {
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
          _degradedVoiceEntry(captureContextTag: CaptureContextTagIds.work),
          _blankVoiceEntry(
            id: 'blank',
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      expect(filters.showCard, isFalse);
    });

    test('share-safe proof does not include filter state or tags', () {
      ArchiveInsightFeedbackStore.hide('weeklyReview');
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: [
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
        ],
      );
      final shareText = proof.lines.join('\n').toLowerCase();
      expect(shareText, isNot(contains('needs attention')));
      expect(shareText, isNot(contains('thin contexts')));
      expect(shareText, isNot(contains('same context')));
    });

    test('copy avoids banned language', () {
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
          ),
        ],
      );
      _expectNoBannedCopy([
        filters.title,
        ...filters.filters.map((filter) => filter.label),
        VisibleArchiveProofCopy.evidenceAttentionFiltersTitle,
        VisibleArchiveProofCopy.evidenceAttentionFilterUntagged,
        VisibleArchiveProofCopy.evidenceAttentionFilterThinContexts,
        VisibleArchiveProofCopy.evidenceAttentionFilterSameContext,
        VisibleArchiveProofCopy.evidenceAttentionFilterCorrections,
        VisibleArchiveProofCopy.evidenceAttentionFilterHidden,
      ]);
    });
  });

  group('EvidenceAttentionFiltersCard navigation', () {
    testWidgets('tapping Untagged routes to untagged drilldown', (tester) async {
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'Another untagged moment before I could leave for the day moment one.',
          ),
        ],
      );
      late String location;

      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: EvidenceAttentionFiltersCard(
                filters: filters,
                onFilterTap: (filter) {
                  final route = filter.resolveRoute();
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

      await tester.tap(find.byKey(const Key('evidence_attention_filter_untagged')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(location, '/archive-evidence-map/context/untagged');
    });

    testWidgets('tapping Corrections routes to Insight Quality', (tester) async {
      ArchiveInsightFeedbackStore.record(
        'weeklyReview',
        ArchiveInsightFeedbackChoice.notQuite,
      );
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      late String location;

      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: EvidenceAttentionFiltersCard(
                filters: filters,
                onFilterTap: (filter) {
                  final route = filter.resolveRoute();
                  if (route != null) context.push(route);
                },
              ),
            ),
          ),
          GoRoute(
            path: InsightQualityNavigation.route,
            builder: (context, state) {
              location = state.uri.toString();
              return const Scaffold(body: Text('insight quality'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('evidence_attention_filter_corrections')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(location, InsightQualityNavigation.route);
    });

    testWidgets('tapping Hidden routes to Insight Quality', (tester) async {
      ArchiveInsightFeedbackStore.hide('weeklyReview');
      final filters = EvidenceAttentionFiltersEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      late String location;

      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: EvidenceAttentionFiltersCard(
                filters: filters,
                onFilterTap: (filter) {
                  final route = filter.resolveRoute();
                  if (route != null) context.push(route);
                },
              ),
            ),
          ),
          GoRoute(
            path: InsightQualityNavigation.route,
            builder: (context, state) {
              location = state.uri.toString();
              return const Scaffold(body: Text('insight quality'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('evidence_attention_filter_hidden')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(location, InsightQualityNavigation.route);
    });
  });
}
