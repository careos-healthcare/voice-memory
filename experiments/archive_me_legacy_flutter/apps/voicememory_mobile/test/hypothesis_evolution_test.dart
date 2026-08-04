import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/features/ai_engines/models/hypothesis_evolution.dart';
import 'package:voicememory_mobile/features/archive_intelligence/hypothesis_tracking_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/hallucination_guard/hallucination_guard_service.dart';
import 'package:voicememory_mobile/shared/ui/charts/confidence_evolution_chart.dart';
import 'package:voicememory_mobile/shared/ui/citation_playback_widget.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';
import 'package:voicememory_mobile/ui/screens/life_os/graph_painter.dart';
import 'package:voicememory_mobile/ui/screens/life_os/knowledge_graph_layout.dart';

void main() {
  test(
    'tracking appends snapshots to a stable theory without duplicates',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'hypothesis_tracking_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final store = LocalSemanticStore(
        storage: EncryptedJsonFileStore(
          file: File('${root.path}/semantic.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      );
      final engine = HypothesisTrackingEngine(store);
      final citation = _citation;
      final first = await engine.track(
        statement: 'Work pressure may interrupt restorative habits.',
        confidenceScore: 20,
        triggeringEvidence: citation,
        deltaReasoning: 'Initial exact quote created the working theory.',
        date: DateTime.utc(2026, 1, 1),
      );
      final second = await engine.track(
        theoryId: first.theoryId,
        statement: first.statement,
        confidenceScore: 54,
        triggeringEvidence: citation,
        deltaReasoning: 'Repeated mentions strengthened the working theory.',
        date: DateTime.utc(2026, 2, 1),
      );
      final duplicate = await engine.track(
        theoryId: first.theoryId,
        statement: first.statement,
        confidenceScore: 54,
        triggeringEvidence: citation,
        deltaReasoning: 'Repeated mentions strengthened the working theory.',
        date: DateTime.utc(2026, 2, 1),
      );

      expect(second.theoryId, first.theoryId);
      expect(second.evolutionHistory.map((item) => item.confidenceScore), [
        20,
        54,
      ]);
      expect(duplicate.evolutionHistory, hasLength(2));
      expect(await engine.activeHypotheses(), hasLength(1));
    },
  );

  test('graph maturation scales node solidity and edge permanence', () {
    final evidence = GraphNodeEvidence(
      entryId: 'entry-1',
      observedAt: DateTime.utc(2026),
      confidence: .9,
      excerpt: 'Work pressure',
      startUtf16: 0,
      endUtf16: 13,
    );
    final early = GraphNode(
      id: 'early',
      type: NodeType.belief,
      label: 'Early theory',
      confidence: .2,
      evidence: [evidence],
    );
    final mature = GraphNode(
      id: 'mature',
      type: NodeType.belief,
      label: 'Mature theory',
      confidence: .94,
      evidence: [evidence],
    );
    final edgeEvidence = GraphEdgeEvidence(
      entryId: 'entry-1',
      observedAt: DateTime.utc(2026),
      confidence: .9,
      excerpt: 'Work pressure',
      startUtf16: 0,
      endUtf16: 13,
    );
    final tentativeEdge = GraphEdge(
      sourceNodeId: early.id,
      targetNodeId: mature.id,
      type: EdgeType.associatedWith,
      isDirected: false,
      weight: .2,
      evidence: [edgeEvidence],
    );
    final matureEdge = GraphEdge(
      sourceNodeId: early.id,
      targetNodeId: mature.id,
      type: EdgeType.associatedWith,
      isDirected: false,
      weight: .94,
      evidence: [edgeEvidence],
    );

    expect(
      knowledgeGraphNodeRadius(mature),
      greaterThan(knowledgeGraphNodeRadius(early)),
    );
    expect(
      knowledgeGraphNodeOpacity(mature),
      greaterThan(knowledgeGraphNodeOpacity(early)),
    );
    expect(knowledgeGraphEdgeIsDashed(tentativeEdge), isTrue);
    expect(knowledgeGraphEdgeIsDashed(matureEdge), isFalse);
  });

  testWidgets(
    'sparkline opens trajectory and historical citation emits playback',
    (tester) async {
      final entry = JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026, 1, 1),
        transcript: 'Work pressure made me skip the walk.',
        durationSeconds: 20,
        reflection: const Reflection(
          mood: '',
          emotionalIntensity: 0,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      );
      final guard = HallucinationGuardService(loadEntry: (_) async => entry);
      CitationPlaybackIntent? playbackIntent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfidenceEvolutionSparkline(
              theoryId: 'theory-work-walk',
              history: [
                ConfidenceSnapshot(
                  date: DateTime.utc(2026, 1, 1),
                  confidenceScore: 20,
                  triggeringEvidence: _citation,
                  deltaReasoning:
                      'The first exact quote suggested a possibility.',
                ),
                ConfidenceSnapshot(
                  date: DateTime.utc(2026, 2, 1),
                  confidenceScore: 54,
                  triggeringEvidence: _citation,
                  deltaReasoning:
                      'A repeated exact quote strengthened the pattern.',
                ),
              ],
              guard: guard,
              onPlaybackIntent: (intent) => playbackIntent = intent,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('confidence_evolution_sparkline')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('theory_trajectory_sheet')), findsOneWidget);
      expect(find.text('Week 1: 20%'), findsOneWidget);
      expect(find.text('Week 2: 54%'), findsOneWidget);
      await tester.pump();
      final citation = find.byKey(const Key('citation_entry-1')).first;
      await tester.ensureVisible(citation);
      await tester.tap(citation);
      expect(playbackIntent?.sourceEntryId, 'entry-1');
      expect(playbackIntent?.audioTimestampMs, 4200);
    },
  );
}

const _citation = VerifiableCitation(
  sourceEntryId: 'entry-1',
  exactQuote: 'Work pressure made me skip the walk.',
  audioTimestampMs: 4200,
  confidenceScore: .96,
  startUtf16: 0,
  endUtf16: 36,
);
