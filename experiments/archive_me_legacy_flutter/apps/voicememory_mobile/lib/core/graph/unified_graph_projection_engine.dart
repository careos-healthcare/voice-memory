import '../../features/archive_evidence/comparable_evidence_text.dart';
import '../../features/insights/archive_insight.dart';
import '../../models/journal_entry.dart';
import '../engines/evidence_reference.dart';
import '../life_story/life_story_synthesis_engine.dart';
import 'graph_node.dart';
import 'personal_knowledge_graph.dart';

/// Projects every user-facing analytical artifact into one governed graph.
///
/// Projection is deliberately separate from semantic extraction. Every
/// projected node still carries an exact UTF-16 transcript citation, so the
/// graph never persists inferred text as evidence.
class UnifiedGraphProjectionEngine {
  const UnifiedGraphProjectionEngine();

  PersonalKnowledgeGraph project({
    required PersonalKnowledgeGraph base,
    required List<JournalEntry> entries,
    required List<ArchiveInsight> archiveInsights,
  }) {
    final coreNodes = base.nodes
        .where(
          (node) =>
              node.type != NodeType.journalEntry &&
              !(node.type == NodeType.chapter &&
                  node.id.startsWith('life-chapter_')) &&
              node.type != NodeType.identityShift &&
              node.type != NodeType.archiveInsight,
        )
        .toList();
    final coreEdges = base.edges
        .where((edge) => !_isProjectionEdge(edge))
        .toList();
    final projectionBase = PersonalKnowledgeGraph(
      schemaVersion: base.schemaVersion,
      nodes: coreNodes,
      edges: coreEdges,
      trajectories: base.trajectories,
      materialization: base.materialization,
    );
    final nodes = [...coreNodes];
    final edges = [...coreEdges];

    for (final entry in entries) {
      if (!_entryEligible(entry)) continue;
      final text = ComparableEvidenceText.userText(entry);
      if (text.isEmpty) continue;
      final evidence = GraphNodeEvidence(
        entryId: entry.id,
        observedAt: entry.createdAt,
        confidence: 1,
        excerpt: text,
        startUtf16: 0,
        endUtf16: text.length,
      );
      final entryNode = GraphNode(
        id: stableGraphId('journal-entry', [entry.id]),
        type: NodeType.journalEntry,
        label: _entryLabel(text),
        confidence: 1,
        evidence: [evidence],
      );
      nodes.add(entryNode);
      for (final entity in coreNodes) {
        final shared = entity.evidence.where(
          (item) => item.entryId == entry.id,
        );
        if (shared.isEmpty) continue;
        edges.add(
          GraphEdge(
            sourceNodeId: entryNode.id,
            targetNodeId: entity.id,
            type: EdgeType.recordedIn,
            isDirected: true,
            weight: entity.confidence,
            evidence: shared.map(_edgeEvidence),
          ),
        );
      }
    }

    final synthesis = LifeStorySynthesisEngine(projectionBase).synthesize();
    for (final chapter in synthesis.chapters) {
      final evidence = chapter.evidence.map(_nodeEvidence).toList();
      if (evidence.isEmpty) continue;
      final chapterNode = GraphNode(
        id: stableGraphId('life-chapter', [
          chapter.category.name,
          chapter.startedAt.toIso8601String(),
          chapter.endedAt.toIso8601String(),
        ]),
        type: NodeType.chapter,
        label: _titleCase(chapter.category.name),
        confidence: chapter.confidence,
        evidence: evidence,
      );
      nodes.removeWhere((node) => node.id == chapterNode.id);
      nodes.add(chapterNode);
      for (final entity in coreNodes) {
        final sharedIds = evidence.map((item) => item.entryId).toSet();
        final shared = entity.evidence.where(
          (item) => sharedIds.contains(item.entryId),
        );
        if (shared.isEmpty) continue;
        edges.add(
          GraphEdge(
            sourceNodeId: chapterNode.id,
            targetNodeId: entity.id,
            type: EdgeType.chapterContains,
            isDirected: true,
            weight: chapter.confidence,
            evidence: shared.map(_edgeEvidence),
          ),
        );
      }
    }

    for (final shift in synthesis.identityShifts) {
      final evidence = shift.evidence.map(_nodeEvidence).toList();
      if (evidence.isEmpty) continue;
      final shiftNode = GraphNode(
        id: stableGraphId('identity-shift', [
          shift.beforeBelief,
          shift.afterBelief,
          shift.boundary.toIso8601String(),
        ]),
        type: NodeType.identityShift,
        label: '${shift.beforeBelief} → ${shift.afterBelief}',
        confidence: shift.confidence,
        evidence: evidence,
      );
      nodes.add(shiftNode);
      _connectBelief(
        nodes: coreNodes,
        edges: edges,
        shift: shiftNode,
        label: shift.beforeBelief,
        type: EdgeType.shiftFrom,
      );
      _connectBelief(
        nodes: coreNodes,
        edges: edges,
        shift: shiftNode,
        label: shift.afterBelief,
        type: EdgeType.shiftTo,
      );
    }

    final entriesById = {
      for (final entry in entries)
        if (_entryEligible(entry)) entry.id: entry,
    };
    for (final insight in archiveInsights) {
      final citations = <GraphNodeEvidence>[];
      for (final item in insight.supportingEvidence) {
        final entry = entriesById[item.entryId];
        if (entry == null) continue;
        final text = ComparableEvidenceText.userText(entry);
        final start = text.indexOf(item.quote);
        if (start < 0 || item.quote.isEmpty) continue;
        citations.add(
          GraphNodeEvidence(
            entryId: item.entryId,
            observedAt: item.recordedAt,
            confidence: insight.confidence / 100,
            excerpt: item.quote,
            startUtf16: start,
            endUtf16: start + item.quote.length,
          ),
        );
      }
      if (citations.isEmpty) continue;
      final insightNode = GraphNode(
        id: stableGraphId('archive-insight', [insight.id]),
        type: NodeType.archiveInsight,
        label: insight.title,
        confidence: insight.confidence / 100,
        evidence: citations,
      );
      nodes.add(insightNode);
      final citationIds = citations.map((item) => item.entryId).toSet();
      for (final entity in coreNodes) {
        final shared = entity.evidence.where(
          (item) => citationIds.contains(item.entryId),
        );
        if (shared.isEmpty) continue;
        edges.add(
          GraphEdge(
            sourceNodeId: insightNode.id,
            targetNodeId: entity.id,
            type: EdgeType.concludesAbout,
            isDirected: true,
            weight: insight.confidence / 100,
            evidence: shared.map(_edgeEvidence),
          ),
        );
      }
    }

    return PersonalKnowledgeGraph(
      schemaVersion: base.schemaVersion,
      nodes: nodes,
      edges: edges,
      trajectories: base.trajectories,
      materialization: base.materialization,
    );
  }

