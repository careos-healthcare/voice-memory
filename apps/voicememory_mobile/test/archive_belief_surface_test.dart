import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_belief_surface.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_change_timeline.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_change_timeline_metrics_store.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_loop_experiment.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_positive_pattern_detector.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_return_value_proof.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_thought_map.dart';
import 'package:voicememory_mobile/features/paywall/archive_paid_value_proof.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_belief_surface_card.dart';

JournalEntry _entry(
  String transcript, {
  String id = 'entry-1',
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 10, 12),
    transcript: transcript,
    durationSeconds: 42,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

ArchiveThoughtMap _fullMap() {
  return const ArchiveThoughtMap(
    title: 'How the checking loop works',
    triggerNode: ArchiveThoughtMapNode(
      label: 'Trigger',
      text: 'When I need this to work properly',
      evidenceQuote: 'when I need this to work properly',
    ),
    thoughtNode: ArchiveThoughtMapNode(
      label: 'Thought',
      text: 'I need to verify again',
    ),
    behaviourNode: ArchiveThoughtMapNode(
      label: 'Behaviour',
      text: 'I check again',
    ),
    reliefNode: ArchiveThoughtMapNode(label: 'Relief', text: 'Brief calm'),
    costNode: ArchiveThoughtMapNode(label: 'Cost', text: 'Time lost'),
    alternativeNode: ArchiveThoughtMapNode(
      label: 'Alternative',
      text: 'One check may be enough',
    ),
    nextTestNode: ArchiveThoughtMapNode(
      label: 'Next test',
      text: 'Record whether one useful check was enough this time.',
    ),
    strongestQuote: 'I keep checking again and again',
    supportQuote: 'I need this to work',
    confidenceLabel: 'Grounded in 2–3 entries',
    hasEnoughEvidence: true,
    mapConfidenceStatus: 'Grounded in 2–3 entries',
  );
}

ArchiveBeliefsSnapshot _beliefsSnapshot() {
  return ArchiveBeliefsSnapshot(
    homeBeliefs: const [],
    current: [
      ArchiveBeliefCardModel(
        id: 'belief-1',
        statement: 'You keep returning to control when things feel uncertain.',
        confidencePercent: 72,
        evidenceSummary:
            'Seen across multiple recordings with work pressure language.',
        whyExplanation: 'Named from recurring themes.',
        section: ArchiveBeliefSection.current,
      ),
    ],
    emerging: const [],
    changing: const [],
    hiddenPatterns: const [],
    stats: const ArchiveBeliefStats(
      beliefsIdentified: 1,
      strongestBelief: 'control when uncertain',
      archiveAgeDays: 3,
      reflectionsAnalysed: 3,
      evidencePoints: 4,
    ),
  );
}

List<String> _captureLogs(void Function() body) {
  final logs = <String>[];
  final previous = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  try {
    body();
  } finally {
    debugPrint = previous;
  }
  return logs;
}

void main() {
  tearDown(() {
    ArchiveBeliefSurfacePlacement.blockForTest = null;
    ArchiveChangeTimelinePlacement.blockForTest = null;
  });

  group('ArchiveBeliefSurfaceResolver', () {
    test('generates belief from real evidence with thought map', () {
      final surface = ArchiveBeliefSurfaceResolver.resolve(
        entries: [
          _entry('I keep checking again and again.', id: 'e1'),
          _entry('I had to check again.', id: 'e2'),
          _entry('I must keep checking again and again.', id: 'e3'),
        ],
        thoughtMap: _fullMap(),
        changeTimeline: null,
        beliefs: _beliefsSnapshot(),
        specificity: null,
        latestReturnResult: null,
        latestLens: null,
        latestLensReturnResult: null,
      );
      expect(surface, isNotNull);
      expect(surface!.isPreview, isFalse);
      expect(surface.beliefSummary, isNotEmpty);
      expect(surface.evidenceSummary, contains('recording'));
    });

    test('weak evidence uses preview cautious copy', () {
      final surface = ArchiveBeliefSurfaceResolver.resolve(
        entries: [_entry('I keep checking again and again.', id: 'e1')],
        thoughtMap: _fullMap(),
        changeTimeline: null,
        beliefs: _beliefsSnapshot(),
        specificity: null,
        latestReturnResult: null,
        latestLens: null,
        latestLensReturnResult: null,
      );
      expect(surface, isNotNull);
      expect(surface!.isPreview, isTrue);
      expect(surface.previewBullets, isNotEmpty);
      expect(surface.evidenceSummary, contains('not a conclusion'));
    });

    test('no therapy/diagnosis/cure language in resolver output', () {
      final timeline = ArchiveChangeTimelineResolver.resolve(
        entries: [
          _entry('I keep checking again and again.', id: 'e1'),
          _entry('I had to check again.', id: 'e2'),
        ],
        thoughtMap: _fullMap(),
        radar: null,
        latestReturnResult: null,
        latestExperiment: null,
        latestExperimentResult: null,
        latestDailyCheckIn: null,
        latestDailyCheckInResult: null,
        manual: null,
        positiveSignals: const [],
      );
      final surface = ArchiveBeliefSurfaceResolver.resolve(
        entries: [
          _entry('I keep checking again and again.', id: 'e1'),
          _entry('I had to check again.', id: 'e2'),
        ],
        thoughtMap: _fullMap(),
        changeTimeline: timeline,
        beliefs: _beliefsSnapshot(),
        specificity: null,
        latestReturnResult: null,
        latestLens: null,
        latestLensReturnResult: null,
      );
      expect(surface, isNotNull);
      final blob = [
        surface!.beliefSummary,
        surface.evidenceSummary,
        surface.whatChangedSummary,
        if (surface.recordNextPrompt != null) surface.recordNextPrompt!,
        ...surface.previewBullets,
      ].join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('cure')));
      expect(blob, isNot(contains('addiction')));
    });
  });

  group('ArchiveBeliefSurfaceCard', () {
    testWidgets('renders belief surface title and sections', (tester) async {
      final surface = ArchiveBeliefSurface(
        mode: ArchiveBeliefSurfaceMode.belief,
        beliefSummary: '"I keep checking again and again"',
        evidenceSummary:
            'Seen across 2 recordings. Strongest signal: I check again.',
        whatChangedSummary:
            'Your recordings suggest this loop is repeating across more than one moment.',
        confidenceLabel: 'Based on your words',
        recordNextPrompt: 'Record the next time this appears.',
        hasEnoughEvidence: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveBeliefSurfaceCard(
              surface: surface,
              onSurface: 'test',
            ),
          ),
        ),
      );
      expect(
        find.text('Your archive currently believes this about you'),
        findsOneWidget,
      );
      expect(find.text('Evidence'), findsOneWidget);
      expect(find.text('What changed'), findsOneWidget);
      expect(find.text('Record this next'), findsOneWidget);
    });
  });

  group('ArchiveChangeTimelineMetricsStore truth feedback', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late ArchiveChangeTimelineMetricsStore store;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_truth_feedback_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      store = ArchiveChangeTimelineMetricsStore(prefs);
    });

    test('persists truth feedback and viewed/expanded flags', () async {
      await store.markTimelineViewed();
      await store.markTimelineExpanded();
      await store.saveTruthFeedback(
        feedback: ArchiveTimelineTruthFeedback.partly,
        note: 'Timing felt off',
      );
      final metrics = await store.load();
      expect(metrics.timelineViewed, isTrue);
      expect(metrics.timelineExpanded, isTrue);
      expect(metrics.truthFeedback, ArchiveTimelineTruthFeedback.partly);
      expect(metrics.truthFeedbackNote, 'Timing felt off');
      expect(metrics.hasTruthFeedback, isTrue);
    });
  });

  group('Map placement and paid proof', () {
    test('Map tab order keeps belief and timeline before radar', () {
      final source =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      final methodStart =
          source.indexOf('List<Widget> _withLoopMapPrimarySurface');
      expect(methodStart, greaterThan(-1));
      final methodBody = source.substring(methodStart, methodStart + 900);
      final returnIndex =
          methodBody.indexOf('_loopMapReturnValueProofWidgets()');
      final proofIndex = methodBody.indexOf('_loopMapProofLoopWidgets()');
      final radarIndex =
          methodBody.indexOf('_loopMapEmergingPatternRadarWidgets()');
      final experimentIndex = methodBody.indexOf('_loopMapExperimentWidgets()');
      final manualIndex = methodBody.indexOf('_loopMapPersonalManualWidgets()');
      expect(returnIndex, greaterThan(-1));
      expect(proofIndex, greaterThan(returnIndex));
      expect(radarIndex, greaterThan(proofIndex));
      expect(experimentIndex, greaterThan(radarIndex));
      expect(manualIndex, greaterThan(experimentIndex));
    });

    test('belief surface appears above timeline in proof loop', () {
      final source =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      final methodStart = source.indexOf('List<Widget> _loopMapProofLoopWidgets');
      expect(methodStart, greaterThan(-1));
      final methodBody = source.substring(methodStart, methodStart + 300);
      final beliefIndex = methodBody.indexOf('_loopMapBeliefSurfaceWidgets()');
      final timelineIndex =
          methodBody.indexOf('_loopMapChangeTimelineWidgets()');
      expect(beliefIndex, greaterThan(-1));
      expect(timelineIndex, greaterThan(beliefIndex));
    });

    test('paid hook only appears after proof thresholds', () {
      final timeline = ArchiveChangeTimelineResolver.resolve(
        entries: [
          _entry('I keep checking again and again.', id: 'e1'),
          _entry(
            'I must keep checking again and again. I am worried and urgent.',
            id: 'e2',
          ),
          _entry(
            'The urge to check came back, but it felt less urgent and easier to stop.',
            id: 'e3',
          ),
        ],
        thoughtMap: _fullMap(),
        radar: null,
        latestReturnResult:
            ArchiveReturnValueProofResultResolver.resolve(
          ArchiveReturnValueProofInput(
            proof: ArchiveReturnValueProof(
              id: 'arvp',
              mapId: 'map',
              sourceEntryId: 'e1',
              testQuestion: 'Watch whether one check is enough',
              testReason:
                  'Your latest recordings suggest the check may be trying to create relief, not only confirm the result.',
              expectedSignal: 'Look for whether the urge to check comes back.',
              createdAt: DateTime.utc(2026, 6, 14, 12),
              dueLabel: 'Tomorrow',
            ),
            returnTranscript:
                'The urge to check came back, but it felt less urgent and easier to stop.',
            sourceTranscript: 'I keep checking again and again.',
          ),
        ),
        latestExperiment: null,
        latestExperimentResult: null,
        latestDailyCheckIn: null,
        latestDailyCheckInResult: null,
        manual: null,
        positiveSignals: ArchivePositivePatternDetector.detectFromTranscripts(
          entries: [
            (
              entryId: 'e3',
              transcript:
                  'The urge to check came back, but it felt less urgent and easier to stop.',
            ),
          ],
        ),
      );
      expect(timeline, isNotNull);
      expect(timeline!.timelineItems.length, greaterThanOrEqualTo(3));

      final beliefSurface = ArchiveBeliefSurfaceResolver.resolve(
        entries: [
          _entry('I keep checking again and again.', id: 'e1'),
          _entry(
            'I must keep checking again and again. I am worried and urgent.',
            id: 'e2',
          ),
          _entry(
            'The urge to check came back, but it felt less urgent and easier to stop.',
            id: 'e3',
          ),
        ],
        thoughtMap: _fullMap(),
        changeTimeline: timeline,
        beliefs: _beliefsSnapshot(),
        specificity: null,
        latestReturnResult: timeline.timelineItems.isNotEmpty
            ? null
            : null,
        latestLens: null,
        latestLensReturnResult: null,
      );

      final completedProof = ArchiveReturnValueProof(
        id: 'arvp_done',
        mapId: 'map',
        sourceEntryId: 'e1',
        testQuestion: 'Watch whether one check is enough',
        testReason:
            'Your latest recordings suggest the check may be trying to create relief, not only confirm the result.',
        expectedSignal: 'Look for whether the urge to check comes back.',
        createdAt: DateTime.utc(2026, 6, 14, 12),
        dueLabel: 'Tomorrow',
        result: ArchiveReturnValueProofResultResolver.resolve(
          ArchiveReturnValueProofInput(
            proof: ArchiveReturnValueProof(
              id: 'arvp',
              mapId: 'map',
              sourceEntryId: 'e1',
              testQuestion: 'Watch whether one check is enough',
              testReason:
                  'Your latest recordings suggest the check may be trying to create relief, not only confirm the result.',
              expectedSignal: 'Look for whether the urge to check comes back.',
              createdAt: DateTime.utc(2026, 6, 14, 12),
              dueLabel: 'Tomorrow',
            ),
            returnTranscript:
                'The urge to check came back, but it felt less urgent and easier to stop.',
            sourceTranscript: 'I keep checking again and again.',
          ),
        ),
      );

      expect(
        ArchivePaidValueProofResolver.qualifiesForBeliefTimelineProof(
          ArchivePaidValueProofInput(
            thoughtMap: _fullMap(),
            beliefSurface: beliefSurface,
            changeTimeline: timeline,
            completedReturnProof: completedProof,
            entryCount: 3,
          ),
        ),
        isTrue,
      );

      final proof = ArchivePaidValueProofResolver.resolve(
        ArchivePaidValueProofInput(
          thoughtMap: _fullMap(),
          beliefSurface: beliefSurface,
          changeTimeline: timeline,
          completedReturnProof: completedProof,
          entryCount: 3,
          now: DateTime.utc(2026, 6, 15, 12),
        ),
      );
      expect(proof.source, ArchivePaidValueProofSource.beliefTimelineProof);
      expect(proof.title, contains('starting to show what changes'));

      final tooEarly = ArchivePaidValueProofResolver.resolve(
        ArchivePaidValueProofInput(
          thoughtMap: _fullMap(),
          changeTimeline: timeline,
          entryCount: 1,
        ),
      );
      expect(tooEarly.source, isNot(ArchivePaidValueProofSource.beliefTimelineProof));
    });

    test('logs ARCHIVEME_BELIEF_SURFACE_RESOLVED', () {
      final logs = _captureLogs(() {
        ArchiveBeliefSurfaceResolver.resolve(
          entries: [
            _entry('I keep checking again and again.', id: 'e1'),
            _entry('I had to check again.', id: 'e2'),
          ],
          thoughtMap: _fullMap(),
          changeTimeline: null,
          beliefs: _beliefsSnapshot(),
          specificity: null,
          latestReturnResult: null,
          latestLens: null,
          latestLensReturnResult: null,
        );
      });
      expect(
        logs.any((line) => line.contains('ARCHIVEME_BELIEF_SURFACE_RESOLVED')),
        isTrue,
      );
    });
  });
}
