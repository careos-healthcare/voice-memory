import 'dart:math' as math;
import 'dart:ui' show PathMetric, PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/graph/graph_node.dart';
import '../../../features/memory_graph/performance/graph_performance_monitor.dart';
import '../../../features/memory_graph/rendering/graph_lod_engine.dart';
import '../../../features/memory_graph/rendering/memory_graph_visual_style.dart';
import '../../../services/analytics/frame_performance_tracker.dart';
import 'knowledge_graph_layout.dart';

/// Mutable paint-only state. Selection changes repaint without rebuilding the
/// InteractiveViewer or CustomPaint subtree.
class KnowledgeGraphViewState extends ChangeNotifier {
  String? get selectedId => _selectedId;
  String? _selectedId;

  set selectedId(String? value) {
    if (_selectedId == value) return;
    _selectedId = value;
    notifyListeners();
  }
}

class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.layout,
    required this.edges,
    required this.viewState,
    required this.transformationController,
    required this.viewportSize,
    Animation<double>? pulse,
    this.newNodeIds = const {},
    this.newEdgeIds = const {},
    this.highlightedNodeIds = const {},
    this.historyMode = false,
    this.visualStyle = MemoryGraphVisualStyle.fallback,
    this.textScaler = TextScaler.noScaling,
    required this.onSemanticTap,
  }) : pulse = pulse ?? const AlwaysStoppedAnimation<double>(1),
       super(
         repaint: Listenable.merge([
           viewState,
           pulse ?? const AlwaysStoppedAnimation<double>(1),
           transformationController,
         ]),
       );

  final KnowledgeGraphLayout layout;
  final List<GraphEdge> edges;
  final KnowledgeGraphViewState viewState;
  final TransformationController transformationController;
  final Size viewportSize;
  final Animation<double> pulse;
  final Set<String> newNodeIds;
  final Set<String> newEdgeIds;
  final Set<String> highlightedNodeIds;
  final bool historyMode;
  final MemoryGraphVisualStyle visualStyle;
  final TextScaler textScaler;
  final ValueChanged<GraphNode> onSemanticTap;
  final Map<String, Path> _edgePathCache = {};
  final Map<String, List<PathMetric>> _edgeMetricCache = {};
  final Map<String, Path> _dashedPathCache = {};

  late final Set<String> _validNodeIds = layout.nodes
      .where((node) => node.hasValidEvidence)
      .map((node) => node.id)
      .toSet();
  late final Map<String, List<GraphEdge>> _adjacentEdges = _buildAdjacency();

  Iterable<GraphNode> get _visibleNodes => _nodesForViewport();

  int get visibleEdgeCount => edges.where(_isVisibleEdge).length;
  int get directedEdgeCount =>
      edges.where((edge) => edge.isDirected && _isVisibleEdge(edge)).length;
  int get weightedEdgeCount =>
      edges.where((edge) => edge.weight > 0 && _isVisibleEdge(edge)).length;

  bool _isVisibleEdge(GraphEdge edge) =>
      edge.hasValidEvidence &&
      _validNodeIds.contains(edge.sourceNodeId) &&
      _validNodeIds.contains(edge.targetNodeId) &&
      layout.positions.containsKey(edge.sourceNodeId) &&
      layout.positions.containsKey(edge.targetNodeId);

  Map<String, List<GraphEdge>> _buildAdjacency() {
    final result = <String, List<GraphEdge>>{};
    for (final edge in edges.where(_isVisibleEdge)) {
      result.putIfAbsent(edge.sourceNodeId, () => []).add(edge);
      result.putIfAbsent(edge.targetNodeId, () => []).add(edge);
    }
    return result;
  }

  Rect _sceneViewport() {
    if (viewportSize.isEmpty) return Offset.zero & layout.size;
    final corners = [
      transformationController.toScene(Offset.zero),
      transformationController.toScene(Offset(viewportSize.width, 0)),
      transformationController.toScene(Offset(0, viewportSize.height)),
      transformationController.toScene(
        Offset(viewportSize.width, viewportSize.height),
      ),
    ];
    final left = corners.map((point) => point.dx).reduce(math.min);
    final top = corners.map((point) => point.dy).reduce(math.min);
    final right = corners.map((point) => point.dx).reduce(math.max);
    final bottom = corners.map((point) => point.dy).reduce(math.max);
    return Rect.fromLTRB(left, top, right, bottom).inflate(56);
  }

  List<GraphNode> _nodesForViewport() => layout
      .nodesIn(_sceneViewport())
      .where((node) => node.hasValidEvidence)
      .toList(growable: false);

  List<GraphEdge> _edgesForNodes(Iterable<GraphNode> nodes) {
    final result = <GraphEdge>[];
    final seen = <String>{};
    for (final node in nodes) {
      for (final edge in _adjacentEdges[node.id] ?? const <GraphEdge>[]) {
        if (seen.add(edge.id)) result.add(edge);
      }
    }
    return result;
  }

  Path _edgePath(GraphEdge edge, Offset source, Offset target) =>
      _edgePathCache.putIfAbsent(edge.id, () {
        final control = _curveControl(edge, source, target);
        return Path()
          ..moveTo(source.dx, source.dy)
          ..quadraticBezierTo(control.dx, control.dy, target.dx, target.dy);
      });

  List<PathMetric> _edgeMetrics(String edgeId, Path path) => _edgeMetricCache
      .putIfAbsent(edgeId, () => path.computeMetrics().toList(growable: false));

  Path _dashedPath(String edgeId, Path path) =>
      _dashedPathCache.putIfAbsent(edgeId, () {
        final dashed = Path();
        for (final metric in _edgeMetrics(edgeId, path)) {
          var distance = 0.0;
          while (distance < metric.length) {
            final end = math.min(distance + 6, metric.length);
            dashed.addPath(metric.extractPath(distance, end), Offset.zero);
            distance += 10;
          }
        }
        return dashed;
      });

  Set<String> _connectedIds(Iterable<GraphEdge> visibleEdges) {
    final selectedId = viewState.selectedId;
    if (selectedId == null) return const {};
    final result = <String>{selectedId};
    for (final edge in visibleEdges) {
      if (edge.sourceNodeId == selectedId) result.add(edge.targetNodeId);
      if (edge.targetNodeId == selectedId) result.add(edge.sourceNodeId);
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = visualStyle.background,
    );
    if (historyMode) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = visualStyle.warning.withValues(alpha: .055),
      );
      final grid = Paint()
        ..color = visualStyle.grid
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 48) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
      for (var y = 0.0; y < size.height; y += 48) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }
    final scale = transformationController.value.getMaxScaleOnAxis();
    final quality = FramePerformanceTracker.installed?.qualityTier;
    final lod = GraphLODEngine.forScale(
      scale,
      qualityPenalty: switch (quality) {
        ApexQualityTier.balanced => 1,
        ApexQualityTier.constrained || ApexQualityTier.survival => 2,
        _ => 0,
      },
    );
    final pulseValue = lod.showAnimations ? pulse.value : 1.0;
    final visibleNodes = _nodesForViewport();
    final visibleEdges = _edgesForNodes(visibleNodes);
    GraphPerformanceMonitor.instance.recordCulling(
      activeNodes: layout.nodes.length,
      visibleNodes: visibleNodes.length,
      visibleEdges: visibleEdges.length,
    );
    final selectedId = viewState.selectedId;
    final connected = _connectedIds(visibleEdges);
    if (lod.level == GraphLODLevel.far) {
      final batchedEdges = Path();
      for (
        var index = 0;
        index < visibleEdges.length;
        index += lod.edgeStride
      ) {
        final edge = visibleEdges[index];
        final source = layout.positions[edge.sourceNodeId];
        final target = layout.positions[edge.targetNodeId];
        if (source == null || target == null) continue;
        batchedEdges
          ..moveTo(source.dx, source.dy)
          ..lineTo(target.dx, target.dy);
      }
      canvas.drawPath(
        batchedEdges,
        Paint()
          ..color = visualStyle.edge.withValues(alpha: .25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    } else {
      for (final edge in visibleEdges) {
        if (!_isVisibleEdge(edge)) continue;
        final source = layout.positions[edge.sourceNodeId];
        final target = layout.positions[edge.targetNodeId];
        if (source == null || target == null) continue;
        final highlighted =
            selectedId != null &&
            (edge.sourceNodeId == selectedId ||
                edge.targetNodeId == selectedId);
        final temporalColor = _edgeValenceColor(edge);
        final paint = Paint()
          ..color = highlighted
              ? visualStyle.selection
              : temporalColor.withValues(
                  alpha: newEdgeIds.contains(edge.id)
                      ? 0.35 + pulseValue * 0.55
                      : 0.22 + edge.weight.clamp(0.0, 1.0) * 0.58,
                )
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth =
              (0.75 + edge.weight.clamp(0.0, 1.0) * 2.8) *
              (highlighted ? 1.45 : 1);
        final control = _curveControl(edge, source, target);
        final path = _edgePath(edge, source, target);
        if (edge.weight >= .85) {
          canvas.drawPath(
            path,
            Paint()
              ..color = paint.color.withValues(alpha: .2 + pulseValue * .12)
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth =
                  paint.strokeWidth + 2 + visualStyle.glowDiffusion * 4,
          );
        }
        if (newEdgeIds.contains(edge.id)) {
          for (final metric in _edgeMetrics(edge.id, path)) {
            canvas.drawPath(
              metric.extractPath(0, metric.length * pulseValue.clamp(0.08, 1)),
              paint,
            );
          }
        } else if (knowledgeGraphEdgeIsDashed(edge, historyMode: historyMode)) {
          canvas.drawPath(_dashedPath(edge.id, path), paint);
        } else {
          canvas.drawPath(path, paint);
        }
        if (edge.isDirected && lod.showDirectedArrows) {
          _drawArrow(canvas, control, target, paint);
        }
      }
    }

    if (lod.level == GraphLODLevel.far) {
      canvas.drawPoints(
        PointMode.points,
        [for (final node in visibleNodes) layout.positions[node.id]!],
        Paint()
          ..color = visualStyle.edge.withValues(alpha: .8)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final labeled = visibleNodes.toList()
      ..sort((a, b) {
        final evidence = b.evidence.length.compareTo(a.evidence.length);
        return evidence != 0 ? evidence : a.id.compareTo(b.id);
      });
    final labelIds = labeled
        .take(lod.maximumLabels)
        .map((node) => node.id)
        .toSet();
    for (final node in visibleNodes) {
      final point = layout.positions[node.id]!;
      final selected = node.id == selectedId;
      final connectedToSelection = connected.contains(node.id);
      final radius = knowledgeGraphNodeRadius(node);
      if (lod.level == GraphLODLevel.close) {
        final card = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: point,
            width: math.max(56, radius * 4.2),
            height: math.max(38, radius * 2.5),
          ),
          const Radius.circular(16),
        );
        if (lod.showShadows) {
          canvas.drawShadow(
            Path()..addRRect(card),
            visualStyle.cardShadow,
            5,
            false,
          );
        }
        canvas.drawRRect(card, Paint()..color = visualStyle.cardSurface);
      }
      if (node.confidence < .4) {
        canvas.drawCircle(
          point,
          radius + 2 + pulseValue * 2,
          Paint()
            ..color = visualStyle
                .nodeColor(node.type)
                .withValues(alpha: .08 + pulseValue * .1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      if (newNodeIds.contains(node.id)) {
        canvas.drawCircle(
          point,
          radius +
              4 +
              visualStyle.glowDiffusion * 5 +
              pulseValue * 7 * visualStyle.glowDiffusion,
          Paint()
            ..color = visualStyle
                .nodeColor(node.type)
                .withValues(
                  alpha: (0.12 + pulseValue * 0.25 * visualStyle.glowDiffusion)
                      .clamp(0, 1),
                )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      if (highlightedNodeIds.contains(node.id)) {
        canvas.drawCircle(
          point,
          radius + 6 + pulseValue * 4,
          Paint()
            ..color = visualStyle.selection
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 + pulseValue,
        );
      }
      canvas.drawCircle(
        point,
        radius +
            (selected
                ? 4
                : connectedToSelection
                ? 2
                : 0),
        Paint()
          ..color = selected
              ? visualStyle.labelText
              : connectedToSelection
              ? visualStyle.selection
              : visualStyle.cardSurface,
      );
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color =
              highlightedNodeIds.isNotEmpty &&
                  !highlightedNodeIds.contains(node.id)
              ? visualStyle.nodeColor(node.type).withValues(alpha: .2)
              : visualStyle
                    .nodeColor(node.type)
                    .withValues(alpha: knowledgeGraphNodeOpacity(node)),
      );
      if (node.origin == NodeOrigin.manual) {
        final metallic = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFF3B0), Color(0xFFC99700), Color(0xFFFFD166)],
          ).createShader(Rect.fromCircle(center: point, radius: radius + 2))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5;
        canvas.drawCircle(point, radius + 2, metallic);
        canvas.drawCircle(
          point.translate(radius * .55, -radius * .55),
          4,
          Paint()..color = const Color(0xFFFFD166),
        );
      }
      if (node.origin == NodeOrigin.external) {
        final sourceColor = switch (node.externalSource) {
          ExternalSource.appleHealth => const Color(0xFFFF4D7D),
          ExternalSource.spotify => const Color(0xFF1ED760),
          null => const Color(0xFF5B8DEF),
        };
        canvas.drawCircle(
          point,
          radius + 2 + pulseValue * 1.5,
          Paint()
            ..color = sourceColor.withValues(alpha: .75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = node.externalSource == ExternalSource.appleHealth
                ? 3
                : 2.5,
        );
        canvas.drawCircle(
          point.translate(radius * .58, -radius * .58),
          4,
          Paint()..color = sourceColor,
        );
      }
      if (node.origin == NodeOrigin.document) {
        final documentColor = visualStyle.documentNode;
        canvas.drawCircle(
          point,
          radius + 2 + pulseValue,
          Paint()
            ..color = documentColor.withValues(alpha: .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        final badgeCenter = point.translate(radius * .58, -radius * .58);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: badgeCenter, width: 8, height: 9),
            const Radius.circular(1.5),
          ),
          Paint()..color = documentColor,
        );
        canvas.drawLine(
          badgeCenter.translate(0, -2.5),
          badgeCenter.translate(0, 2.5),
          Paint()
            ..color = visualStyle.labelSurface
            ..strokeWidth = 1,
        );
      }
      if (lod.showMediaBadges && node.mediaAttachments.isNotEmpty) {
        _drawMediaBadge(canvas, point, radius);
      }
      if (lod.showLabels &&
          (highlightedNodeIds.isEmpty ||
              highlightedNodeIds.contains(node.id)) &&
          (labelIds.contains(node.id) || selected)) {
        final painter = TextPainter(
          text: TextSpan(
            text: node.label.length > 22
                ? '${node.label.substring(0, 21)}…'
                : node.label,
            style: TextStyle(
              color: visualStyle.labelText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              backgroundColor: visualStyle.labelSurface,
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 130);
        painter.paint(canvas, point + Offset(-painter.width / 2, radius + 4));
      }
    }
  }

  Color _edgeValenceColor(GraphEdge edge) {
    final valence = edge.emotionalValenceScore;
    if (valence == null) return visualStyle.edge;
    if (valence > .15) return visualStyle.positive;
    if (valence < -.15) return visualStyle.negative;
    return visualStyle.warning;
  }

  static void _drawMediaBadge(Canvas canvas, Offset center, double radius) {
    final badgeCenter = center.translate(radius * .68, radius * .68);
    final badge = RRect.fromRectAndRadius(
      Rect.fromCenter(center: badgeCenter, width: 14, height: 12),
      const Radius.circular(3),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xFF101828));
    canvas.drawCircle(
      badgeCenter.translate(3, -2),
      1.5,
      Paint()..color = Colors.white,
    );
    final mountain = Path()
      ..moveTo(badgeCenter.dx - 5, badgeCenter.dy + 3)
      ..lineTo(badgeCenter.dx - 1, badgeCenter.dy - 1)
      ..lineTo(badgeCenter.dx + 5, badgeCenter.dy + 3)
      ..close();
    canvas.drawPath(mountain, Paint()..color = Colors.white);
  }

  Offset _curveControl(GraphEdge edge, Offset source, Offset target) {
    final midpoint = (source + target) / 2;
    final delta = target - source;
    if (delta.distance < 1) return midpoint;
    final perpendicular = Offset(-delta.dy, delta.dx) / delta.distance;
    final direction = edge.id.hashCode.isEven ? 1.0 : -1.0;
    final bend = math.min(28.0, 8 + delta.distance * 0.055);
    return midpoint + perpendicular * bend * direction;
  }

  void _drawArrow(
    Canvas canvas,
    Offset control,
    Offset target,
    Paint edgePaint,
  ) {
    final tangent = target - control;
    if (tangent.distance < 1) return;
    final direction = tangent / tangent.distance;
    final tip = target - direction * 13;
    final perpendicular = Offset(-direction.dy, direction.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - direction.dx * 9 + perpendicular.dx * 5,
        tip.dy - direction.dy * 9 + perpendicular.dy * 5,
      )
      ..lineTo(
        tip.dx - direction.dx * 9 - perpendicular.dx * 5,
        tip.dy - direction.dy * 9 - perpendicular.dy * 5,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = edgePaint.color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final selectedId = viewState.selectedId;
    return _visibleNodes.map((node) {
      final point = layout.positions[node.id]!;
      final radius = knowledgeGraphNodeRadius(node) + 9;
      final selected = node.id == selectedId;
      return CustomPainterSemantics(
        rect: Rect.fromCircle(center: point, radius: radius),
        properties: SemanticsProperties(
          label:
              '${knowledgeGraphNodeTypeLabel(node.type)}, ${node.label}, '
              '${node.evidence.length} evidence '
              '${node.evidence.length == 1 ? 'entry' : 'entries'}'
              '${node.mediaAttachments.isNotEmpty ? ', ${node.mediaAttachments.length} visual ${node.mediaAttachments.length == 1 ? 'memory' : 'memories'}' : ''}'
              '${newNodeIds.contains(node.id) ? ', new unconfirmed node' : ''}'
              '${selected ? ', selected' : ''}',
          textDirection: TextDirection.ltr,
          button: true,
          selected: selected,
          onTap: () => onSemanticTap(node),
        ),
      );
    }).toList();
  };

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.edges != edges ||
      oldDelegate.newNodeIds != newNodeIds ||
      oldDelegate.newEdgeIds != newEdgeIds ||
      oldDelegate.highlightedNodeIds != highlightedNodeIds ||
      oldDelegate.historyMode != historyMode ||
      oldDelegate.visualStyle != visualStyle ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.viewState != viewState ||
      oldDelegate.transformationController != transformationController ||
      oldDelegate.viewportSize != viewportSize;

  @override
  bool shouldRebuildSemantics(covariant GraphPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.newNodeIds != newNodeIds ||
      oldDelegate.viewState != viewState ||
      oldDelegate.viewState.selectedId != viewState.selectedId;
}

double knowledgeGraphNodeOpacity(GraphNode node) =>
    (.32 + node.confidence.clamp(0, 1) * .68).clamp(0, 1);

bool knowledgeGraphEdgeIsDashed(GraphEdge edge, {bool historyMode = false}) =>
    edge.origin == NodeOrigin.autonomousMuse ||
    edge.weight < (historyMode ? .85 : .4);

Color knowledgeGraphNodeColor(NodeType type) => switch (type) {
  NodeType.person => const Color(0xFF0072B2),
  NodeType.place => const Color(0xFF008A67),
  NodeType.event => const Color(0xFFD97706),
  NodeType.goal => const Color(0xFF6D4CC2),
  NodeType.fear => const Color(0xFFC43E00),
  NodeType.habit => const Color(0xFF2E7D32),
  NodeType.belief => const Color(0xFFA83C82),
  NodeType.memory => const Color(0xFF4B6587),
  NodeType.chapter => const Color(0xFF8A5A00),
  NodeType.project => const Color(0xFF005F73),
  NodeType.emotion => const Color(0xFFD1495B),
  NodeType.interaction => const Color(0xFFB45309),
  NodeType.decision => const Color(0xFF5F0F40),
  NodeType.outcome => const Color(0xFF3A7D44),
  NodeType.journalEntry => const Color(0xFF2563EB),
  NodeType.identityShift => const Color(0xFF9333EA),
  NodeType.archiveInsight => const Color(0xFFEA580C),
  NodeType.actionItem => const Color(0xFF0369A1),
  NodeType.promise => const Color(0xFF7C3AED),
  NodeType.topic => const Color(0xFF0F766E),
  NodeType.object => const Color(0xFF475569),
  NodeType.text => const Color(0xFF4338CA),
};

String knowledgeGraphNodeTypeLabel(NodeType type) => switch (type) {
  NodeType.person => 'Person',
  NodeType.place => 'Place',
  NodeType.event => 'Event',
  NodeType.goal => 'Goal',
  NodeType.fear => 'Fear',
  NodeType.habit => 'Habit',
  NodeType.belief => 'Belief',
  NodeType.memory => 'Memory',
  NodeType.chapter => 'Chapter',
  NodeType.project => 'Project',
  NodeType.emotion => 'Emotion',
  NodeType.interaction => 'Interaction',
  NodeType.decision => 'Decision',
  NodeType.outcome => 'Outcome',
  NodeType.journalEntry => 'Voice memory',
  NodeType.identityShift => 'Identity shift',
  NodeType.archiveInsight => 'Archive insight',
  NodeType.actionItem => 'Action item',
  NodeType.promise => 'Promise',
  NodeType.topic => 'Topic',
  NodeType.object => 'Object',
  NodeType.text => 'Visible text',
};
