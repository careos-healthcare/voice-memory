import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/insights/post_save_life_os_insights.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/low_effort_yes_capture_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/low_effort_yes_capture_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/yes_capture_timing.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/low_effort_yes_capture_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/life_os/post_save_life_os_insights_card.dart';

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required String transcript,
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: createdAt,
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: localAudioPath,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

PostSaveLifeOsInsights _visibleInsights({String finalizedEntryId = 'latest'}) =>
    PostSaveLifeOsInsights(
      finalizedEntryId: finalizedEntryId,
      entityFrequencies: [
        EntityFrequencyInsight(
          nodeId: 'node_sarah',
          entityLabel: 'Sarah',
          entityType: 'person',
          isNewlyDetected: false,
          currentMonthCount: 2,
          citations: [
            LifeOsEvidenceCitation(
              entryId: 'prior',
              observedAt: DateTime.utc(2026, 6, 3, 9),
            ),
            LifeOsEvidenceCitation(
              entryId: finalizedEntryId,
              observedAt: DateTime.utc(2026, 6, 20, 12),
            ),
          ],
        ),
      ],
      relatedMemories: [
        RelatedMemoryInsight(
          nodeId: 'node_sarah',
          entityLabel: 'Sarah',
          entityType: 'person',
          currentEntryCitation: LifeOsEvidenceCitation(
            entryId: finalizedEntryId,
            observedAt: DateTime.utc(2026, 6, 20, 12),
          ),
          relatedEntryCitation: LifeOsEvidenceCitation(
            entryId: 'prior',
            observedAt: DateTime.utc(2026, 6, 3, 9),
          ),
        ),
      ],
    );

class _ImmediateSaveEngine extends LowEffortYesCaptureEngine {
  const _ImmediateSaveEngine();

