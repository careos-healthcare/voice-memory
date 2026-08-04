import 'package:flutter/material.dart';

import '../../../core/graph/graph_node.dart';
import '../../../core/graph/personal_knowledge_graph.dart';
import '../../../features/journal_playback/rich_memory_playback.dart';
import '../../../features/memory_graph/ui/graph_node_hero_animation.dart';
import '../../../models/journal_entry.dart';
import '../../../ui/screens/life_os/graph_painter.dart';

class HistoricalNodeSheet extends StatelessWidget {
  const HistoricalNodeSheet({
    super.key,
    required this.graph,
    required this.node,
    required this.targetTime,
    required this.entries,
    required this.onClose,
    this.onSelectConnectedNode,
  });

  final PersonalKnowledgeGraph graph;
  final GraphNode node;
  final DateTime targetTime;
  final List<JournalEntry> entries;
  final VoidCallback onClose;
  final ValueChanged<GraphNode>? onSelectConnectedNode;

  @override
  Widget build(BuildContext context) {
    final target = targetTime.toUtc();
    final evidence =
        node.evidence.where((item) => !item.observedAt.isAfter(target)).toList()
          ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    final evidenceIds = evidence.map((item) => item.entryId).toSet();
    final playable = entries
        .where(
          (entry) =>
              evidenceIds.contains(entry.id) &&
              !entry.createdAt.toUtc().isAfter(target) &&
              entry.localAudioReference?.isNotEmpty == true,
        )
        .take(3);
    final nodeById = {for (final item in graph.nodes) item.id: item};
    final connected = graph.edges
        .where(
          (edge) =>
              edge.sourceNodeId == node.id || edge.targetNodeId == node.id,
        )
        .map(
          (edge) =>
              nodeById[edge.sourceNodeId == node.id
                  ? edge.targetNodeId
                  : edge.sourceNodeId],
        )
        .whereType<GraphNode>()
        .toList();
    final date =
        '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
    return Material(
      key: const Key('historical-node-sheet'),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Semantics(
              liveRegion: true,
              label: 'Viewing ${node.label} as of $date, read only',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B6F47).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Viewing graph as of $date · Read only'),
                    ),
                    IconButton(
                      tooltip: 'Close historical details',
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GraphNodeHeroAnimation(
              node: node,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: knowledgeGraphNodeColor(node.type),
                    child: const Icon(Icons.history, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      node.label,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Text('${(node.confidence * 100).round()}%'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Evidence available by this date',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final item in evidence)
              ListTile(
                key: Key('historical-evidence-${item.entryId}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.format_quote),
                title: Text('“${item.excerpt}”'),
                subtitle: Text(item.observedAt.toLocal().toString()),
              ),
            for (final entry in playable)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: RichMemoryPlayback(entry: entry, hasProAccess: true),
              ),
            if (connected.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Connected at this time',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final item in connected)
                ListTile(
                  title: Text(item.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onSelectConnectedNode == null
                      ? null
                      : () => onSelectConnectedNode!(item),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
