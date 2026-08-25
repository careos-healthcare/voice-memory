import 'dart:math' as math;
import 'dart:ui';

import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';

enum InsightGraphNodeKind { theme, memory, counterEvidence }

/// One node in the theory connection graph.
class InsightGraphNode {
  const InsightGraphNode({
    required this.id,
    required this.label,
    required this.kind,
    required this.position,
    this.subtitle,
    this.entryId,
    this.quote,
    this.excerpt,
  });

  final String id;
  final String label;
  final String? subtitle;
  final InsightGraphNodeKind kind;
  final Offset position;
  final String? entryId;
  final TheoryEvidenceQuote? quote;
  final String? excerpt;

  bool get isNavigable => entryId != null && entryId!.isNotEmpty;

  bool get supportsCitationPlayback => quote?.hasCitationPlayback ?? false;
}

class InsightGraphEdge {
  const InsightGraphEdge({required this.fromId, required this.toId});

  final String fromId;
  final String toId;
}

/// Layout-ready graph of theme ↔ memory ↔ counter-evidence links.
class TheoryConnectionGraph {
  const TheoryConnectionGraph({
    required this.nodes,
    required this.edges,
    required this.canvasSize,
    required this.themeNodeId,
  });

  final List<InsightGraphNode> nodes;
  final List<InsightGraphEdge> edges;
  final Size canvasSize;
  final String themeNodeId;

  InsightGraphNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }
}

/// Builds a positioned graph from [TrackedTheory] pipeline output.
class TheoryConnectionGraphBuilder {
  const TheoryConnectionGraphBuilder({
    this.maxMemoryNodes = 6,
    this.maxCounterNodes = 4,
  });

  final int maxMemoryNodes;
  final int maxCounterNodes;

  static const nodeRadius = 18.0;
  static const hitRadius = 28.0;
  static const horizontalPadding = 56.0;
  static const verticalPadding = 56.0;
  static const linkRadius = 190.0;

