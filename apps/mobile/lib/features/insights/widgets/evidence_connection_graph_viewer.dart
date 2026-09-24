import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/insights/evidence_connection_graph_mapper.dart';
import 'package:archiveme_mobile/features/insights/models/evidence_connection_graph.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_state.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Interactive graph of a reply and the moments it cites.
class EvidenceConnectionGraphViewer extends StatefulWidget {
  const EvidenceConnectionGraphViewer({
    required this.graph,
    super.key,
    this.onNodeTap,
    this.onOpenEntry,
  });

  final EvidenceConnectionGraph graph;
  final ValueChanged<EvidenceGraphNode>? onNodeTap;
  final ValueChanged<EvidenceGraphNode>? onOpenEntry;

  @override
  State<EvidenceConnectionGraphViewer> createState() =>
      _EvidenceConnectionGraphViewerState();
}

class _EvidenceConnectionGraphViewerState
    extends State<EvidenceConnectionGraphViewer> {
  EvidenceGraphNode? _expandedNode;

  @override
  Widget build(BuildContext context) {
    final graph = widget.graph;
    final expanded = _expandedNode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EvidenceGraphLegend(),
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
                key: const Key('evidence_graph_interactive_viewer'),
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
                        key: const Key('evidence_graph_canvas'),
                        size: graph.canvasSize,
                        painter: EvidenceConnectionGraphPainter(
                          graph: graph,
                          expandedNodeId: expanded?.id,
                        ),
                      ),
                      for (final node in graph.nodes)
                        _EvidenceNodeHitTarget(
                          key: Key('evidence_hit_${node.id}'),
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
          _ExpandedEvidencePanel(
            node: expanded,
            onClose: () => setState(() => _expandedNode = null),
            onOpenEntry: expanded.isNavigable
                ? () => _openEntry(expanded)
                : null,
          ),
        ],
      ],
    );
  }

  void _handleNodeTap(EvidenceGraphNode node) {
    widget.onNodeTap?.call(node);
    setState(() {
      _expandedNode = _expandedNode?.id == node.id ? null : node;
    });
  }

  void _openEntry(EvidenceGraphNode node) {
    widget.onOpenEntry?.call(node);
    final entryId = node.entryId;
    if (entryId == null || entryId.isEmpty) return;
    unawaited(context.push('/entry/$entryId'));
  }
}

class _EvidenceNodeHitTarget extends StatelessWidget {
  const _EvidenceNodeHitTarget({
    required this.node,
    required this.onTap,
    required this.expanded,
    super.key,
  });

  final EvidenceGraphNode node;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    const radius = EvidenceConnectionGraphMapper.hitRadius;
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
            child: const SizedBox(
              width: EvidenceConnectionGraphMapper.hitRadius * 2,
              height: EvidenceConnectionGraphMapper.hitRadius * 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceGraphLegend extends StatelessWidget {
  const _EvidenceGraphLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _LegendSwatch(color: AppColors.accentPrimary, label: 'Reply'),
        _LegendSwatch(color: AppColors.accentSecondary, label: 'Cited moment'),
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

class _ExpandedEvidencePanel extends StatelessWidget {
  const _ExpandedEvidencePanel({
    required this.node,
    required this.onClose,
    this.onOpenEntry,
  });

  final EvidenceGraphNode node;
  final VoidCallback onClose;
  final VoidCallback? onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final color = EvidenceConnectionGraphPainter.colorForKind(node.kind);
    final detail = node.excerpt ?? node.subtitle;

    return Container(
      key: Key('evidence_graph_expanded_${node.id}'),
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
          if (node.dateLabel != null && node.dateLabel!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              node.dateLabel!,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail,
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (onOpenEntry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: Key('evidence_graph_open_entry_${node.id}'),
                onPressed: onOpenEntry,
                icon: const Icon(Icons.article_outlined, size: 18),
                label: const Text('Open transcript'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints reply/cited-moment nodes and the edges between them.
class EvidenceConnectionGraphPainter extends CustomPainter {
  EvidenceConnectionGraphPainter({
    required this.graph,
    this.expandedNodeId,
  });

  final EvidenceConnectionGraph graph;
  final String? expandedNodeId;

  static Color colorForKind(EvidenceGraphNodeKind kind) {
    return switch (kind) {
      EvidenceGraphNodeKind.message => AppColors.accentPrimary,
      EvidenceGraphNodeKind.evidence => AppColors.accentSecondary,
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

  void _paintNode(
    Canvas canvas,
    EvidenceGraphNode node, {
    required bool expanded,
  }) {
    final color = colorForKind(node.kind);
    const radius = EvidenceConnectionGraphMapper.nodeRadius;
    final ringPaint = Paint()
      ..color = color.withValues(alpha: expanded ? 0.28 : 0.16)
      ..style = PaintingStyle.fill;
    final nodePaint = Paint()..color = color;

    canvas
      ..drawCircle(node.position, radius + (expanded ? 8 : 4), ringPaint)
      ..drawCircle(node.position, radius, nodePaint);

    const labelStyle = TextStyle(
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
  bool shouldRepaint(covariant EvidenceConnectionGraphPainter oldDelegate) {
    return oldDelegate.graph != graph ||
        oldDelegate.expandedNodeId != expandedNodeId;
  }
}

/// Sheet that loads cited entries and shows how a reply connects to them.
Future<void> showEvidenceConnectionGraphSheet(
  BuildContext context, {
  required PatternExplorationMessage message,
  required JournalEntryLookup getById,
}) {
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
          child: EvidenceConnectionGraphSheet(
            message: message,
            getById: getById,
          ),
        ),
      );
    },
  );
}

/// Loads the citation graph and hosts [EvidenceConnectionGraphViewer].
class EvidenceConnectionGraphSheet extends StatefulWidget {
  const EvidenceConnectionGraphSheet({
    required this.message,
    required this.getById,
    super.key,
  });

  final PatternExplorationMessage message;
  final JournalEntryLookup getById;

  static const Key sheetKey = Key('evidence_connection_graph_sheet');
  static const String title = 'How this connects';
  static const String loadError = "Couldn't load these connections";

  @override
  State<EvidenceConnectionGraphSheet> createState() =>
      _EvidenceConnectionGraphSheetState();
}

class _EvidenceConnectionGraphSheetState
    extends State<EvidenceConnectionGraphSheet> {
  late final Future<EvidenceConnectionGraph> _graphFuture;

  @override
  void initState() {
    super.initState();
    _graphFuture = const EvidenceConnectionGraphMapper().map(
      message: widget.message,
      getById: widget.getById,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: EvidenceConnectionGraphSheet.sheetKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          EvidenceConnectionGraphSheet.title,
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.message.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ArchiveMobileTypography.explanationBody(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: FutureBuilder<EvidenceConnectionGraph>(
            future: _graphFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    EvidenceConnectionGraphSheet.loadError,
                    style: ArchiveMobileTypography.explanationBody(
                      context,
                    ).copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final graph = snapshot.data;
              if (graph == null) {
                return const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return EvidenceConnectionGraphViewer(
                key: const Key('evidence_connection_graph_viewer'),
                graph: graph,
              );
            },
          ),
        ),
      ],
    );
  }
}