  @override
  Future<LowEffortYesCaptureSaveResult> saveQuickCapture({
    required JournalStore journal,
    required LowEffortYesCaptureSaveRequest request,
    CapacityPullReasonStore? pullReasonStore,
    CapacityDecisionOutcomeStore? outcomeStore,
  }) async => const LowEffortYesCaptureSaveResult(
    entryId: 'quick_yes_instant',
    savedPullReason: true,
    savedOutcome: false,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 40,
}) async {
  for (var i = 0; i < attempts && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

void main() {
  group('PostSaveLifeOsInsights worker and service', () {
    final oldSarah = _entry(
      id: 'old_sarah',
      createdAt: DateTime.utc(2026, 5, 12, 8),
      transcript: 'I spoke to Sarah about the launch.',
    );
    final priorSarah = _entry(
      id: 'prior_sarah',
      createdAt: DateTime.utc(2026, 6, 3, 9),
      transcript: 'I met Sarah before work.',
    );
    final latest = _entry(
      id: 'latest',
      createdAt: DateTime.utc(2026, 6, 20, 12),
      transcript: 'I talked to Sarah. I met Priya.',
    );

    late PostSaveLifeOsInsights result;

    setUp(() {
      result = PostSaveLifeOsInsights.fromJson(
        postSaveLifeOsInsightsWorker({
          'entries': [oldSarah.toJson(), priorSarah.toJson(), latest.toJson()],
          'finalizedEntryId': latest.id,
        }),
      );
    });

    test('finds new entities and exact current-month counts', () {
      final sarah = result.entityFrequencies.singleWhere(
        (item) => item.entityLabel == 'Sarah',
      );
      final priya = result.entityFrequencies.singleWhere(
        (item) => item.entityLabel == 'Priya',
      );

      expect(sarah.isNewlyDetected, isFalse);
      expect(sarah.currentMonthCount, 2);
      expect(priya.isNewlyDetected, isTrue);
      expect(priya.currentMonthCount, 1);
    });

    test('retains exact monthly citations and timestamps', () {
      final sarah = result.entityFrequencies.singleWhere(
        (item) => item.entityLabel == 'Sarah',
      );

      expect(sarah.citations.map((item) => item.entryId), [
        'prior_sarah',
        'latest',
      ]);
      expect(sarah.citations.first.observedAt, priorSarah.createdAt.toUtc());
      expect(sarah.citations.last.observedAt, latest.createdAt.toUtc());
      expect(
        sarah.citations.map((item) => item.entryId),
        isNot(contains('old_sarah')),
      );
    });

    test('does not count future evidence in a post-save month total', () {
      final futureSarah = _entry(
        id: 'future_sarah',
        createdAt: DateTime.utc(2026, 6, 25, 9),
        transcript: 'I spoke to Sarah after the saved moment.',
      );
      final bounded = PostSaveLifeOsInsights.fromJson(
        postSaveLifeOsInsightsWorker({
          'entries': [
            priorSarah.toJson(),
            latest.toJson(),
            futureSarah.toJson(),
          ],
          'finalizedEntryId': latest.id,
        }),
      );
      final sarah = bounded.entityFrequencies.singleWhere(
        (item) => item.entityLabel == 'Sarah',
      );

      expect(sarah.currentMonthCount, 2);
      expect(
        sarah.citations.map((item) => item.entryId),
        isNot(contains('future_sarah')),
      );
    });

    test('returns the most recent prior memory without self-matching', () {
      final related = result.relatedMemories.singleWhere(
        (item) => item.entityLabel == 'Sarah',
      );

      expect(related.currentEntryCitation.entryId, 'latest');
      expect(related.currentEntryCitation.observedAt, latest.createdAt.toUtc());
      expect(related.relatedEntryCitation.entryId, 'prior_sarah');
      expect(
        related.relatedEntryCitation.observedAt,
        priorSarah.createdAt.toUtc(),
      );
      expect(
        related.relatedEntryCitation.entryId,
        isNot(related.currentEntryCitation.entryId),
      );
    });

    test('returns safe empty results for a transcript-free quick entry', () {
      final empty = _entry(
        id: 'quick_yes',
        createdAt: DateTime.utc(2026, 6, 20, 13),
        transcript: '',
      );
      final emptyResult = PostSaveLifeOsInsights.fromJson(
        postSaveLifeOsInsightsWorker({
          'entries': [priorSarah.toJson(), empty.toJson()],
          'finalizedEntryId': empty.id,
        }),
      );

      expect(emptyResult.isEmpty, isTrue);
      expect(emptyResult.finalizedEntryId, empty.id);
    });

    test('delegates sendable JSON to an injected analysis runner', () async {
      Map<String, dynamic>? received;
      final service = PostSaveLifeOsInsightsService(
        runner: (request) async {
          received = request;
          return PostSaveLifeOsInsights(finalizedEntryId: 'latest').toJson();
        },
      );

      final delegated = await service.analyze(
        entries: [latest],
        finalizedEntryId: latest.id,
      );

      expect(received?['finalizedEntryId'], latest.id);
      expect(received?['entries'], isA<List<dynamic>>());
      expect((received?['entries'] as List).single, isA<Map>());
      expect(delegated.finalizedEntryId, latest.id);
    });

    test('injects async production graphs before analysis', () async {
      var graphBuilds = 0;
      final service = PostSaveLifeOsInsightsService(
        graphBuilder: (entries) async {
          graphBuilds++;
          return PersonalKnowledgeGraphEngine().rebuild(entries);
        },
        runner: (request) async => postSaveLifeOsInsightsWorker(request),
      );

      final result = await service.analyze(
        entries: [priorSarah, latest],
        finalizedEntryId: latest.id,
      );

      expect(graphBuilds, 2);
      expect(result.finalizedEntryId, latest.id);
      expect(result.isAiDerived, isTrue);
      expect(result.isEmpty, isTrue);
    });
  });

  group('PostSaveLifeOsInsightsCard', () {
    testWidgets('moves from loading to expandable cited insights', (
      tester,
    ) async {
      final completer = Completer<PostSaveLifeOsInsights>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveLifeOsInsightsCard(
              entryId: 'latest',
              loader: () => completer.future,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('post_save_life_os_insights_loading')),
        findsOneWidget,
      );

      completer.complete(_visibleInsights());
      await tester.pump();
      await tester.pump();

      expect(find.text("You've mentioned Sarah 2 times this month"), findsOne);
      expect(
        find.byKey(const Key('post_save_life_os_insights_details')),
        findsNothing,
      );

      final collapsedSemantics = tester.getSemantics(
        find.byKey(const Key('post_save_life_os_insights_toggle')),
      );
      expect(
        collapsedSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        collapsedSemantics.getSemanticsData().label,
        contains('Collapsed'),
      );

      await tester.tap(
        find.byKey(const Key('post_save_life_os_insights_toggle')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('post_save_life_os_insights_details')),
        findsOneWidget,
      );
      expect(find.textContaining('Entry ID: prior'), findsWidgets);
      expect(find.textContaining('Entry ID: latest'), findsOneWidget);
      expect(find.textContaining('private raw excerpt'), findsNothing);

      final expandedSemantics = tester.getSemantics(
        find.byKey(const Key('post_save_life_os_insights_toggle')),
      );
      expect(expandedSemantics.getSemanticsData().label, contains('Expanded'));

      await tester.tap(
        find.byKey(const Key('post_save_life_os_insights_toggle')),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('post_save_life_os_insights_details')),
        findsNothing,
      );
    });

    testWidgets('shows a safe empty state without exception details', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveLifeOsInsightsCard(
              entryId: 'latest',
              loader: () => Future.error(StateError('private failure')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('post_save_life_os_insights_empty')),
        findsOneWidget,
      );
      expect(find.textContaining('private failure'), findsNothing);
    });
  });

  testWidgets(
    'quick capture completes before insights and places them below friction',
    (tester) async {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      await tester.runAsync(() async {
        await AppServices.resetForTest(
          journalPath: '/tmp/post_save_life_os_journal_$stamp.json',
          prefsPath: '/tmp/post_save_life_os_prefs_$stamp.json',
          skipRevenueCat: true,
        );
        await CapacityPullReasonStore.resetForTest();
        await CapacityDecisionOutcomeStore.resetForTest();
      });
      final insights = Completer<PostSaveLifeOsInsights>();
      String? requestedEntryId;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => LowEffortYesCaptureScreen(
              engine: const _ImmediateSaveEngine(),
              instantMode: true,
              insightsLoader: (entryId) {
                requestedEntryId = entryId;
                return insights.future;
              },
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (_, _) => const Scaffold(body: Text('Record')),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );

      final timingOption = find.byKey(
        const Key(
          'low_effort_yes_capture_timing_${YesCaptureTimingIds.beforeYes}',
        ),
      );
      await tester.ensureVisible(timingOption);
      await tester.tap(timingOption);
      await tester.pump();
      final pullOption = find.byKey(
        const Key(
          'low_effort_yes_capture_pull_${CapacityPullReasonIds.soundedUrgent}',
        ),
      );
      await tester.ensureVisible(pullOption);
      await tester.tap(pullOption);
      await tester.pump();
      final saveButton = find.byKey(
        const Key('low_effort_yes_capture_save_button'),
      );
      await tester.ensureVisible(saveButton);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
      await tester.tap(saveButton);

      await _pumpUntil(
        tester,
        find.byKey(const Key('quick_capture_friction_card')),
      );
      expect(requestedEntryId, isNotNull);
      expect(
        find.byKey(const Key('post_save_life_os_insights_loading')),
        findsOneWidget,
      );

      insights.complete(_visibleInsights(finalizedEntryId: requestedEntryId!));
      await tester.pump();
      await tester.pump();

      final friction = find.byKey(const Key('quick_capture_friction_card'));
      final lifeOs = find.byKey(const Key('post_save_life_os_insights_card'));
      expect(lifeOs, findsOneWidget);
      expect(
        tester.getTopLeft(friction).dy,
        lessThan(tester.getTopLeft(lifeOs).dy),
      );
    },
  );

  testWidgets('live-voice semantic output fails closed without exact proof', (
    tester,
  ) async {
    final entries = [
      _entry(
        id: 'voice_prior',
        createdAt: DateTime.utc(2026, 7, 2, 10),
        transcript: 'I spoke to Sarah after lunch.',
        localAudioPath: '/tmp/prior.m4a',
      ),
      _entry(
        id: 'voice_latest',
        createdAt: DateTime.utc(2026, 7, 23, 11),
        transcript: 'I talked to Sarah about the project.',
        localAudioPath: '/tmp/live_voice_capture.m4a',
      ),
    ];
    final analyzed = await tester.runAsync(
      () => PostSaveLifeOsInsightsService().analyze(
        entries: entries,
        finalizedEntryId: 'voice_latest',
      ),
    );
    expect(analyzed?.isAiDerived, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PostSaveLifeOsInsightsCard(
            entryId: 'voice_latest',
            loader: () async => analyzed!,
          ),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      find.byKey(const Key('post_save_life_os_insights_empty')),
    );
    expect(find.textContaining('Sarah'), findsNothing);
    expect(find.textContaining('Entry ID:'), findsNothing);
  });
}
