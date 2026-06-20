import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_change_timeline.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_loop_experiment.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_positive_pattern_detector.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_return_value_proof.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_thought_map.dart';
import 'package:voicememory_mobile/features/paywall/archive_paid_value_proof.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_change_timeline_card.dart';
import 'package:voicememory_mobile/widgets/paywall/archive_paid_value_proof_panel.dart';

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

ArchiveLoopExperiment _completedExperiment({
  required ArchiveLoopExperimentResult result,
}) {
  return ArchiveLoopExperiment(
    id: 'alex_completed',
    createdAt: DateTime.utc(2026, 6, 14, 12),
    source: ArchiveLoopExperimentSource.thoughtMap,
    sourceId: 'map-1',
    mapId: 'map-1',
    patternKey: 'checking_loop',
    title: 'Try one useful check',
    experimentLine: 'Do one useful check, then wait before checking again.',
    whyThisExperimentLine:
        'Your recordings suggest the second check may be about relief, not only the result.',
    watchForLine:
        'Watch whether waiting makes the urge softer, stronger, or unchanged.',
    recordingPrompt: 'Record whether one useful check was enough this time.',
    status: ArchiveLoopExperimentStatus.completed,
    expectedSignal: ArchiveLoopExperimentExpectedSignal.clearerStoppingPoint,
    createdFromEvidenceEntryIds: const ['e1', 'e2'],
    acceptedAt: DateTime.utc(2026, 6, 14, 13),
    completedAt: DateTime.utc(2026, 6, 15, 12),
    completedEntryId: 'entry-done',
    result: result,
  );
}

