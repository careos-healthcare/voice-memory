import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/features/ai_engines/on_device_extraction_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:voicememory_mobile/features/weekly_intelligence/weekly_delta_engine.dart';
import 'package:voicememory_mobile/features/weekly_intelligence/weekly_intelligence_models.dart';
import 'package:voicememory_mobile/features/weekly_intelligence/weekly_intelligence_sheet.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/hallucination_guard/hallucination_guard_service.dart';
import 'package:voicememory_mobile/services/notifications/sunday_digest_service.dart';
import 'package:voicememory_mobile/shared/ui/citation_playback_widget.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late LocalSemanticStore semanticStore;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('weekly_intelligence_');
    semanticStore = LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/semantic.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('aggregates paired week-over-week behavioral deltas locally', () async {
    final graph = _graph();
    await semanticStore.upsert(
      OnDeviceExtractionResult(
        entryId: 'current-action',
        graph: graph,
        intent: LocalEntryIntent.actionPlanning,
        tags: const {'goal', 'actionItem', 'habit', 'emotion', 'belief'},
        primaryTopics: const ['project'],
        embedding: Float32List.fromList([1, 0, 0]),
      ),
    );
    final snapshot = await WeeklyDeltaEngine(
      graph: graph,
      semanticStore: semanticStore,
      clock: () => DateTime.utc(2026, 7, 26, 12),
    ).aggregate();

    expect(
      snapshot.deltas.map((delta) => delta.dimension),
      containsAll([
        BehavioralDeltaDimension.actionIntentRatio,
        BehavioralDeltaDimension.emotionalVelocity,
        BehavioralDeltaDimension.habitDrift,
        BehavioralDeltaDimension.identityShift,
      ]),
    );
    for (final delta in snapshot.deltas) {
      expect(delta.explainability.evidence, hasLength(2));
      expect(
        delta.explainability.evidence.map((item) => item.sourceEntryId),
        containsAll(['baseline-intent', 'current-action']),
      );
    }
    expect(snapshot.localSemanticMatches, 1);
  });

  test('Sunday service schedules, caches, and falls back offline', () async {
    final prefs = await MobilePrefsStore.open('${root.path}/prefs.json');
    final backend = _FakeReminderBackend();
    final snapshot = _snapshot();
    final service = SundayDigestService(
      prefs: prefs,
      backend: backend,
      prefetch: () async => snapshot,
      clock: () => DateTime(2026, 7, 25, 12),
    );

    expect(await service.setEnabled(true), ReminderScheduleOutcome.scheduled);
    expect(backend.scheduledAt?.weekday, DateTime.sunday);
    expect(backend.title, SundayDigestService.title);
    expect(await service.prefetchIfDue(), same(snapshot));

    final offline = SundayDigestService(
      prefs: prefs,
      backend: backend,
      prefetch: () => Future.error(StateError('offline')),
      clock: () => DateTime(2026, 7, 26, 8),
    );
    final cached = await offline.prefetchIfDue();
    expect(cached, isNotNull);
    expect(cached!.fromCache, isTrue);
    expect(cached.deltas.single.id, 'intent-action');
  });

  testWidgets('sheet highlights graph and emits paired citation playback', (
    tester,
  ) async {
    final snapshot = _snapshot();
    Set<String>? highlighted;
    CitationPlaybackIntent? playbackIntent;
    final entries = {
      'baseline-intent': _entry(
        'baseline-intent',
        'I intend to begin the project',
        DateTime.utc(2026, 7, 10),
      ),
      'current-action': _entry(
        'current-action',
        'I completed the first project milestone',
        DateTime.utc(2026, 7, 24),
      ),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyIntelligenceSheet(
            load: () async => snapshot,
            onHighlightNodes: (value) => highlighted = value,
            hallucinationGuard: HallucinationGuardService(
              loadEntry: (id) async => entries[id],
            ),
            onPlaybackIntent: (value) => playbackIntent = value,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Intent moved toward action'));
    expect(highlighted, {'goal-project', 'action-project'});

    await tester.tap(find.byKey(const Key('ai_explainability_expand')));
    await tester.pump(const Duration(milliseconds: 400));
    final citation = find.byKey(const Key('citation_baseline-intent'));
    await tester.ensureVisible(citation);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(citation);
    await tester.pump(const Duration(milliseconds: 500));
    expect(playbackIntent?.sourceEntryId, 'baseline-intent');
    expect(playbackIntent?.audioTimestampMs, isNull);
  });
}

WeeklyIntelligenceSnapshot _snapshot() => WeeklyIntelligenceSnapshot(
  weekStart: DateTime.utc(2026, 7, 20),
  weekEnd: DateTime.utc(2026, 7, 27),
  baselineWeekCount: 3,
  localSemanticMatches: 2,
  generatedAt: DateTime.utc(2026, 7, 26),
  deltas: [
    ActionIntentRatio(
      id: 'intent-action',
      title: 'Intent moved toward action',
      statement: 'Project language moved from planning to execution.',
      magnitude: .5,
      direction: DeltaDirection.increased,
      nodeIds: const {'goal-project', 'action-project'},
      explainability: _explainability(),
      baselineIntentCount: 2,
      currentActionCount: 3,
      executionRatio: 1.5,
    ),
  ],
);

AiExplainability _explainability() => AiExplainability(
  confidence: 80,
  evidence: const [
    VerifiableCitation(
      sourceEntryId: 'baseline-intent',
      exactQuote: 'intend to begin',
      confidenceScore: .95,
      startUtf16: 2,
      endUtf16: 17,
    ),
    VerifiableCitation(
      sourceEntryId: 'current-action',
      exactQuote: 'completed the first',
      audioTimestampMs: 4200,
      confidenceScore: .96,
      startUtf16: 2,
      endUtf16: 21,
    ),
  ],
  reasoning: const [
    'Compared an earlier intention with a current execution statement.',
  ],
  alternativeExplanation: 'The completed milestone may have been small.',
  uncertainty: 'Unrecorded work is not represented.',
);

PersonalKnowledgeGraph _graph() {
  final baseline = DateTime.utc(2026, 7, 10);
  final current = DateTime.utc(2026, 7, 24);
  return PersonalKnowledgeGraph(
    nodes: [
      _node(
        'goal-project',
        NodeType.goal,
        'Begin project',
        'baseline-intent',
        baseline,
        'I intend to begin the project',
      ),
      _node(
        'action-project',
        NodeType.actionItem,
        'Complete milestone',
        'current-action',
        current,
        'I completed the first project milestone',
      ),
      GraphNode(
        id: 'habit-focus',
        type: NodeType.habit,
        label: 'Focused work',
        confidence: .9,
        evidence: [
          _evidence('baseline-intent', baseline, 'Focused work felt hard'),
          _evidence('current-action', current, 'Focused work happened daily'),
          _evidence('current-action', current, 'Focused work felt easier'),
        ],
      ),
      _node(
        'emotion-overwhelmed',
        NodeType.emotion,
        'overwhelmed',
        'baseline-intent',
        baseline,
        'I felt overwhelmed',
      ),
      _node(
        'emotion-calm',
        NodeType.emotion,
        'calm',
        'current-action',
        current,
        'I felt calm',
      ),
      _node(
        'belief-plan',
        NodeType.belief,
        'I plan carefully',
        'baseline-intent',
        baseline,
        'I plan carefully',
      ),
      _node(
        'belief-act',
        NodeType.belief,
        'I act quickly',
        'current-action',
        current,
        'I act quickly',
      ),
    ],
  );
}

GraphNode _node(
  String id,
  NodeType type,
  String label,
  String entryId,
  DateTime at,
  String quote,
) => GraphNode(
  id: id,
  type: type,
  label: label,
  confidence: .9,
  evidence: [_evidence(entryId, at, quote)],
);

GraphNodeEvidence _evidence(String entryId, DateTime at, String quote) =>
    GraphNodeEvidence(
      entryId: entryId,
      observedAt: at,
      confidence: .9,
      excerpt: quote,
      startUtf16: 0,
      endUtf16: quote.length,
    );

JournalEntry _entry(String id, String transcript, DateTime at) => JournalEntry(
  id: id,
  createdAt: at,
  transcript: transcript,
  durationSeconds: 30,
  reflection: const Reflection(
    mood: '',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

class _FakeReminderBackend implements CheckInReminderBackend {
  DateTime? scheduledAt;
  String? title;

  @override
  bool get isAvailable => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduledAt = when;
    this.title = title;
  }

  @override
  Future<void> cancel(String checkInId) async {}

  @override
  Future<void> clearAll() async {}
}
