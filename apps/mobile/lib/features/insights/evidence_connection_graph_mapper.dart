import 'dart:math' as math;
import 'dart:ui';

import 'package:archiveme_mobile/features/insights/models/evidence_connection_graph.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_state.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Loads journal rows by id. Matches `JournalStore.getById`.
typedef JournalEntryLookup = Future<JournalEntry?> Function(String id);

/// Builds an [EvidenceConnectionGraph] from a chat reply and cited entries.
class EvidenceConnectionGraphMapper {
  const EvidenceConnectionGraphMapper();

  static const String unavailableLabel = 'entry no longer available';
  static const String messageNodeId = 'message';
  static const String emptyMessageLabel = 'Reply';

  static const double nodeRadius = 18;
  static const double hitRadius = 28;
  static const double horizontalPadding = 56;
  static const double verticalPadding = 56;
  static const double linkRadius = 160;
  static const double canvasWidth = 560;

  /// One center message node plus one evidence node per cited entry.
  Future<EvidenceConnectionGraph> map({
    required PatternExplorationMessage message,
    required JournalEntryLookup getById,
  }) async {
    final citedIds = _uniqueCitedIds(message.citedEntryIds);
    final evidencePending = <_PendingEvidence>[];

    for (final entryId in citedIds) {
      evidencePending.add(await _loadEvidence(entryId, getById));
    }

    final evidenceCount = math.max(evidencePending.length, 1);
    final canvasHeight = math.max<double>(
      320,
      verticalPadding * 2 + evidenceCount * 72,
    );
    final canvasSize = Size(canvasWidth, canvasHeight);
    final center = Offset(canvasWidth / 2, canvasHeight / 2);

    final nodes = <EvidenceGraphNode>[
      EvidenceGraphNode(
        id: messageNodeId,
        label: _trim(message.content, 42, fallback: emptyMessageLabel),
        subtitle: _trim(message.content, 120, fallback: emptyMessageLabel),
        kind: EvidenceGraphNodeKind.message,
        position: center,
        excerpt: message.content.trim(),
      ),
      for (var i = 0; i < evidencePending.length; i++)
        evidencePending[i].toNode(
          _pointOnCircle(
            origin: center,
            index: i,
            total: evidencePending.length,
            radius: linkRadius,
          ),
        ),
    ];

    final edges = [
      for (final node in nodes)
        if (node.kind == EvidenceGraphNodeKind.evidence)
          EvidenceGraphEdge(fromId: messageNodeId, toId: node.id),
    ];

    return EvidenceConnectionGraph(
      nodes: nodes,
      edges: edges,
      canvasSize: canvasSize,
      messageNodeId: messageNodeId,
    );
  }

  Future<_PendingEvidence> _loadEvidence(
    String entryId,
    JournalEntryLookup getById,
  ) async {
    JournalEntry? entry;
    try {
      entry = await getById(entryId);
    } on Object {
      entry = null;
    }

    if (entry == null) {
      return _PendingEvidence(
        id: 'evidence-$entryId',
        label: unavailableLabel,
        subtitle: unavailableLabel,
        excerpt: unavailableLabel,
        entryId: entryId,
        available: false,
      );
    }

    final excerpt = entry.transcript.trim();
    final dateLabel = formatEvidenceDateLabel(entry.createdAt);
    return _PendingEvidence(
      id: 'evidence-$entryId',
      label: _trim(dateLabel, 18, fallback: 'Moment'),
      subtitle: _trim(excerpt, 72, fallback: ''),
      excerpt: excerpt,
      dateLabel: dateLabel,
      entryId: entryId,
    );
  }

  static List<String> _uniqueCitedIds(List<String> citedEntryIds) {
    final seen = <String>{};
    final unique = <String>[];
    for (final id in citedEntryIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      unique.add(trimmed);
    }
    return unique;
  }

  static Offset _pointOnCircle({
    required Offset origin,
    required int index,
    required int total,
    required double radius,
  }) {
    if (total <= 0) return origin;
    const startAngle = -math.pi / 2;
    final angle = startAngle + (2 * math.pi * index / total);
    return Offset(
      origin.dx + math.cos(angle) * radius,
      origin.dy + math.sin(angle) * radius,
    );
  }

  static String _trim(String value, int maxChars, {required String fallback}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return fallback;
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 1)}…';
  }

  /// Short date for a cited moment (UTC month/day so tests stay stable).
  static String formatEvidenceDateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _PendingEvidence {
  const _PendingEvidence({
    required this.id,
    required this.label,
    required this.entryId,
    this.subtitle,
    this.excerpt,
    this.dateLabel,
    this.available = true,
  });

  final String id;
  final String label;
  final String? subtitle;
  final String? excerpt;
  final String? dateLabel;
  final String entryId;
  final bool available;

  EvidenceGraphNode toNode(Offset position) {
    return EvidenceGraphNode(
      id: id,
      label: label,
      subtitle: subtitle,
      kind: EvidenceGraphNodeKind.evidence,
      position: position,
      entryId: entryId,
      excerpt: excerpt,
      dateLabel: dateLabel,
      available: available,
    );
  }
}
