import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/belief_evidence_trail.dart';
import 'package:voicememory_mobile/features/activation/belief_update_payoff.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/belief_evidence_screen.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/belief_evidence_trail_card.dart';
import 'package:voicememory_mobile/widgets/record/belief_update_payoff_card.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
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

List<JournalEntry> _fourRepeatCapacityEntries() => [
      _voiceEntry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _voiceEntry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _voiceEntry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
      _voiceEntry(
        id: 'e4',
        transcript:
            'The same yes-with-no-capacity pattern showed up again at work today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

List<JournalEntry> _fourDistinctWorkEntries() => _fourRepeatCapacityEntries();

const _bannedWords = [
  'you always',
  'diagnosis',
  'symptom',
  'therapy',
  'mental health condition',
  'pattern found',
  'certain',
];

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

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

BeliefEvidenceTrail _trailFromEntries(List<JournalEntry> entries) =>
    BeliefEvidenceTrailEngine.build(entries: entries);

void main() {
  group('BeliefEvidenceTrailEngine', () {
    test('returns insufficient trail below four usable entries', () {
      final trail = BeliefEvidenceTrailEngine.build(
        entries: _fourDistinctWorkEntries().sublist(0, 2),
      );
      expect(trail.hasEnoughEvidence, isFalse);
      expect(trail.title, VisibleArchiveProofCopy.beliefEvidenceTrailTitle);
      expect(
        trail.insufficientBody,
        VisibleArchiveProofCopy.beliefEvidenceInsufficientBody,
      );
    });

    test('four usable entries includes belief, evidence, and source copy', () {
      final trail = _trailFromEntries(_fourDistinctWorkEntries());
      expect(trail.hasEnoughEvidence, isTrue);
      expect(trail.notConclusionLine, VisibleArchiveProofCopy.beliefEvidenceNotConclusion);
      expect(
        trail.sourceLine,
        'ArchiveMe is using your saved words, not guessing.',
      );
      expect(trail.currentBelief, isNotEmpty);
      expect(trail.whatChangedLine, isNotEmpty);
      expect(trail.evidenceRows.length, greaterThanOrEqualTo(2));
      expect(trail.primaryCta, 'Record if it happens again');
      _expectNoBannedCopy([
        trail.title,
        trail.notConclusionLine!,
        trail.sourceLine!,
        trail.currentBelief!,
        trail.whatChangedLine!,
        ...trail.evidenceRows,
        if (trail.nextActionLine != null) trail.nextActionLine!,
      ]);
    });

    test('degraded entries are excluded from evidence trail', () {
      final trail = BeliefEvidenceTrailEngine.build(
        entries: [
          ..._fourDistinctWorkEntries().sublist(0, 3),
          _degradedVoiceEntry(id: 'e4'),
        ],
      );
      expect(trail.hasEnoughEvidence, isFalse);
    });

    test('weak duplicate entries show still thin uncertainty', () {
      const shared =
          'I felt pressure at work before saying yes again even when I was tired.';
      final trail = BeliefEvidenceTrailEngine.build(
        entries: [
          _voiceEntry(id: 'e1', transcript: shared, createdAt: DateTime(2026, 6, 9)),
          _voiceEntry(id: 'e2', transcript: shared, createdAt: DateTime(2026, 6, 10)),
          _voiceEntry(
            id: 'e3',
            transcript:
                'I noticed the same hurry showing up before I answered anyone at work.',
            createdAt: DateTime(2026, 6, 11),
          ),
          _voiceEntry(
            id: 'e4',
            transcript:
                'The deadline pressure returned, but I caught it earlier this time.',
            createdAt: DateTime(2026, 6, 12),
          ),
        ],
      );
      expect(trail.hasEnoughEvidence, isTrue);
      expect(trail.uncertaintyLine, BeliefEvidenceTrailCopy.evidenceStillThin);
      expect(
        trail.nextActionLine,
        VisibleArchiveProofCopy.beliefEvidenceNextWhenThin,
      );
    });
  });

  group('BeliefEvidenceTrailCard', () {
    testWidgets('renders full trail sections at four entries', (tester) async {
      final trail = _trailFromEntries(_fourDistinctWorkEntries());
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeliefEvidenceTrailCard(
                trail: trail,
                onAddAnother: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('belief_evidence_trail_card')), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.beliefEvidenceNotConclusion), findsOneWidget);
      expect(
        find.text('ArchiveMe is using your saved words, not guessing.'),
        findsOneWidget,
      );
      expect(find.text(VisibleArchiveProofCopy.beliefEvidenceCurrentBeliefLabel), findsOneWidget);
      expect(find.text('What changed'), findsOneWidget);
      expect(find.text('Evidence from your archive'), findsOneWidget);
      expect(find.byKey(const Key('belief_evidence_trail_add_next_label')), findsOneWidget);
      expect(find.byKey(const Key('belief_evidence_trail_add_cta')), findsOneWidget);
      expect(find.byKey(const Key('belief_evidence_trail_evidence_0')), findsOneWidget);
      _expectNoBannedCopy(_visibleText(tester));
    });

    testWidgets('renders insufficient state gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BeliefEvidenceTrailCard(
              trail: BeliefEvidenceTrail.insufficient(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('belief_evidence_trail_insufficient')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your archive needs more moments before it can show an evidence trail.',
        ),
        findsOneWidget,
      );
    });
  });

  group('BeliefEvidenceScreen', () {
    testWidgets('renders trail with preview data', (tester) async {
      final trail = _trailFromEntries(_fourDistinctWorkEntries());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BeliefEvidenceScreen(previewTrail: trail),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('belief_evidence_screen_title')), findsOneWidget);
      expect(find.text('Evidence behind this belief'), findsWidgets);
      expect(find.text(VisibleArchiveProofCopy.beliefEvidenceCurrentBeliefLabel), findsOneWidget);
      expect(find.byKey(const Key('belief_evidence_trail_add_cta')), findsOneWidget);
      _expectNoBannedCopy(_visibleText(tester));
    });

    testWidgets('preview insufficient trail shows graceful empty copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BeliefEvidenceScreen(
            previewTrail: BeliefEvidenceTrail.insufficient(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('belief_evidence_trail_insufficient_body')), findsOneWidget);
    });
  });

  group('View evidence navigation', () {
    testWidgets('Record if it happens again routes to record not evidence', (
      tester,
    ) async {
      const payoff = BeliefUpdatePayoff(
        title: BeliefUpdatePayoffCopy.title,
        body: BeliefUpdatePayoffCopy.bodyChanged,
        currentBelief: VisibleArchiveProofCopy.beliefUpdateWorkBelief,
        evidenceRows: ['snippet one', 'snippet two'],
        whatChangedLine: VisibleArchiveProofCopy.beliefUpdateChangeNewContext,
        beliefChanged: true,
        evidenceWeak: false,
        primaryCta: 'Record if it happens again',
        secondaryCta: 'View evidence',
      );

      var recordOpened = false;
      var evidenceOpened = false;
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: BeliefUpdatePayoffCard(
                  payoff: payoff,
                  onAddAnother: () {
                    recordOpened = true;
                    context.go('/record');
                  },
                  onViewEvidence: () {
                    evidenceOpened = true;
                    context.push(BeliefEvidenceNavigation.route);
                  },
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) =>
                const Scaffold(body: Text('RECORD_SCREEN')),
          ),
          GoRoute(
            path: BeliefEvidenceNavigation.route,
            builder: (context, state) => BeliefEvidenceScreen(
              previewTrail: _trailFromEntries(_fourDistinctWorkEntries()),
            ),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      final addCta = find.byKey(const Key('belief_update_payoff_add_cta'));
      await tester.ensureVisible(addCta);
      await tester.tap(addCta);
      await tester.pumpAndSettle();

      expect(recordOpened, isTrue);
      expect(evidenceOpened, isFalse);
      expect(find.text('RECORD_SCREEN'), findsOneWidget);
      expect(find.byKey(const Key('belief_evidence_trail_card')), findsNothing);
    });

    testWidgets('View evidence CTA pushes belief evidence route', (
      tester,
    ) async {
      const payoff = BeliefUpdatePayoff(
        title: BeliefUpdatePayoffCopy.title,
        body: BeliefUpdatePayoffCopy.bodyChanged,
        currentBelief: VisibleArchiveProofCopy.beliefUpdateWorkBelief,
        evidenceRows: ['snippet one', 'snippet two'],
        whatChangedLine: VisibleArchiveProofCopy.beliefUpdateChangeNewContext,
        beliefChanged: true,
        evidenceWeak: false,
        primaryCta: 'Record if it happens again',
        secondaryCta: 'View evidence',
      );

      var evidenceOpened = false;
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: BeliefUpdatePayoffCard(
                  payoff: payoff,
                  onAddAnother: () {},
                  onViewEvidence: () {
                    evidenceOpened = true;
                    context.push(BeliefEvidenceNavigation.route);
                  },
                ),
              ),
            ),
          ),
          GoRoute(
            path: BeliefEvidenceNavigation.route,
            builder: (context, state) => BeliefEvidenceScreen(
              previewTrail: _trailFromEntries(_fourDistinctWorkEntries()),
            ),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      final cta = find.byKey(const Key('belief_update_payoff_view_evidence_cta'));
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(evidenceOpened, isTrue);
      expect(find.byKey(const Key('belief_evidence_trail_card')), findsOneWidget);
      expect(find.byKey(const Key('belief_update_payoff_card')), findsNothing);
    });

    testWidgets('Record if it happens again and View evidence use different routes', (
      tester,
    ) async {
      const payoff = BeliefUpdatePayoff(
        title: BeliefUpdatePayoffCopy.title,
        body: BeliefUpdatePayoffCopy.bodyStillBuilding,
        currentBelief: VisibleArchiveProofCopy.beliefUpdateWorkBelief,
        evidenceRows: ['snippet one', 'snippet two'],
        whatChangedLine: VisibleArchiveProofCopy.beliefUpdateChangeEasierCompare,
        beliefChanged: false,
        evidenceWeak: true,
        primaryCta: 'Record if it happens again',
        secondaryCta: 'View evidence',
      );

      String? lastRoute;
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: BeliefUpdatePayoffCard(
                  payoff: payoff,
                  onAddAnother: () {
                    lastRoute = '/record';
                    context.go('/record');
                  },
                  onViewEvidence: () {
                    lastRoute = BeliefEvidenceNavigation.route;
                    context.push(BeliefEvidenceNavigation.route);
                  },
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) =>
                const Scaffold(body: Text('RECORD_SCREEN')),
          ),
          GoRoute(
            path: BeliefEvidenceNavigation.route,
            builder: (context, state) => const Scaffold(
              body: Text('EVIDENCE_SCREEN'),
            ),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('belief_update_payoff_add_cta')));
      await tester.pumpAndSettle();
      expect(lastRoute, '/record');

      router.go('/start');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('belief_update_payoff_view_evidence_cta')),
      );
      await tester.pumpAndSettle();
      expect(lastRoute, BeliefEvidenceNavigation.route);
      expect(lastRoute, isNot('/record'));
    });

    test('belief evidence route constant is stable', () {
      expect(BeliefEvidenceNavigation.route, '/belief-evidence');
    });
  });
}
