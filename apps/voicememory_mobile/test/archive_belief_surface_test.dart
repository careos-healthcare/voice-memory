import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_model.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_change_timeline_metrics_store.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_demo_preview_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_demo_preview_resolver.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_display_copy_guard.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_paid_value_proof_source.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/patterns/patterns_stack_policy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/belief_detail_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_belief_surface_card.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_demo_preview_card.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_timeline_truth_feedback_card.dart';

JournalEntry _entry({
  required String id,
  String transcript = '',
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
      transcript: transcript,
      durationSeconds: 30,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

ArchiveBeliefThread _belief({
  String currentBelief =
      'You keep returning to control when things feel uncertain.',
  String evidenceLine =
      'Seen across 4 recordings. Strongest signal: work pressure.',
  String whatChanged =
      'This softened after you tried writing the first next step.',
}) =>
    ArchiveBeliefThread(
      hasEnoughData: true,
      suggestionId: 'test-belief',
      currentBelief: currentBelief,
      evidenceLine: evidenceLine,
      whatChanged: whatChanged,
      whatToTest: 'Notice before you agree.',
      timeline: const [],
      confidenceBand: ArchiveConfidenceBand.returningThread,
    );

void main() {
  group('ArchiveDisplayCopyGuard', () {
    test('rejects banned overclaiming terms', () {
      expect(
        ArchiveDisplayCopyGuard.passes('This is a therapy recommendation'),
        isFalse,
      );
      expect(
        ArchiveDisplayCopyGuard.passes(
          'Seen across 4 recordings. Strongest signal: work pressure.',
        ),
        isTrue,
      );
    });

    test('belief surface copy stays evidence-based not advisory', () {
      final surfaceCopy = [
        ArchiveBeliefSurfaceCopy.headline,
        ArchiveBeliefSurfaceCopy.evidenceLabel,
        ArchiveBeliefSurfaceCopy.watchingLabel,
        ArchiveBeliefSurfaceCopy.previewBadge,
      ].join(' ').toLowerCase();

      expect(surfaceCopy, contains('evidence'));
      expect(surfaceCopy, contains('still watching'));
      expect(surfaceCopy, isNot(contains('you should')));
      expect(surfaceCopy, isNot(contains('this means')));

      final proBridgeCopy = [
        ArchiveBeliefThreadCopy.proBridgeBody,
        ArchiveBeliefThreadCopy.whyPro,
      ].join(' ').toLowerCase();
      expect(proBridgeCopy, contains('evidence'));
      expect(proBridgeCopy, isNot(contains('coaching plan')));
      expect(proBridgeCopy, isNot(contains('you should')));

      for (final line in [
        ArchiveBeliefSurfaceCopy.previewBadge,
        ArchiveBeliefThreadCopy.proBridgeBody,
        ArchiveBeliefThreadCopy.whyPro,
      ]) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('ArchiveBeliefSurfaceSource', () {
    test('zero entries returns static empty preview', () {
      final surface = const ArchiveBeliefSurfaceSource().resolve([]);
      expect(surface.shouldShow, isTrue);
      expect(surface.isPreview, isTrue);
      expect(surface.beliefSummary, contains('Not enough evidence yet'));
    });

    test('builds belief from real capacity repeat entries', () {
      final surface = const ArchiveBeliefSurfaceSource().resolve(
        [
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
        _entry(
          id: 'c',
          createdAt: DateTime(2026, 6, 3, 12),
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
        ),
      ],
        viewingConfirmedRepeatOrTimeline: true,
      );

      expect(surface.shouldShow, isTrue);
      expect(surface.isPreview, isFalse);
      expect(surface.isPrimaryAfterFirstProof, isTrue);
      expect(surface.headline, ArchiveBeliefSurfaceCopy.headline);
      expect(surface.evidencePhrases, isNotEmpty);
      expect(ArchiveDisplayCopyGuard.passes(surface.beliefSummary), isTrue);
    });

    test('weak entry count uses preview cautious copy', () {
      final surface = const ArchiveBeliefSurfaceSource().resolve([
        _entry(
          id: 'a',
          transcript:
              'Work pressure built before I could rest tonight after the deadline.',
        ),
      ]);

      expect(surface.shouldShow, isTrue);
      expect(surface.isPreview, isTrue);
      expect(
        surface.beliefSummary,
        ArchiveDemoPreviewCopy.oneEntryPatternHint,
      );
      expect(surface.headline, ArchiveBeliefSurfaceCopy.headlineStarting);
    });
  });

  group('ArchiveBeliefSurfaceCard', () {
    testWidgets('shows belief, evidence, what changed, and record next', (
      tester,
    ) async {
      final surface = ArchiveBeliefSurfaceSource().resolve(
        [
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
        _entry(
          id: 'c',
          createdAt: DateTime(2026, 6, 3, 12),
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
        ),
      ],
        viewingConfirmedRepeatOrTimeline: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveBeliefSurfaceCard(
                surface: surface,
                onRecordNext: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('archive_belief_proof_primary_card')), findsOneWidget);
      expect(find.text(ArchiveBeliefSurfaceCopy.headline), findsOneWidget);
      expect(find.text(ArchiveBeliefSurfaceCopy.evidenceLabel), findsOneWidget);
      if (surface.evidencePhrases.isNotEmpty) {
        expect(
          find.byKey(
            Key(
              'archive_belief_surface_evidence_phrase_${surface.evidencePhrases.first}',
            ),
          ),
          findsOneWidget,
        );
      }
      if (surface.watchingNextLine != null) {
        expect(find.text(ArchiveBeliefSurfaceCopy.watchingLabel), findsOneWidget);
      }
      expect(find.byKey(const Key('archive_belief_surface_record_next')), findsOneWidget);
    });
  });

  group('ArchiveDemoPreviewResolver', () {
    test('one entry shows watch preview not conclusion', () {
      final preview = const ArchiveDemoPreviewResolver().resolve([
        _entry(
          id: 'a',
          transcript:
              'Work pressure built before I could rest tonight after the deadline.',
        ),
      ]);

      expect(preview.shouldShow, isTrue);
      expect(preview.patternFirstSeen, contains('Not enough evidence yet'));
    });
  });

  group('ArchiveTimelineTruthFeedbackCard', () {
    testWidgets('persists yes feedback locally', (tester) async {
      final prefs = _MemoryPrefs();
      final store = ArchiveChangeTimelineMetricsStore(prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveTimelineTruthFeedbackCard(store: store),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('archive_timeline_truth_yes')));
      await tester.pump();

      final metrics = await store.load();
      expect(metrics.truthFeedback, ArchiveTimelineTruthFeedback.yes);
      expect(metrics.timelineViewed, isFalse);
    });
  });

  group('decidePatternsStack proof order', () {
    test('timeline appears before pattern profile radar', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: true,
        hasNextCheck: false,
        hasArchiveCleanView: false,
        hasPatternProfile: true,
        hasRangeReview: true,
        hasArchiveCompression: false,
        hasTimeline: true,
        hasProgress: true,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: true,
      );

      expect(d.includes(PatternsSectionType.timeline), isTrue);
      expect(
        d.sections.indexOf(PatternsSectionType.timeline),
        lessThan(d.sections.indexOf(PatternsSectionType.patternProfile)),
      );
      expect(d.suppressSeparateTimelineCard, isFalse);
    });

    test('manual navigation appears after radar and experiment', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: true,
        hasNextCheck: false,
        hasArchiveCleanView: true,
        hasPatternProfile: true,
        hasRangeReview: true,
        hasArchiveCompression: true,
        hasTimeline: true,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: true,
      );

      expect(
        d.sections.indexOf(PatternsSectionType.patternProfile),
        lessThan(d.sections.indexOf(PatternsSectionType.archiveNavigation)),
      );
      expect(
        d.sections.indexOf(PatternsSectionType.rangeReview),
        lessThan(d.sections.indexOf(PatternsSectionType.archiveNavigation)),
      );
    });
  });

  group('ArchivePaidValueProofSource', () {
    test('requires proof thresholds before showing copy hook', () {
      expect(
        ArchivePaidValueProofSource.shouldShow(
          entryCount: 1,
          belief: _belief(),
          timeline: null,
          returnProofSeen: true,
        ),
        isFalse,
      );

      final timeline = ArchiveEvolutionTimeline(
        patternTitle: 'Work pressure',
        events: List.generate(
          3,
          (i) => ArchiveEvolutionEvent(
            id: 'e$i',
            date: DateTime(2026, 6, i + 1),
            type: ArchiveEvolutionEventType.showedAgain,
            title: 'Showed again',
            body: 'Grounded in your words.',
          ),
        ),
        eventCount: 3,
      );

      expect(
        ArchivePaidValueProofSource.shouldShow(
          entryCount: 2,
          belief: _belief(),
          timeline: timeline,
          returnProofSeen: true,
        ),
        isTrue,
      );
    });
  });

  group('Pattern screen back navigation', () {
    ArchiveBeliefCardModel _detailBelief() => ArchiveBeliefCardModel(
          id: 'belief-test',
          statement: 'Work pressure keeps showing up before you agree.',
          confidencePercent: 72,
          evidenceSummary: 'Appeared in 3 reflections.',
          whyExplanation:
              'ArchiveMe noticed this topic repeating across months of reflections.',
          section: ArchiveBeliefSection.hiddenPattern,
          conclusion: 'This pattern appears consistently in what you record.',
        );

    testWidgets('BeliefDetailScreen shows back control and pattern copy', (
      tester,
    ) async {
      final belief = _detailBelief();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BeliefDetailScreen(belief: belief),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('consumer_screen_back_header')), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.labelWhy), findsOneWidget);
      expect(find.text(belief.statement), findsOneWidget);
      expect(find.text(belief.whyExplanation), findsOneWidget);
    });
  });
}

class _MemoryPrefs implements MobilePrefsStore {
  final Map<String, dynamic> _maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => _maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    _maps[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
