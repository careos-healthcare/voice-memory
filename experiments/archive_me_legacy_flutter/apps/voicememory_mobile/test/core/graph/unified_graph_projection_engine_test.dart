import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/unified_graph_projection_engine.dart';
import 'package:voicememory_mobile/features/insights/archive_insight.dart';
import 'package:voicememory_mobile/features/insights/insight_evidence.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  test('projects entries and archive intelligence with exact citations', () {
    const transcript = 'Alex helped me finish the studio plan.';
    final observedAt = DateTime.utc(2026, 7, 26);
    final entry = JournalEntry(
      id: 'entry-1',
      createdAt: observedAt,
      transcript: transcript,
      durationSeconds: 14,
      reflection: _reflection,
    );
    final alexStart = transcript.indexOf('Alex');
    final base = PersonalKnowledgeGraph(
      nodes: [
        GraphNode(
          id: 'alex',
          type: NodeType.person,
          label: 'Alex',
          confidence: .9,
          evidence: [
            GraphNodeEvidence(
              entryId: entry.id,
              observedAt: observedAt,
              confidence: .9,
              excerpt: 'Alex',
              startUtf16: alexStart,
              endUtf16: alexStart + 4,
            ),
          ],
        ),
      ],
    );
    final insight = ArchiveInsight(
      id: 'insight-1',
      type: ArchiveInsightType.prediction,
      title: 'Collaboration unlocks progress',
      summary: 'Support appears near completed projects.',
      confidence: 76,
      evidenceCount: 1,
      supportingEvidence: [
        InsightEvidenceLine(
          entryId: entry.id,
          quote: 'Alex helped me',
          recordedAt: observedAt,
        ),
      ],
      createdAt: observedAt,
    );

    final projected = const UnifiedGraphProjectionEngine().project(
      base: base,
      entries: [entry],
      archiveInsights: [insight],
    );

    expect(
      projected.nodes.where((node) => node.type == NodeType.journalEntry),
      hasLength(1),
    );
    final insightNode = projected.nodes.singleWhere(
      (node) => node.type == NodeType.archiveInsight,
    );
    expect(insightNode.evidence.single.isExactSliceOf(transcript), isTrue);
    expect(
      projected.edges.map((edge) => edge.type),
      containsAll([EdgeType.recordedIn, EdgeType.concludesAbout]),
    );
    expect(projected.nodes.every((node) => node.hasValidEvidence), isTrue);
    expect(projected.edges.every((edge) => edge.hasValidEvidence), isTrue);
  });
}

const _reflection = Reflection(
  mood: '',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);
