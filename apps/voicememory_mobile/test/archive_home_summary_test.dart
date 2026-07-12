import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/archive_home_summary_card.dart';
import 'package:voicememory_mobile/widgets/archive/post_save_archive_home_nudge_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_save_evidence_card.dart';

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

List<JournalEntry> _entries(int count) => List.generate(
      count,
      (i) => _voiceEntry(
        id: 'e$i',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired moment $i.',
        createdAt: DateTime(2026, 6, 9 + i, 12),
      ),
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
  'share to unlock',
  'voicememory',
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
  group('ArchiveHomeSummaryEngine', () {
    test('0 entries shows archive start copy without belief claims', () {
      final summary = ArchiveHomeSummaryEngine.build(entries: const []);
      expect(summary.stage, ArchiveHomeStage.empty);
      expect(summary.title, VisibleArchiveProofCopy.archiveHomeEmptyTitle);
      expect(summary.body, contains(VisibleArchiveProofCopy.firstRunBuildingLine));
      expect(summary.footnoteLine, VisibleArchiveProofCopy.archiveHomeEmptySampleHint);
      expect(summary.primaryCta, 'Record a moment');
      expect(summary.secondaryCta, 'Type instead');
      expect(summary.primaryAction, ArchiveHomeAction.record);
      expect(summary.suppressDuplicatePayoffCards, isFalse);
      _expectNoBannedCopy([summary.title, summary.body, summary.footnoteLine!]);
    });

    test('1 entry shows one-piece evidence without repeat claims', () {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(1));
      expect(summary.stage, ArchiveHomeStage.one);
      expect(summary.title, VisibleArchiveProofCopy.archiveHomeOneTitle);
      expect(summary.body, VisibleArchiveProofCopy.archiveHomeOneBody);
      expect(summary.body.toLowerCase(), isNot(contains('repeat')));
      expect(summary.body.toLowerCase(), isNot(contains('pattern')));
      expect(summary.footnoteLine, VisibleArchiveProofCopy.firstRunBeliefsNotConclusionsLine);
      expect(summary.evidenceRows, contains('1 saved moment'));
      expect(summary.nextActionLine, VisibleArchiveProofCopy.secondMomentWhyLine);
      expect(summary.primaryAction, ArchiveHomeAction.addMoment);
      expect(summary.suppressDuplicatePayoffCards, isTrue);
    });

    test('2 entries shows two-moments-to-compare copy', () {
      final summary = ArchiveHomeSummaryEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            createdAt: DateTime(2026, 6, 9, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'I spent the afternoon organizing photos from last summer at the beach.',
            createdAt: DateTime(2026, 6, 10, 12),
          ),
        ],
      );
      expect(summary.stage, ArchiveHomeStage.two);
      expect(summary.title, 'ArchiveMe has two moments to compare.');
      expect(summary.body, contains('No clear repeat yet'));
      expect(summary.suppressDuplicatePayoffCards, isTrue);
    });

    test('3 entries shows belief-starting copy with not-conclusion framing', () {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(3));
      expect(summary.stage, ArchiveHomeStage.three);
      expect(summary.title, 'ArchiveMe is starting to form a belief.');
      expect(summary.body, contains('saved words suggest so far'));
      expect(
        summary.currentBeliefLine,
        VisibleArchiveProofCopy.threeEntryBeliefCurrentBeliefLine,
      );
      expect(summary.secondaryCta, 'View archive');
      expect(summary.secondaryAction, ArchiveHomeAction.viewArchive);
      expect(summary.suppressDuplicatePayoffCards, isTrue);
      _expectNoBannedCopy([summary.title, summary.body, summary.footnoteLine!]);
    });

    test('4 entries shows belief-updated copy and add moment primary action', () {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(4));
      expect(summary.stage, ArchiveHomeStage.four);
      expect(summary.title, VisibleArchiveProofCopy.beliefUpdateTitle);
      expect(summary.primaryCta, 'Add one more moment');
      expect(summary.primaryAction, ArchiveHomeAction.addMoment);
      expect(summary.secondaryCta, 'View evidence');
      expect(summary.secondaryAction, ArchiveHomeAction.viewEvidence);
      expect(summary.currentBeliefLine, isNotEmpty);
      expect(summary.evidenceRows.length, greaterThanOrEqualTo(2));
      expect(summary.suppressDuplicatePayoffCards, isTrue);
    });

    test('5+ entries shows weekly review copy and view review action', () {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(5));
      expect(summary.stage, ArchiveHomeStage.fivePlus);
      expect(summary.title, 'Your archive review');
      expect(summary.subtitle, 'What your saved words are starting to show.');
      expect(summary.primaryCta, 'View review');
      expect(summary.primaryAction, ArchiveHomeAction.viewReview);
      expect(summary.showShareProof, isTrue);
      expect(summary.suppressDuplicatePayoffCards, isTrue);
    });

    test('degraded entries do not count toward ladder', () {
      final summary = ArchiveHomeSummaryEngine.build(
        entries: [
          ..._entries(2),
          _degradedVoiceEntry(id: 'e3'),
        ],
      );
      expect(summary.stage, ArchiveHomeStage.two);
    });

    test('first-run framing lines appear through early ladder stages', () {
      for (final count in [0, 1, 2]) {
        final summary = ArchiveHomeSummaryEngine.build(
          entries: count == 0 ? const [] : _entries(count),
        );
        final visible = [
          summary.title,
          summary.body,
          summary.footnoteLine,
        ].whereType<String>();
        if (count == 0) {
          expect(
            visible,
            anyElement(contains(VisibleArchiveProofCopy.firstRunBuildingLine)),
            reason: 'count $count should mention saved words',
          );
        }
        if (count == 1) {
          expect(
            visible,
            anyElement(contains('first piece of evidence')),
            reason: 'count $count should stay evidence-first',
          );
        }
        if (count == 2) {
          expect(
            visible,
            anyElement(contains('compare')),
            reason: 'count $count should mention compare',
          );
        }
        _expectNoBannedCopy(visible);
      }
      final three = ArchiveHomeSummaryEngine.build(entries: _entries(3));
      expect(three.body.toLowerCase(), contains('saved words suggest so far'));
    });
  });

  group('ArchiveHomeSummaryCard', () {
    testWidgets('renders command center sections', (tester) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(4));
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveHomeSummaryCard(
                summary: summary,
                onPrimary: () {},
                onSecondary: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('archive_home_summary_card')), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.archiveHomeBeliefLabel), findsOneWidget);
      expect(find.text('What changed'), findsOneWidget);
      expect(find.text('Evidence from your archive'), findsOneWidget);
      expect(find.text('What to add next'), findsOneWidget);
      expect(find.byKey(const Key('archive_home_summary_primary_cta')), findsOneWidget);
    });

    testWidgets('five entries can embed share-safe proof', (tester) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(5));
      expect(summary.showShareProof, isTrue);

      await tester.binding.setSurfaceSize(const Size(390, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveHomeSummaryCard(
                summary: summary,
                onPrimary: () {},
                shareProof: const ShareableArchiveProofEngine()
                    .buildFromJournal(entries: _entries(5)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('shareable_archive_proof_card')), findsOneWidget);
      expect(find.text('No private entries shared.'), findsOneWidget);
    });

    testWidgets('first save card exposes view archive callback', (tester) async {
      var viewedArchive = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () => viewedArchive = true,
              onRecordAnother: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('first_save_view_archive_cta')));
      await tester.pump();
      expect(viewedArchive, isTrue);
    });

    testWidgets('post-save nudge routes to archive home copy at two entries', (
      tester,
    ) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(2));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveArchiveHomeNudgeCard(
              summary: summary,
              onViewArchive: () {},
              onAddMoment: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('post_save_view_archive_cta')), findsOneWidget);
      expect(find.text('View archive'), findsOneWidget);
      expect(find.text(summary.title), findsOneWidget);
    });

    testWidgets('four-entry summary Add one more moment routes to record', (
      tester,
    ) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(4));
      var recordOpened = false;
      var evidenceOpened = false;

      final router = GoRouter(
        initialLocation: '/patterns',
        routes: [
          GoRoute(
            path: '/patterns',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: ArchiveHomeSummaryCard(
                  summary: summary,
                  onPrimary: () {
                    recordOpened = true;
                    context.go('/record');
                  },
                  onSecondary: () {
                    evidenceOpened = true;
                    context.push('/belief-evidence');
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
            path: '/belief-evidence',
            builder: (context, state) =>
                const Scaffold(body: Text('EVIDENCE_SCREEN')),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('archive_home_summary_primary_cta')));
      await tester.pumpAndSettle();
      expect(recordOpened, isTrue);
      expect(evidenceOpened, isFalse);
      expect(find.text('RECORD_SCREEN'), findsOneWidget);

      recordOpened = false;
      router.go('/patterns');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('archive_home_summary_secondary_cta')));
      await tester.pumpAndSettle();
      expect(evidenceOpened, isTrue);
      expect(recordOpened, isFalse);
      expect(find.text('EVIDENCE_SCREEN'), findsOneWidget);
    });

    testWidgets('four-entry post-save nudge always labels add moment CTA', (
      tester,
    ) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(4));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveArchiveHomeNudgeCard(
              summary: summary,
              onViewArchive: () {},
              onAddMoment: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add one more moment'), findsOneWidget);
      expect(find.text('View evidence'), findsNothing);
    });
  });
}