ArchiveReturnValueProofResult _softenedReturnResult() {
  return ArchiveReturnValueProofResultResolver.resolve(
    ArchiveReturnValueProofInput(
      proof: ArchiveReturnValueProof(
        id: 'arvp_test',
        mapId: 'thought-map',
        sourceEntryId: 'entry-1',
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

ArchiveChangeTimeline _timelineFromEntries(List<JournalEntry> entries) {
  return ArchiveChangeTimelineResolver.resolve(
    entries: entries,
    thoughtMap: _fullMap(),
    radar: null,
    latestReturnResult: null,
    latestExperiment: null,
    latestExperimentResult: null,
    latestDailyCheckIn: null,
    latestDailyCheckInResult: null,
    manual: null,
    positiveSignals: const [],
    now: DateTime.utc(2026, 6, 15, 12),
  )!;
}

void main() {
  tearDown(() {
    ArchiveChangeTimelinePlacement.blockForTest = null;
  });

  group('ArchiveChangeTimelineResolver', () {
    test('builds loop first seen item from first clear evidence', () {
      final timeline = _timelineFromEntries([
        _entry('I keep checking again and again.', id: 'e1'),
        _entry('I had to check again.', id: 'e2'),
      ]);
      expect(
        timeline.timelineItems.any(
          (item) => item.type == ArchiveChangeTimelineItemType.loopFirstSeen,
        ),
        isTrue,
      );
      expect(
        timeline.timelineItems.firstWhere(
          (item) => item.type == ArchiveChangeTimelineItemType.loopFirstSeen,
        ).evidenceLine,
        contains('I keep checking again and again'),
      );
    });

    test('builds loop repeated item from repeated checking language', () {
      final timeline = _timelineFromEntries([
        _entry('I keep checking again and again.', id: 'e1'),
        _entry('I had to check again because I keep checking.', id: 'e2'),
      ]);
      expect(
        timeline.timelineItems.any(
          (item) => item.type == ArchiveChangeTimelineItemType.loopRepeated,
        ),
        isTrue,
      );
    });

    test('builds urgency increased item when latest entry is stronger', () {
      final timeline = _timelineFromEntries([
        _entry('I had to check again.', id: 'e1'),
        _entry(
          'I must keep checking again and again. I am worried and urgent.',
          id: 'e2',
          createdAt: DateTime.utc(2026, 6, 12, 12),
        ),
      ]);
      expect(
        timeline.timelineItems.any(
          (item) => item.type == ArchiveChangeTimelineItemType.urgencyIncreased,
        ),
        isTrue,
      );
    });

    test('builds urgency softened item from return result or softer language', () {
      final timeline = ArchiveChangeTimelineResolver.resolve(
        entries: [
          _entry(
            'I must keep checking again and again. I am worried and urgent.',
            id: 'e1',
          ),
          _entry(
            'The urge to check came back, but it felt less urgent and easier to stop.',
            id: 'e2',
            createdAt: DateTime.utc(2026, 6, 12, 12),
          ),
        ],
        thoughtMap: _fullMap(),
        radar: null,
        latestReturnResult: _softenedReturnResult(),
        latestExperiment: null,
        latestExperimentResult: null,
        latestDailyCheckIn: null,
        latestDailyCheckInResult: null,
        manual: null,
        positiveSignals: const [],
        now: DateTime.utc(2026, 6, 15, 12),
      );
      expect(timeline, isNotNull);
      expect(
        timeline!.timelineItems.any(
          (item) => item.type == ArchiveChangeTimelineItemType.urgencySoftened,
        ),
        isTrue,
      );
    });

    test('builds helpful action item from positive signal', () {
      final signals = ArchivePositivePatternDetector.detectFromTranscripts(
        entries: [
          (
            entryId: 'e2',
            transcript: 'I paused before reacting and stopped sooner than usual.',
          ),
        ],
      );
      final timeline = ArchiveChangeTimelineResolver.resolve(
        entries: [
          _entry('I keep checking again and again.', id: 'e1'),
          _entry(
            'I paused before reacting and stopped sooner than usual.',
            id: 'e2',
            createdAt: DateTime.utc(2026, 6, 12, 12),
          ),
        ],
        thoughtMap: _fullMap(),
        radar: null,
        latestReturnResult: null,
        latestExperiment: null,
        latestExperimentResult: null,
        latestDailyCheckIn: null,
        latestDailyCheckInResult: null,
        manual: null,
        positiveSignals: signals,
        now: DateTime.utc(2026, 6, 15, 12),
      );
      expect(timeline, isNotNull);
      expect(
        timeline!.timelineItems.any(
          (item) =>
              item.type ==
              ArchiveChangeTimelineItemType.helpfulActionAppeared,
        ),
        isTrue,
      );
      expect(timeline.helpfulChange, isNotNull);
    });

    test('builds experiment helped item from loop experiment result', () {
      final experiment = _sampleExperiment();
      final result = ArchiveLoopExperimentResultResolver.resolve(
        experiment: experiment,
        completedEntry: _entry('I waited and felt less urgent.', id: 'done'),
        previousEntries: [
          _entry('I keep checking again and again.', id: 'e1'),
        ],
      );
      final timeline = ArchiveChangeTimelineResolver.resolve(
        entries: [
          _entry('I keep checking again and again.', id: 'e1'),
          _entry('I had to check again.', id: 'e2'),
          _entry('I waited and felt less urgent.', id: 'done'),
        ],
        thoughtMap: _fullMap(),
        radar: null,
        latestReturnResult: null,
        latestExperiment: _completedExperiment(result: result),
        latestExperimentResult: result,
        latestDailyCheckIn: null,
        latestDailyCheckInResult: null,
        manual: null,
        positiveSignals: const [],
        now: DateTime.utc(2026, 6, 15, 12),
      );
      expect(timeline, isNotNull);
      expect(
        timeline!.timelineItems.any(
          (item) =>
              item.type == ArchiveChangeTimelineItemType.experimentHelped ||
              item.type == ArchiveChangeTimelineItemType.experimentStarted,
        ),
        isTrue,
      );
      expect(timeline.hasExperimentResult, isTrue);
    });

    test('max 7 items', () {
      final experiment = _sampleExperiment();
      final result = ArchiveLoopExperimentResultResolver.resolve(
        experiment: experiment,
        completedEntry: _entry('I waited and felt less urgent.', id: 'done'),
        previousEntries: [
          _entry('I keep checking again and again.', id: 'e1'),
        ],
      );
      final signals = ArchivePositivePatternDetector.detectFromTranscripts(
        entries: [
          (
            entryId: 'e3',
            transcript: 'I paused before reacting and stopped sooner than usual.',
          ),
        ],
      );
      final timeline = ArchiveChangeTimelineResolver.resolve(
        entries: [
          _entry('I keep checking again and again.', id: 'e1'),
          _entry(
            'I must keep checking again and again. I am worried and urgent.',
            id: 'e2',
            createdAt: DateTime.utc(2026, 6, 11, 12),
          ),
          _entry(
            'I paused before reacting and stopped sooner than usual.',
            id: 'e3',
            createdAt: DateTime.utc(2026, 6, 12, 12),
          ),
          _entry('I waited and felt less urgent.', id: 'done'),
        ],
        thoughtMap: _fullMap(),
        radar: null,
        latestReturnResult: _softenedReturnResult(),
        latestExperiment: _completedExperiment(result: result),
        latestExperimentResult: result,
        latestDailyCheckIn: null,
        latestDailyCheckInResult: null,
        manual: null,
        positiveSignals: signals,
        now: DateTime.utc(2026, 6, 15, 12),
      );
      expect(timeline, isNotNull);
      expect(timeline!.timelineItems.length, lessThanOrEqualTo(7));
    });

    test('timeline sorted by date', () {
      final timeline = _timelineFromEntries([
        _entry('I keep checking again and again.', id: 'e1'),
        _entry(
          'I had to check again.',
          id: 'e2',
          createdAt: DateTime.utc(2026, 6, 12, 12),
        ),
      ]);
      final dates = timeline.timelineItems.map((item) => item.createdAt).toList();
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].compareTo(dates[i - 1]), greaterThanOrEqualTo(0));
      }
    });

    test('does not invent evidence', () {
      final timeline = _timelineFromEntries([
        _entry('I keep checking again and again.', id: 'e1'),
        _entry('I had to check again.', id: 'e2'),
      ]);
      final blob = timeline.timelineItems
          .map(
            (item) =>
                '${item.title} ${item.evidenceLine} ${item.changeLine}',
          )
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('3 times')));
      expect(blob, isNot(contains('always')));
      expect(blob, isNot(contains('this proves')));
      expect(blob, isNot(matches(RegExp(r'\d+ recordings'))));
    });
  });

  group('ArchiveChangeTimeline UI', () {
    testWidgets('renders Change timeline', (tester) async {
      final timeline = _timelineFromEntries([
        _entry('I keep checking again and again.', id: 'e1'),
        _entry('I had to check again.', id: 'e2'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveChangeTimelineCard(
                timeline: timeline,
                surface: 'test',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Change timeline'), findsOneWidget);
      expect(
        find.text('How this pattern is moving over time'),
        findsOneWidget,
      );
      expect(find.text('Record this next'), findsWidgets);
    });

    testWidgets('CTA routes to RecordScreen with guidedPromptNodeKey changeTimeline',
        (tester) async {
      final timeline = _timelineFromEntries([
        _entry('I keep checking again and again.', id: 'e1'),
        _entry('I had to check again.', id: 'e2'),
      ]);
      final item = timeline.timelineItems.firstWhere(
        (entry) => entry.hasRecordPrompt,
      );
      Uri? navigatedUri;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => SingleChildScrollView(
              child: ArchiveChangeTimelineCard(
                timeline: timeline,
                surface: 'test',
              ),
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) {
              navigatedUri = state.uri;
              return const Scaffold(body: Text('record'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('archive_change_timeline_record_${item.id}')),
      );
      await tester.pumpAndSettle();
      expect(navigatedUri, isNotNull);
      expect(
        navigatedUri!.queryParameters['guidedPromptNodeKey'],
        'changeTimeline',
      );
      expect(
        navigatedUri!.queryParameters['guidedPromptText'],
        item.nextLine,
      );
    });
  });

  group('ArchiveChangeTimeline placement and compliance', () {
    test('Map tab placement keeps timeline after return proof and before radar', () {
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
      expect(returnIndex, greaterThan(-1));
      expect(proofIndex, greaterThan(returnIndex));
      expect(radarIndex, greaterThan(proofIndex));
    });

    testWidgets(
        'paid value proof can use timeline copy without hiding subscription metadata',
        (tester) async {
      final timeline = _timelineFromEntries([
        _entry('I keep checking again and again.', id: 'e1'),
        _entry('I had to check again.', id: 'e2'),
      ]);
      final proof = ArchivePaidValueProofResolver.resolve(
        ArchivePaidValueProofInput(
          thoughtMap: _fullMap(),
          changeTimeline: timeline,
          entryCount: 3,
          now: DateTime.utc(2026, 6, 15, 12),
        ),
      );
      expect(proof.source, ArchivePaidValueProofSource.changeTimeline);
      expect(proof.title, 'Keep tracking what changes');
      expect(proof.valueLine, contains('timeline connected'));
      expect(proof.riskLine, contains('evidence builds'));
      expect(
        ArchivePaidValueProofResolver.paywallHeadline(proof),
        'Keep tracking what changes',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchivePaidValueProofPanel(
              proof: proof,
              surface: 'test',
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('archive_paid_value_proof_panel_value')),
          findsOneWidget);
      expect(find.byKey(const Key('archive_paid_value_proof_panel_risk')),
          findsOneWidget);
    });

    test('no therapy/diagnosis/cure language in resolver output', () {
      final experiment = _sampleExperiment();
      final result = ArchiveLoopExperimentResultResolver.resolve(
        experiment: experiment,
        completedEntry: _entry('I waited and felt less urgent.', id: 'done'),
        previousEntries: [
          _entry('I keep checking again and again.', id: 'e1'),
        ],
      );
      final timeline = ArchiveChangeTimelineResolver.resolve(
        entries: [
          _entry('I keep checking again and again.', id: 'e1'),
          _entry('I had to check again.', id: 'e2'),
        ],
        thoughtMap: _fullMap(),
        radar: null,
        latestReturnResult: _softenedReturnResult(),
        latestExperiment: _completedExperiment(result: result),
        latestExperimentResult: result,
        latestDailyCheckIn: null,
        latestDailyCheckInResult: null,
        manual: null,
        positiveSignals: ArchivePositivePatternDetector.detectFromTranscripts(
          entries: [
            (
              entryId: 'e2',
              transcript:
                  'I paused before reacting and stopped sooner than usual.',
            ),
          ],
        ),
        now: DateTime.utc(2026, 6, 15, 12),
      );
      expect(timeline, isNotNull);
      final blob = [
        timeline!.summaryLine,
        ...timeline.timelineItems.expand(
          (item) => [item.title, item.evidenceLine, item.changeLine, item.nextLine],
        ),
      ].join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('cure')));
      expect(blob, isNot(contains('addiction')));
      expect(blob, isNot(contains('this proves')));
    });

    test('release smoke placement gate remains clean', () {
      ArchiveChangeTimelinePlacement.blockForTest = true;
      final timeline = _timelineFromEntries([
        _entry('I keep checking again and again.', id: 'e1'),
        _entry('I had to check again.', id: 'e2'),
      ]);
      expect(
        ArchiveChangeTimelinePlacement.shouldShow(
          entryCount: 3,
          firstValueRescueActive: false,
          timeline: timeline,
          hasFullMap: true,
          radar: null,
          manual: null,
        ),
        isFalse,
      );
    });

    test('logs ARCHIVEME_CHANGE_TIMELINE_RESOLVED', () {
      final logs = _captureLogs(() {
        _timelineFromEntries([
          _entry('I keep checking again and again.', id: 'e1'),
          _entry('I had to check again.', id: 'e2'),
        ]);
      });
      expect(
        logs.any((line) => line.contains('ARCHIVEME_CHANGE_TIMELINE_RESOLVED')),
        isTrue,
      );
      expect(
        logs.any((line) => line.contains('ARCHIVEME_CHANGE_TIMELINE_ITEM')),
        isTrue,
      );
    });

    test('Record screen uses Record this next prefix for change timeline prompts',
        () {
      const screen = RecordScreen(
        guidedPromptText: 'Record the next time this appears.',
        guidedPromptId: 'acti_test',
        guidedPromptNodeKey: 'changeTimeline',
      );
      expect(screen.guidedPromptNodeKey, 'changeTimeline');
    });
  });
}

ArchiveLoopExperiment _sampleExperiment() {
  return ArchiveLoopExperiment(
    id: 'alex_test',
    createdAt: DateTime.utc(2026, 6, 14, 12),
    source: ArchiveLoopExperimentSource.thoughtMap,
    sourceId: 'map-1',
    mapId: 'map-1',
    patternKey: 'checking_loop',
    title: 'Try one useful check',
    experimentLine: 'Do one useful check, then wait before checking again.',
    whyThisExperimentLine:
        'Your recordings suggest the second check may be about relief, not only the result.',
    watchForLine:
        'Watch whether waiting makes the urge softer, stronger, or unchanged.',
    recordingPrompt: 'Record whether one useful check was enough this time.',
    status: ArchiveLoopExperimentStatus.accepted,
    expectedSignal: ArchiveLoopExperimentExpectedSignal.clearerStoppingPoint,
    createdFromEvidenceEntryIds: const ['e1', 'e2'],
    acceptedAt: DateTime.utc(2026, 6, 14, 13),
  );
}
