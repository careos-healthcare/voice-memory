import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/graph/personal_knowledge_graph.dart';
import '../semantic_cluster.dart';
import 'cluster_boundary_overlay.dart';

typedef SemanticClusterPinCallback =
    FutureOr<void> Function(SemanticCluster cluster, bool pinned);
typedef SemanticClusterRenameCallback =
    FutureOr<void> Function(SemanticCluster cluster, String title);
typedef SemanticClusterMergeCallback =
    FutureOr<void> Function(
      SemanticCluster cluster,
      SemanticCluster otherCluster,
    );
typedef SemanticClusterSplitCallback =
    FutureOr<void> Function(SemanticCluster cluster);
typedef SemanticClusterSmallStepsCallback =
    FutureOr<void> Function(SemanticCluster cluster);
typedef SemanticClusterShareCallback =
    FutureOr<void> Function(SemanticCluster cluster);

class SemanticClustersSheet extends StatelessWidget {
  const SemanticClustersSheet({
    super.key,
    required this.clusters,
    required this.graph,
    this.initialClusterId,
    this.onClusterSelected,
    this.onPin,
    this.onRename,
    this.onMerge,
    this.onSplit,
    this.onTrySmallSteps,
    this.onShare,
  });

  final List<SemanticCluster> clusters;
  final PersonalKnowledgeGraph graph;
  final String? initialClusterId;
  final ValueChanged<SemanticCluster>? onClusterSelected;
  final SemanticClusterPinCallback? onPin;
  final SemanticClusterRenameCallback? onRename;
  final SemanticClusterMergeCallback? onMerge;
  final SemanticClusterSplitCallback? onSplit;
  final SemanticClusterSmallStepsCallback? onTrySmallSteps;
  final SemanticClusterShareCallback? onShare;

  static List<SemanticCluster> rankedClusters(
    List<SemanticCluster> clusters,
    PersonalKnowledgeGraph graph,
  ) {
    final result = clusters.toList();
    result.sort((left, right) {
      final velocity = right.activityVelocity.compareTo(left.activityVelocity);
      if (velocity != 0) return velocity;
      final valence = (_valence(right, graph) ?? double.negativeInfinity)
          .compareTo(_valence(left, graph) ?? double.negativeInfinity);
      return valence != 0 ? valence : left.title.compareTo(right.title);
    });
    return List.unmodifiable(result);
  }