  static bool _isProjectionEdge(GraphEdge edge) => switch (edge.type) {
    EdgeType.recordedIn ||
    EdgeType.chapterContains ||
    EdgeType.shiftFrom ||
    EdgeType.shiftTo ||
    EdgeType.concludesAbout => true,
    _ => false,
  };

  static bool _entryEligible(JournalEntry entry) =>
      !entry.isArchived &&
      !entry.keepSeparate &&
      !entry.treatAsNew &&
      entry.memorySurfacing != 'do_not_surface';

  static GraphNodeEvidence _nodeEvidence(EvidenceReference item) =>
      GraphNodeEvidence(
        entryId: item.entryId,
        observedAt: item.observedAt,
        confidence: item.confidence,
        excerpt: item.excerpt,
        startUtf16: item.startUtf16,
        endUtf16: item.endUtf16,
      );

  static GraphEdgeEvidence _edgeEvidence(GraphNodeEvidence item) =>
      GraphEdgeEvidence(
        entryId: item.entryId,
        observedAt: item.observedAt,
        confidence: item.confidence,
        excerpt: item.excerpt,
        startUtf16: item.startUtf16,
        endUtf16: item.endUtf16,
      );

  static void _connectBelief({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    required GraphNode shift,
    required String label,
    required EdgeType type,
  }) {
    final normalized = normalizeGraphLabel(label);
    for (final belief in nodes) {
      if (belief.type != NodeType.belief ||
          normalizeGraphLabel(belief.label) != normalized) {
        continue;
      }
      edges.add(
        GraphEdge(
          sourceNodeId: shift.id,
          targetNodeId: belief.id,
          type: type,
          isDirected: true,
          weight: shift.confidence,
          evidence: shift.evidence.map(_edgeEvidence),
        ),
      );
      return;
    }
  }

  static String _entryLabel(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = compact.length > 42
        ? '${compact.substring(0, 41)}…'
        : compact;
    return 'Voice memory · $preview';
  }

  static String _titleCase(String value) => value
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
