import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archiveme_mobile/features/graph/domain/graph_topology.dart';
import 'package:archiveme_mobile/features/graph/presentation/graph_force_simulation.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Scale threshold below which expensive paint effects are skipped.
const graphCanvasLowDetailScaleThreshold = 0.6;

/// Node-based force-directed graph canvas with LOD-aware rendering.
class GraphCanvas extends StatefulWidget {
  const GraphCanvas({
    required this.topology,
    super.key,
    this.onNodeTap,
    this.canvasSize = const Size(960, 720),
    this.warmupTicks = 120,
  });

  final GraphTopology topology;
  final ValueChanged<GraphNodeRecord>? onNodeTap;
  final Size canvasSize;
  final int warmupTicks;

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late GraphForceSimulation _simulation;
  Ticker? _ticker;
  var _ticksRemaining = 0;
  var _layoutGeneration = 0;
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleTransformChanged);
    _resetSimulation();
    _startWarmup();
  }

  @override
  void didUpdateWidget(covariant GraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topology != widget.topology ||
        oldWidget.canvasSize != widget.canvasSize) {
      _resetSimulation();
      _startWarmup();
    }
  }

  void _resetSimulation() {
    _simulation = GraphForceSimulation.fromTopology(
      widget.topology,
      canvasSize: widget.canvasSize,
    );
  }

  void _startWarmup() {
    _ticker?.stop();
    _ticksRemaining = widget.warmupTicks;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_ticksRemaining <= 0) {
      _ticker?.stop();
      return;
    }
    _ticksRemaining--;
    _simulation.tick(
      center: Offset(widget.canvasSize.width / 2, widget.canvasSize.height / 2),
    );
    _layoutGeneration++;
    setState(() {});
  }

  void _handleTransformChanged() {
    setState(() {});
  }

  double get _viewportScale => graphCanvasScale(_transformationController);

  bool get _lowDetail => _viewportScale < graphCanvasLowDetailScaleThreshold;

  @override
  void dispose() {
    _ticker?.dispose();
    _transformationController
      ..removeListener(_handleTransformChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          key: const Key('graph_canvas_interactive_viewer'),
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(48),
          minScale: 0.35,
          maxScale: 3,
          child: SizedBox(
            width: widget.canvasSize.width,
            height: widget.canvasSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  key: const Key('graph_canvas_painter'),
                  size: widget.canvasSize,
                  painter: GraphCanvasPainter(
                    simulation: _simulation,
                    selectedNodeId: _selectedNodeId,
                    lowDetail: _lowDetail,
                    layoutGeneration: _layoutGeneration,
                  ),
                ),
                for (final node in _simulation.nodes)
                  _GraphNodeHitTarget(
                    key: Key('graph_node_hit_${node.id}'),
                    node: node,
                    selected: _selectedNodeId == node.id,
                    onTap: () => _handleNodeTap(node.record),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNodeTap(GraphNodeRecord node) {
    setState(() {
      _selectedNodeId = _selectedNodeId == node.id ? null : node.id;
    });
    widget.onNodeTap?.call(node);
  }
}

class _GraphNodeHitTarget extends StatelessWidget {
  const _GraphNodeHitTarget({
    required this.node,
    required this.onTap,
    required this.selected,
    super.key,
  });

  final GraphLayoutNode node;
  final VoidCallback onTap;
  final bool selected;

  static const hitRadius = 28.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: node.position.dx - hitRadius,
      top: node.position.dy - hitRadius,
      child: Semantics(
        button: true,
        label: node.record.label,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: hitRadius * 2,
              height: hitRadius * 2,
            ),
          ),
        ),
      ),
    );
  }
}

class GraphCanvasPainter extends CustomPainter {
  GraphCanvasPainter({
    required this.simulation,
    required this.lowDetail,
    required this.layoutGeneration,
    this.selectedNodeId,
  });

  final GraphForceSimulation simulation;
  final bool lowDetail;
  final int layoutGeneration;
  final String? selectedNodeId;

  static const nodeRadius = 16.0;

  static Color colorForKind(String kind) {
    return switch (kind) {
      'journal_entry' => AppColors.accentPrimary,
      'tension' => AppColors.warning,
      'next_action' => AppColors.accentSecondary,
      'theme' => AppColors.proofConfidenceMedium,
      _ => AppColors.textSecondary,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final nodeById = {for (final node in simulation.nodes) node.id: node};
    final seen = <String>{};

    for (final link in simulation.links) {
      final from = nodeById[link.fromId]?.position;
      final to = nodeById[link.toId]?.position;
      if (from == null || to == null) continue;
      final key = '${link.fromId}|${link.toId}';
      if (!seen.add(key)) continue;
      _paintEdge(canvas, from, to);
    }

    for (final node in simulation.nodes) {
      _paintNode(
        canvas,
        node,
        selected: node.id == selectedNodeId,
      );
    }
  }

  void _paintEdge(Canvas canvas, Offset from, Offset to) {
    if (lowDetail) {
      final paint = Paint()
        ..color = AppColors.borderSubtle
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(from, to, paint);
      return;
    }

    final paint = Paint()
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..shader = ui.Gradient.linear(
        from,
        to,
        [
          AppColors.accentPrimary.withValues(alpha: 0.18),
          AppColors.accentSecondary.withValues(alpha: 0.55),
        ],
      );
    canvas.drawLine(from, to, paint);
  }

  void _paintNode(
    Canvas canvas,
    GraphLayoutNode node, {
    required bool selected,
  }) {
    final color = colorForKind(node.record.kind);
    final radius = nodeRadius + (selected ? 2 : 0);

    if (!lowDetail) {
      final shadowPaint = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(
        node.position + const Offset(0, 3),
        radius + 3,
        shadowPaint,
      );
    }

    final ringPaint = Paint()
      ..color = color.withValues(alpha: selected ? 0.28 : 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(node.position, radius + (selected ? 7 : 4), ringPaint);

    final nodePaint = Paint()..color = color;
    canvas.drawCircle(node.position, radius, nodePaint);

    if (lowDetail) return;

    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    );
    final tp = TextPainter(
      text: TextSpan(text: node.record.label, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 128);

    tp.paint(
      canvas,
      Offset(
        node.position.dx - tp.width / 2,
        node.position.dy + radius + 8,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant GraphCanvasPainter oldDelegate) {
    return oldDelegate.layoutGeneration != layoutGeneration ||
        oldDelegate.lowDetail != lowDetail ||
        oldDelegate.selectedNodeId != selectedNodeId;
  }
}

/// Reads the horizontal (x-axis) viewport scale from a [TransformationController].
///
/// [Matrix4.getMaxScaleOnAxis] takes the largest scale across the x, y *and* z
/// bases. A 2D [InteractiveViewer] scales x/y uniformly but leaves the z basis
/// at 1, so getMaxScaleOnAxis never drops below 1 on zoom-out — the low-detail
/// path (see [_GraphCanvasState._lowDetail]) then never engages and the
/// expensive paint effects always run. The x-axis basis-vector length is the
/// true 2D zoom factor.
@visibleForTesting
double graphCanvasScale(TransformationController controller) {
  final storage = controller.value.storage;
  return math.sqrt(
    storage[0] * storage[0] + storage[1] * storage[1] + storage[2] * storage[2],
  );
}

@visibleForTesting
bool graphCanvasUsesLowDetail(TransformationController controller) {
  return graphCanvasScale(controller) < graphCanvasLowDetailScaleThreshold;
}