  @override
  Widget build(BuildContext context) {
    final ranked = rankedClusters(clusters, graph).toList();
    if (initialClusterId != null) {
      ranked.sort((left, right) {
        if (left.id == initialClusterId) return -1;
        if (right.id == initialClusterId) return 1;
        return 0;
      });
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          key: const Key('semantic-clusters-sheet'),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .86),
          child: SafeArea(
            top: false,
            child: CustomScrollView(
              key: const Key('semantic-clusters-scroll-view'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Semantic clusters',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Related memories grouped by meaning and momentum.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                if (ranked.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No semantic clusters yet.')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
                    sliver: SliverList.builder(
                      itemCount: ranked.length,
                      itemBuilder: (context, index) {
                        final cluster = ranked[index];
                        return _ClusterCard(
                          cluster: cluster,
                          valence: _valence(cluster, graph),
                          selected: cluster.id == initialClusterId,
                          mergeCandidates: ranked
                              .where((item) => item.id != cluster.id)
                              .toList(),
                          onSelected: onClusterSelected,
                          onPin: onPin,
                          onRename: onRename,
                          onMerge: onMerge,
                          onSplit: onSplit,
                          onTrySmallSteps: onTrySmallSteps,
                          onShare: onShare,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double? _valence(
    SemanticCluster cluster,
    PersonalKnowledgeGraph graph,
  ) {
    final ids = cluster.nodeIds.toSet();
    final values = graph.edges
        .where(
          (edge) =>
              ids.contains(edge.sourceNodeId) &&
              ids.contains(edge.targetNodeId) &&
              edge.emotionalValenceScore != null,
        )
        .map((edge) => edge.emotionalValenceScore!)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left + right) / values.length;
  }
}

enum _ClusterAction { pin, rename, merge, split, share }

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({
    required this.cluster,
    required this.valence,
    required this.selected,
    required this.mergeCandidates,
    this.onSelected,
    this.onPin,
    this.onRename,
    this.onMerge,
    this.onSplit,
    this.onTrySmallSteps,
    this.onShare,
  });

  final SemanticCluster cluster;
  final double? valence;
  final bool selected;
  final List<SemanticCluster> mergeCandidates;
  final ValueChanged<SemanticCluster>? onSelected;
  final SemanticClusterPinCallback? onPin;
  final SemanticClusterRenameCallback? onRename;
  final SemanticClusterMergeCallback? onMerge;
  final SemanticClusterSplitCallback? onSplit;
  final SemanticClusterSmallStepsCallback? onTrySmallSteps;
  final SemanticClusterShareCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final color = semanticClusterCategoryColor(cluster.category);
    return Semantics(
      button: onSelected != null,
      selected: selected,
      label:
          '${cluster.title}, ${cluster.nodeIds.length} members, '
          '${(cluster.activityVelocity * 100).round()} percent activity',
      child: Card(
        key: Key('semantic-cluster-card-${cluster.id}'),
        color: color.withValues(alpha: selected ? .16 : .08),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: color.withValues(alpha: selected ? .75 : .3),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onSelected == null ? null : () => onSelected!(cluster),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  cluster.pinned ? Icons.push_pin : Icons.bubble_chart_outlined,
                  color: color,
                  semanticLabel: cluster.pinned ? 'Pinned' : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cluster.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cluster.summary.isEmpty
                            ? semanticClusterCategoryLabel(cluster.category)
                            : cluster.summary,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Metric(
                            label:
                                '${cluster.nodeIds.length} ${cluster.nodeIds.length == 1 ? 'member' : 'members'}',
                          ),
                          _Metric(
                            label:
                                '${(cluster.activityVelocity * 100).round()}% active',
                          ),
                          if (valence != null)
                            _Metric(
                              label:
                                  '${valence! >= 0 ? 'Positive' : 'Negative'} '
                                  '${(valence!.abs() * 100).round()}%',
                            ),
                        ],
                      ),
                      if (onTrySmallSteps != null) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          key: Key(
                            'semantic-cluster-small-steps-${cluster.id}',
                          ),
                          onPressed: () => onTrySmallSteps!(cluster),
                          icon: const Icon(Icons.spa_outlined, size: 18),
                          label: const Text('Try small steps'),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_ClusterAction>(
                  key: Key('semantic-cluster-actions-${cluster.id}'),
                  tooltip: 'Cluster actions',
                  onSelected: (action) => _perform(context, action),
                  itemBuilder: (context) => [
                    if (onPin != null)
                      PopupMenuItem(
                        value: _ClusterAction.pin,
                        child: Text(cluster.pinned ? 'Unpin' : 'Pin'),
                      ),
                    if (onRename != null)
                      const PopupMenuItem(
                        value: _ClusterAction.rename,
                        child: Text('Rename'),
                      ),
                    if (onMerge != null && mergeCandidates.isNotEmpty)
                      const PopupMenuItem(
                        value: _ClusterAction.merge,
                        child: Text('Merge'),
                      ),
                    if (onSplit != null && cluster.nodeIds.length >= 4)
                      const PopupMenuItem(
                        value: _ClusterAction.split,
                        child: Text('Split'),
                      ),
                    if (onShare != null)
                      const PopupMenuItem(
                        value: _ClusterAction.share,
                        child: Text('Share encrypted copy'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _perform(BuildContext context, _ClusterAction action) async {
    switch (action) {
      case _ClusterAction.pin:
        await onPin?.call(cluster, !cluster.pinned);
        return;
      case _ClusterAction.rename:
        final title = await showDialog<String>(
          context: context,
          builder: (_) => _RenameClusterDialog(initialTitle: cluster.title),
        );
        if (title != null && title.isNotEmpty) {
          await onRename?.call(cluster, title);
        }
        return;
      case _ClusterAction.merge:
        final other = await showDialog<SemanticCluster>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Merge with…'),
            children: [
              for (final candidate in mergeCandidates)
                SimpleDialogOption(
                  key: Key(
                    'semantic-cluster-merge-${cluster.id}-${candidate.id}',
                  ),
                  onPressed: () => Navigator.pop(dialogContext, candidate),
                  child: Text(candidate.title),
                ),
            ],
          ),
        );
        if (other != null) await onMerge?.call(cluster, other);
        return;
      case _ClusterAction.split:
        await onSplit?.call(cluster);
        return;
      case _ClusterAction.share:
        await onShare?.call(cluster);
        return;
    }
  }
}

class _RenameClusterDialog extends StatefulWidget {
  const _RenameClusterDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameClusterDialog> createState() => _RenameClusterDialogState();
}

class _RenameClusterDialogState extends State<_RenameClusterDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename cluster'),
    content: TextField(
      key: const Key('semantic-cluster-rename-field'),
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Cluster name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .66),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    ),
  );
}
