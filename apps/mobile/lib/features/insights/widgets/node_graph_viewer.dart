import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/archive_theory/views/citation_badge.dart';
import 'package:archiveme_mobile/features/insights/models/theory_connection_graph.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

typedef InsightGraphNodeCallback = void Function(InsightGraphNode node);

/// Interactive force-style graph of theme ↔ memory ↔ counter-evidence links.
class NodeGraphViewer extends StatefulWidget {
  const NodeGraphViewer({
    required this.graph,
    super.key,
    this.onNodeTap,
    this.onCitationPlay,
    this.onOpenEntry,
  });

  final TheoryConnectionGraph graph;
  final InsightGraphNodeCallback? onNodeTap;
  final CitationPlaybackCallback? onCitationPlay;
  final InsightGraphNodeCallback? onOpenEntry;

  @override
  State<NodeGraphViewer> createState() => _NodeGraphViewerState();
}

class _NodeGraphViewerState extends State<NodeGraphViewer> {
  InsightGraphNode? _expandedNode;

  @override
  Widget build(BuildContext context) {
    final graph = widget.graph;
    final expanded = _expandedNode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LegendRow(),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warmBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                key: const Key('node_graph_interactive_viewer'),
                boundaryMargin: const EdgeInsets.all(48),
                minScale: 0.45,
                maxScale: 3,
                child: SizedBox(
                  width: graph.canvasSize.width,
                  height: graph.canvasSize.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        key: const Key('node_graph_canvas'),
                        size: graph.canvasSize,
                        painter: NodeGraphPainter(
                          graph: graph,
                          expandedNodeId: expanded?.id,
                        ),
                      ),
                      for (final node in graph.nodes)
                        _NodeHitTarget(
                          key: Key('node_hit_${node.id}'),
                          node: node,
                          expanded: expanded?.id == node.id,
                          onTap: () => _handleNodeTap(node),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (expanded != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _ExpandedNodePanel(
            node: expanded,
            onClose: () => setState(() => _expandedNode = null),
            onOpenEntry: expanded.isNavigable
                ? () => _openEntry(expanded)
                : null,
            onCitationPlay: expanded.supportsCitationPlayback &&
                    widget.onCitationPlay != null
                ? () => widget.onCitationPlay!(expanded.quote!)
                : null,
          ),
        ],
      ],
    );
  }

  void _handleNodeTap(InsightGraphNode node) {
    widget.onNodeTap?.call(node);
    setState(() {
      _expandedNode = _expandedNode?.id == node.id ? null : node;
    });
  }

  void _openEntry(InsightGraphNode node) {
    widget.onOpenEntry?.call(node);
    if (node.entryId == null) return;
    unawaited(context.push('/entry/${node.entryId}'));
  }
}

class _NodeHitTarget extends StatelessWidget {
  const _NodeHitTarget({
    required this.node,
    required this.onTap,
    required this.expanded,
    super.key,
  });

  final InsightGraphNode node;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final radius = TheoryConnectionGraphBuilder.hitRadius;
    return Positioned(
      left: node.position.dx - radius,
      top: node.position.dy - radius,
      child: Semantics(
        button: true,
        label: node.label,
        selected: expanded,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: radius * 2, height: radius * 2),
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: const [
        _LegendSwatch(
          color: AppColors.accentSecondary,
          label: 'Theme',
        ),
        _LegendSwatch(
          color: AppColors.accentPrimary,
          label: 'Memory',
        ),
        _LegendSwatch(
          color: AppColors.warning,
          label: 'Counter-evidence',
        ),
      ],
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: ArchiveMobileTypography.responsiveHelper(context)),
      ],
    );
  }
}

class _ExpandedNodePanel extends StatelessWidget {
  const _ExpandedNodePanel({
    required this.node,
    required this.onClose,
    this.onOpenEntry,
    this.onCitationPlay,
  });

  final InsightGraphNode node;
  final VoidCallback onClose;
  final VoidCallback? onOpenEntry;
  final VoidCallback? onCitationPlay;

  @override
  Widget build(BuildContext context) {
    final color = NodeGraphPainter.colorForKind(node.kind);

    return Container(
      key: Key('node_graph_expanded_${node.id}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.label,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          if (node.subtitle != null && node.subtitle!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              node.subtitle!,
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (onOpenEntry != null || onCitationPlay != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onOpenEntry != null)
                  OutlinedButton.icon(
                    key: Key('node_graph_open_entry_${node.id}'),
                    onPressed: onOpenEntry,
                    icon: const Icon(Icons.article_outlined, size: 18),
                    label: const Text('Open transcript'),
                  ),
                if (onCitationPlay != null && node.quote != null)
                  CitationBadge(
                    quote: node.quote!,
                    onTap: (_) => onCitationPlay!(),
                    compact: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class NodeGraphPainter extends CustomPainter {
  NodeGraphPainter({
    required this.graph,
    this.expandedNodeId,
  });

  final TheoryConnectionGraph graph;
  final String? expandedNodeId;

  static Color colorForKind(InsightGraphNodeKind kind) {
    return switch (kind) {
      InsightGraphNodeKind.theme => AppColors.accentSecondary,
      InsightGraphNodeKind.memory => AppColors.accentPrimary,
      InsightGraphNodeKind.counterEvidence => AppColors.warning,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final edge in graph.edges) {
      final from = graph.nodeById(edge.fromId)?.position;
      final to = graph.nodeById(edge.toId)?.position;
      if (from == null || to == null) continue;
      canvas.drawLine(from, to, edgePaint);
    }

    for (final node in graph.nodes) {
      _paintNode(canvas, node, expanded: node.id == expandedNodeId);
    }
  }

  void _paintNode(Canvas canvas, InsightGraphNode node, {required bool expanded}) {
    final color = colorForKind(node.kind);
    final radius = TheoryConnectionGraphBuilder.nodeRadius;
    final ringPaint = Paint()
      ..color = color.withValues(alpha: expanded ? 0.28 : 0.16)
      ..style = PaintingStyle.fill;
    final nodePaint = Paint()..color = color;

    canvas.drawCircle(node.position, radius + (expanded ? 8 : 4), ringPaint);
    canvas.drawCircle(node.position, radius, nodePaint);

    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    );
    final tp = TextPainter(
      text: TextSpan(text: node.label, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 120);

    final dx = node.position.dx - tp.width / 2;
    final dy = node.position.dy + radius + 8;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant NodeGraphPainter oldDelegate) {
    return oldDelegate.graph != graph ||
        oldDelegate.expandedNodeId != expandedNodeId;
  }
}

/// Full-screen sheet showing the connection graph for one theory.
Future<void> showTheoryConnectionGraphSheet(
  BuildContext context, {
  required TrackedTheory theory,
  CitationPlaybackCallback? onCitationPlay,
}) {
  final graph = const TheoryConnectionGraphBuilder().build(theory);
  if (graph.nodes.length <= 1) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.78;
      return SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Connection map',
                style: ArchiveMobileTypography.listTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                theory.statement,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ArchiveMobileTypography.explanationBody(context).copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: NodeGraphViewer(
                  key: Key('node_graph_viewer_${theory.id}'),
                  graph: graph,
                  onCitationPlay: onCitationPlay,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
