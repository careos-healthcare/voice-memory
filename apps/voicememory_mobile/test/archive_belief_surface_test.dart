import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_model.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_change_timeline_metrics_store.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_demo_preview_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_demo_preview_resolver.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_display_copy_guard.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_paid_value_proof_source.dart';
import 'package:voicememory_mobile/features/patterns/patterns_stack_policy.dart';
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
  });

  group('ArchiveBeliefSurfaceSource', () {
    test('zero entries returns static empty preview', () {
      final surface = const ArchiveBeliefSurfaceSource().resolve([]);
      expect(surface.shouldShow, isTrue);
      expect(surface.isPreview, isTrue);
      expect(surface.beliefSummary, contains('Not enough evidence yet'));
    });

    test('builds belief from real capacity repeat entries', () {
      final surface = const ArchiveBeliefSurfaceSource().resolve([
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
      ]);

      expect(surface.shouldShow, isTrue);
      expect(surface.isPreview, isFalse);
      expect(ArchiveDisplayCopyGuard.passes(surface.beliefSummary), isTrue);
      expect(ArchiveDisplayCopyGuard.passes(surface.evidenceSummary), isTrue);
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
      final surface = ArchiveBeliefSurfaceSource().resolve([
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
      ]);

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
      expect(find.text(ArchiveBeliefSurfaceCopy.evidenceLabel), findsOneWidget);
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