  TheoryConnectionGraph build(TrackedTheory theory) {
    final themeId = 'theme-${theory.id}';
    final memoryNodes = <_PendingNode>[];
    final counterNodes = <_PendingNode>[];
    final seenMemory = <String>{};
    final seenCounter = <String>{};

    void addMemory({
      required String entryId,
      required String label,
      String? subtitle,
      TheoryEvidenceQuote? quote,
      String? excerpt,
    }) {
      if (entryId.isEmpty || seenMemory.contains(entryId)) return;
      if (memoryNodes.length >= maxMemoryNodes) return;
      seenMemory.add(entryId);
      memoryNodes.add(
        _PendingNode(
          id: 'memory-$entryId',
          label: label,
          subtitle: subtitle,
          kind: InsightGraphNodeKind.memory,
          entryId: entryId,
          quote: quote,
          excerpt: excerpt,
        ),
      );
    }

    void addCounter({
      required String entryId,
      required String label,
      String? subtitle,
      TheoryEvidenceQuote? quote,
      String? excerpt,
    }) {
      if (entryId.isEmpty || seenCounter.contains(entryId)) return;
      if (counterNodes.length >= maxCounterNodes) return;
      seenCounter.add(entryId);
      counterNodes.add(
        _PendingNode(
          id: 'counter-$entryId',
          label: label,
          subtitle: subtitle,
          kind: InsightGraphNodeKind.counterEvidence,
          entryId: entryId,
          quote: quote,
          excerpt: excerpt,
        ),
      );
    }

    for (final quote in theory.supportingEvidence) {
      addMemory(
        entryId: quote.entryId,
        label: _shortLabel(quote.dateLabel, fallback: 'Memory'),
        subtitle: _trim(quote.quote, 72),
        quote: quote,
        excerpt: quote.quote,
      );
    }

    for (final quote in theory.contradictingEvidence) {
      addCounter(
        entryId: quote.entryId,
        label: _shortLabel(quote.dateLabel, fallback: 'Counter'),
        subtitle: _trim(quote.quote, 72),
        quote: quote,
        excerpt: quote.quote,
      );
    }

    final inspection = theory.inspection;
    if (inspection != null) {
      for (final chunk in inspection.retrievedChunks) {
        switch (chunk.role) {
          case TheoryRetrievalRole.supporting:
            addMemory(
              entryId: chunk.entryId,
              label: _shortLabel(
                chunk.recordedAt != null ? _formatDate(chunk.recordedAt!) : null,
                fallback: 'Memory',
              ),
              subtitle: _trim(chunk.excerpt, 72),
              excerpt: chunk.excerpt,
            );
          case TheoryRetrievalRole.counter:
            addCounter(
              entryId: chunk.entryId,
              label: _shortLabel(
                chunk.recordedAt != null ? _formatDate(chunk.recordedAt!) : null,
                fallback: 'Counter',
              ),
              subtitle: _trim(chunk.excerpt, 72),
              excerpt: chunk.excerpt,
            );
          case TheoryRetrievalRole.hybrid:
            addMemory(
              entryId: chunk.entryId,
              label: _shortLabel(
                chunk.recordedAt != null ? _formatDate(chunk.recordedAt!) : null,
                fallback: 'Memory',
              ),
              subtitle: _trim(chunk.excerpt, 72),
              excerpt: chunk.excerpt,
            );
        }
      }
    }

    final canvasHeight = math.max(
      320,
      verticalPadding * 2 +
          math.max(memoryNodes.length, 1) * 72 +
          math.max(counterNodes.length, 1) * 72,
    );
    const canvasWidth = 560.0;
    final canvasSize = Size(canvasWidth, canvasHeight.toDouble());
    final themeCenter = Offset(horizontalPadding + 72, canvasHeight / 2);

    final positioned = <InsightGraphNode>[
      InsightGraphNode(
        id: themeId,
        label: _trim(theory.statement, 42),
        subtitle: 'Recurring theme',
        kind: InsightGraphNodeKind.theme,
        position: themeCenter,
      ),
      ..._positionArc(
        pending: memoryNodes,
        origin: themeCenter,
        startAngle: -math.pi / 3,
        endAngle: math.pi / 3,
        radius: linkRadius,
      ),
      ..._positionArc(
        pending: counterNodes,
        origin: themeCenter,
        startAngle: math.pi / 6,
        endAngle: math.pi * 0.78,
        radius: linkRadius + 24,
      ),
    ];

    final edges = <InsightGraphEdge>[
      for (final node in positioned)
        if (node.kind != InsightGraphNodeKind.theme)
          InsightGraphEdge(fromId: themeId, toId: node.id),
    ];

    return TheoryConnectionGraph(
      nodes: positioned,
      edges: edges,
      canvasSize: canvasSize,
      themeNodeId: themeId,
    );
  }

  List<InsightGraphNode> _positionArc({
    required List<_PendingNode> pending,
    required Offset origin,
    required double startAngle,
    required double endAngle,
    required double radius,
  }) {
    if (pending.isEmpty) return const [];

    return [
      for (var i = 0; i < pending.length; i++)
        pending[i].toGraphNode(
          _pointOnArc(
            origin: origin,
            index: i,
            total: pending.length,
            startAngle: startAngle,
            endAngle: endAngle,
            radius: radius,
          ),
        ),
    ];
  }

  Offset _pointOnArc({
    required Offset origin,
    required int index,
    required int total,
    required double startAngle,
    required double endAngle,
    required double radius,
  }) {
    final angle = total <= 1
        ? (startAngle + endAngle) / 2
        : startAngle + (endAngle - startAngle) * (index / (total - 1));
    return Offset(
      origin.dx + math.cos(angle) * radius,
      origin.dy + math.sin(angle) * radius,
    );
  }

  static String _trim(String value, int maxChars) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 1)}…';
  }

  static String _shortLabel(String? label, {required String fallback}) {
    final trimmed = label?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return _trim(trimmed, 18);
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _PendingNode {
  const _PendingNode({
    required this.id,
    required this.label,
    required this.kind,
    required this.entryId,
    this.subtitle,
    this.quote,
    this.excerpt,
  });

  final String id;
  final String label;
  final String? subtitle;
  final InsightGraphNodeKind kind;
  final String entryId;
  final TheoryEvidenceQuote? quote;
  final String? excerpt;

  InsightGraphNode toGraphNode(Offset position) {
    return InsightGraphNode(
      id: id,
      label: label,
      subtitle: subtitle,
      kind: kind,
      position: position,
      entryId: entryId,
      quote: quote,
      excerpt: excerpt,
    );
  }
}
