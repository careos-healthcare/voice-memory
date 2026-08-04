import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';

import '../../../core/engines/ai_time_machine_engine.dart';
import '../../../core/engines/relationship_memory_engine.dart';
import '../../../core/graph/graph_node.dart';
import '../../../core/graph/personal_knowledge_graph.dart';
import '../../../features/media/encrypted_image_engine.dart';
import '../../../features/memory_graph/performance/graph_performance_monitor.dart';
import '../../../features/memory_graph/rendering/memory_graph_visual_style.dart';
import '../../../features/memory_graph/ui/graph_node_hero_animation.dart';
import '../../../features/memory_graph/ui/canvas_gesture_controller.dart';
import '../../../features/memory_graph/ui/graph_performance_overlay.dart';
import '../../../features/semantic_clusters/semantic_cluster.dart';
import '../../../features/semantic_clusters/ui/cluster_boundary_overlay.dart';
import '../../../features/relationships/relationship_evolution_sheet.dart';
import '../../../features/time_machine/ui/historical_node_sheet.dart';
import '../../../features/relationships/relationship_graph_models.dart';
import '../../../models/journal_entry.dart';
import '../../../services/hallucination_guard/hallucination_guard_service.dart';
import 'graph_painter.dart';
import 'knowledge_graph_layout.dart';
import 'node_detail_sheet.dart';

typedef EntityTimeMachineQuery = TimeMachineResult Function(GraphNode node);
typedef KnowledgeGraphLayoutCallback =
    void Function(int computationCount, Map<String, Offset> positions);
typedef KnowledgeGraphEvidenceCallback = void Function(GraphNode node);
typedef ManualConnectionCallback =
    FutureOr<void> Function(GraphNode source, GraphNode target);

class InteractiveKnowledgeGraphWidget extends StatefulWidget {
  const InteractiveKnowledgeGraphWidget({
    super.key,
    required this.graph,
    this.relationshipMemoryEngine,
    this.timeMachineEngine,
    this.onTimeMachineQuery,
    this.onNodeSelected,
    this.onLayoutComputed,
    this.transformationController,
    this.onViewEvidenceMentions,
    this.entries = const [],
    this.highlightedNodeIds = const {},
    this.burstNodeIds = const {},
    this.burstEdgeIds = const {},
    this.relationshipHallucinationGuard,
    this.height,
    this.onEmptySpaceLongPress,
    this.onManualConnection,
    this.readOnly = false,
    this.targetTime,
    this.focusNodeId,
    this.focusRevision = 0,
    this.clusters = const [],
    this.onClusterSelected,
    this.focusClusterId,
    this.focusClusterRevision = 0,
    this.encryptedImageEngine,
    this.visualStyle = MemoryGraphVisualStyle.fallback,
    this.spatialOverlayBuilder,
  });

  final PersonalKnowledgeGraph graph;
  final RelationshipMemoryEngine? relationshipMemoryEngine;
  final AITimeMachineEngine? timeMachineEngine;
  final EntityTimeMachineQuery? onTimeMachineQuery;
  final ValueChanged<GraphNode>? onNodeSelected;
  final KnowledgeGraphLayoutCallback? onLayoutComputed;
  final TransformationController? transformationController;
  final KnowledgeGraphEvidenceCallback? onViewEvidenceMentions;
  final List<JournalEntry> entries;
  final Set<String> highlightedNodeIds;
  final Set<String> burstNodeIds;
  final Set<String> burstEdgeIds;
  final HallucinationGuardService? relationshipHallucinationGuard;

  /// Optional host override. When omitted the canvas follows the safe viewport
  /// and the surrounding scroll view handles compact or large-text layouts.
  final double? height;
  final ValueChanged<Offset>? onEmptySpaceLongPress;
  final ManualConnectionCallback? onManualConnection;
  final bool readOnly;
  final DateTime? targetTime;
  final String? focusNodeId;
  final int focusRevision;
  final List<SemanticCluster> clusters;
  final ValueChanged<SemanticCluster>? onClusterSelected;
  final String? focusClusterId;
  final int focusClusterRevision;
  final EncryptedImageEngine? encryptedImageEngine;
  final MemoryGraphVisualStyle visualStyle;
  final Widget Function(KnowledgeGraphLayout layout)? spatialOverlayBuilder;

  @override
  State<InteractiveKnowledgeGraphWidget> createState() =>
      _InteractiveKnowledgeGraphWidgetState();
}

class _ManualEdgePreviewPainter extends CustomPainter {
  const _ManualEdgePreviewPainter({required this.source, required this.target});

  final Offset source;
  final Offset target;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(source, target, paint);
    canvas.drawCircle(target, 7, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _ManualEdgePreviewPainter oldDelegate) =>
      source != oldDelegate.source || target != oldDelegate.target;
}

class _InteractiveKnowledgeGraphWidgetState
    extends State<InteractiveKnowledgeGraphWidget>
    with TickerProviderStateMixin {
  NodeType? _filter;
  KnowledgeGraphLayout? _layout;
  String? _layoutKey;
  int _layoutComputationCount = 0;
  late TransformationController _transformationController;
  late bool _ownsTransformationController;
  late final AnimationController _animationController;
  late final AnimationController _graphPulseController;
  int _pulseTurns = 0;
  Set<String> _newNodeIds = const {};
  Set<String> _newEdgeIds = const {};
  String? _heroNodeId;
  Animation<Matrix4>? _matrixAnimation;
  final KnowledgeGraphViewState _viewState = KnowledgeGraphViewState();
  final GlobalKey _graphSemanticsKey = GlobalKey();
  final FocusNode _graphFocusNode = FocusNode(debugLabel: 'knowledge graph');
  bool _showAccessibleList = false;
  bool _showPerformanceOverlay = false;
  Size _viewportSize = Size.zero;
  late final CanvasGestureController _canvasGestures;
  String? _handledClusterFocusToken;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_recordGraphTimings);
    _canvasGestures = CanvasGestureController()..addListener(_repaintGestures);
    _setTransformationController(widget.transformationController);
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addListener(() {
          final animation = _matrixAnimation;
          if (animation != null) {
            _transformationController.value = animation.value;
          }
        });
    _graphPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addStatusListener(_handlePulseStatus);
    if (widget.burstNodeIds.isNotEmpty || widget.burstEdgeIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
          _graphPulseController.value = 1;
        } else {
          _graphPulseController.repeat(reverse: true);
        }
      });
    }
  }

  void _repaintGestures() {
    if (mounted) setState(() {});
  }

  void _recordGraphTimings(List<FrameTiming> timings) {
    GraphPerformanceMonitor.instance.recordFrameTimings(timings);
  }

  @override
  void didUpdateWidget(covariant InteractiveKnowledgeGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformationController != widget.transformationController) {
      if (_ownsTransformationController) _transformationController.dispose();
      _setTransformationController(widget.transformationController);
    }
    if (!identical(oldWidget.graph, widget.graph)) {
      final previousNodeIds = oldWidget.graph.nodes
          .map((node) => node.id)
          .toSet();
      final previousEdgeIds = oldWidget.graph.edges
          .map((edge) => edge.id)
          .toSet();
      _newNodeIds = widget.graph.nodes
          .map((node) => node.id)
          .where((id) => !previousNodeIds.contains(id))
          .toSet();
      _newEdgeIds = widget.graph.edges
          .map((edge) => edge.id)
          .where((id) => !previousEdgeIds.contains(id))
          .toSet();
      if (_newNodeIds.isNotEmpty || _newEdgeIds.isNotEmpty) {
        if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
          _graphPulseController.value = 1;
        } else {
          _pulseTurns = 0;
          _graphPulseController.repeat(reverse: true);
        }
      }
      _layoutKey = null;
      _layout = null;
      if (!widget.graph.nodes.any((node) => node.id == _viewState.selectedId)) {
        _viewState.selectedId = null;
      }
    }
    if (oldWidget.focusRevision != widget.focusRevision &&
        widget.focusNodeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final node = widget.graph.nodes
            .where((item) => item.id == widget.focusNodeId)
            .firstOrNull;
        if (node != null) unawaited(_zoomToNode(node));
      });
    }
  }

  void _setTransformationController(TransformationController? controller) {
    _ownsTransformationController = controller == null;
    _transformationController = controller ?? TransformationController();
  }

  void _handlePulseStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }
    _pulseTurns += 1;
    if (_pulseTurns < 3 || !mounted) return;
    _graphPulseController.stop();
    setState(() {
      _newNodeIds = const {};
      _newEdgeIds = const {};
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_recordGraphTimings);
    _canvasGestures
      ..removeListener(_repaintGestures)
      ..dispose();
    _animationController.dispose();
    _graphPulseController.dispose();
    if (_ownsTransformationController) _transformationController.dispose();
    _graphFocusNode.dispose();
    _viewState.dispose();
    super.dispose();
  }

  void _select(GraphNode node) {
    unawaited(_selectWithTransition(node));
  }

  Future<void> _selectWithTransition(GraphNode node) async {
    _viewState.selectedId = node.id;
    setState(() => _heroNodeId = node.id);
    _graphSemanticsKey.currentContext
        ?.findRenderObject()
        ?.markNeedsSemanticsUpdate();
    widget.onNodeSelected?.call(node);
    await _zoomToNode(node);
    if (!mounted) return;
    await _showNodeDetails(node);
  }

  Future<void> _showNodeDetails(GraphNode node) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: math.min(constraints.maxHeight * 0.9, 720),
          child: widget.readOnly && widget.targetTime != null
              ? HistoricalNodeSheet(
                  graph: widget.graph,
                  node: node,
                  targetTime: widget.targetTime!,
                  entries: widget.entries,
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onSelectConnectedNode: (connected) {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _select(connected);
                    });
                  },
                )
              : node.type == NodeType.person &&
                    RelationshipGraphSnapshot.forPerson(
                      widget.graph,
                      node,
                    ).interactions.isNotEmpty
              ? RelationshipEvolutionSheet(
                  graph: widget.graph,
                  person: node,
                  onClose: () => Navigator.of(sheetContext).pop(),
                  hallucinationGuard: widget.relationshipHallucinationGuard,
                )
              : NodeDetailSheet(
                  graph: widget.graph,
                  node: node,
                  relationshipMemoryEngine: widget.relationshipMemoryEngine,
                  timeMachineEngine: widget.timeMachineEngine,
                  onTimeMachineQuery: widget.onTimeMachineQuery,
                  entries: widget.entries,
                  encryptedImageEngine: widget.encryptedImageEngine,
                  onSelectConnectedNode: (connected) {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _select(connected);
                    });
                  },
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onViewEvidence: () {
                    Navigator.of(sheetContext).pop();
                    final callback = widget.onViewEvidenceMentions;
                    if (callback != null) {
                      callback(node);
                      return;
                    }
                    final location = Uri(
                      path: '/life-os/graph',
                      queryParameters: {'view': 'evidence', 'nodeId': node.id},
                    ).toString();
                    context.push(location);
                  },
                ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _heroNodeId = null);
    _graphFocusNode.requestFocus();
    _announce('${node.label} details closed. Returned to knowledge graph.');
  }

  void _setFilter(NodeType? filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _layoutKey = null;
      _layout = null;
    });
    _viewState.selectedId = null;
    _announce(
      '${filter == null ? 'All' : knowledgeGraphNodeTypeLabel(filter)} '
      'filter selected',
    );
  }

  Future<void> _animateTo(Matrix4 target) async {
    final media = MediaQuery.of(context);
    if (media.disableAnimations || media.accessibleNavigation) {
      _animationController.stop();
      _transformationController.value = target;
      return;
    }
    _animationController.stop();
    _matrixAnimation =
        Matrix4Tween(
          begin: Matrix4.copy(_transformationController.value),
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutCubic,
          ),
        );
    await _animationController.forward(from: 0).orCancel;
  }

  void _centerAll() {
    unawaited(_animateTo(Matrix4.identity()));
    _announce('Graph centered and zoom reset');
  }

  void _centerSelected() {
    final selectedId = _viewState.selectedId;
    final point = selectedId == null ? null : _layout?.positions[selectedId];
    if (point == null || _viewportSize.isEmpty) return;
    final currentScale = _transformationController.value.storage[0].abs().clamp(
      0.45,
      4.0,
    );
    final target = Matrix4.zero();
    target.storage[0] = currentScale;
    target.storage[5] = currentScale;
    target.storage[10] = 1;
    target.storage[15] = 1;
    target.storage[12] = _viewportSize.width / 2 - point.dx * currentScale;
    target.storage[13] = _viewportSize.height / 2 - point.dy * currentScale;
    unawaited(_animateTo(target));
    _announce('Selected entity centered');
  }

  Future<void> _zoomToNode(GraphNode node) async {
    final point = _layout?.positions[node.id];
    if (point == null || _viewportSize.isEmpty) return;
    final currentScale = _transformationController.value.storage[0].abs();
    final targetScale = math.max(currentScale, 1.8).clamp(0.45, 4.0);
    final target = Matrix4.identity()
      ..setEntry(0, 0, targetScale)
      ..setEntry(1, 1, targetScale)
      ..setEntry(0, 3, _viewportSize.width / 2 - point.dx * targetScale)
      ..setEntry(1, 3, _viewportSize.height / 2 - point.dy * targetScale);
    try {
      await _animateTo(target);
    } on TickerCanceled {
      // A newer interaction superseded this transition.
    }
  }

  Future<void> _fitCluster(SemanticCluster cluster) async {
    final layout = _layout;
    if (layout == null || _viewportSize.isEmpty) return;
    final members = layout.nodes
        .where(
          (node) =>
              cluster.nodeIds.contains(node.id) &&
              layout.positions.containsKey(node.id),
        )
        .toList();
    if (members.isEmpty) return;
    var bounds = Rect.fromCircle(
      center: layout.positions[members.first.id]!,
      radius: knowledgeGraphNodeRadius(members.first),
    );
    for (final node in members.skip(1)) {
      bounds = bounds.expandToInclude(
        Rect.fromCircle(
          center: layout.positions[node.id]!,
          radius: knowledgeGraphNodeRadius(node),
        ),
      );
    }
    bounds = bounds.inflate(44);
    final scale = math
        .min(
          (_viewportSize.width - 32) / math.max(bounds.width, 1),
          (_viewportSize.height - 32) / math.max(bounds.height, 1),
        )
        .clamp(.45, 3.0);
    final center = bounds.center;
    final target = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, _viewportSize.width / 2 - center.dx * scale)
      ..setEntry(1, 3, _viewportSize.height / 2 - center.dy * scale);
    try {
      await _animateTo(target);
      _announce('${cluster.title} cluster focused');
    } on TickerCanceled {
      // A newer graph focus superseded this transition.
    }
  }

  void _scheduleClusterFocus(KnowledgeGraphLayout layout) {
    final id = widget.focusClusterId;
    if (id == null) {
      _handledClusterFocusToken = null;
      return;
    }
    final token = '$id:${widget.focusClusterRevision}:$_layoutKey';
    if (_handledClusterFocusToken == token) return;
    final cluster = widget.clusters.where((item) => item.id == id).firstOrNull;
    if (cluster == null) return;
    _handledClusterFocusToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_layout, layout)) {
        unawaited(_fitCluster(cluster));
      }
    });
  }

  void _setAccessibleList(bool value) {
    if (_showAccessibleList == value) return;
    setState(() => _showAccessibleList = value);
    _announce(value ? 'Entity list view' : 'Graph canvas view');
  }

  void _announce(String message) {
    if (!mounted || !MediaQuery.supportsAnnounceOf(context)) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final safeViewportHeight =
        media.size.height - media.padding.vertical - media.viewInsets.vertical;
    final requestedHeight =
        widget.height ??
        (safeViewportHeight * (landscape ? 0.72 : 0.55)).clamp(240.0, 520.0);
    final effectiveHeight = landscape
        ? math.min(requestedHeight, math.max(240.0, safeViewportHeight))
        : requestedHeight;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: 'Knowledge graph filters',
            child: _filterMenu(),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            selected: _showAccessibleList,
            label: _showAccessibleList
                ? 'Show visual graph canvas'
                : 'Show accessible entity list',
            child: ExcludeSemantics(
              child: OutlinedButton.icon(
                key: const Key('knowledge-graph-list-toggle'),
                onPressed: () => _setAccessibleList(!_showAccessibleList),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: Icon(
                  _showAccessibleList ? Icons.hub_outlined : Icons.list,
                ),
                label: Text(
                  _showAccessibleList ? 'Canvas view' : 'Entity list',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: effectiveHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportSize = Size(constraints.maxWidth, effectiveHeight);
                final nodes =
                    widget.graph.nodes
                        .where(
                          (node) =>
                              node.hasValidEvidence &&
                              (_filter == null || node.type == _filter),
                        )
                        .toList()
                      ..sort((a, b) {
                        final label = a.label.toLowerCase().compareTo(
                          b.label.toLowerCase(),
                        );
                        return label != 0 ? label : a.id.compareTo(b.id);
                      });
                final columns = math.max(1, math.sqrt(nodes.length).ceil());
                final rows = math.max(1, (nodes.length / columns).ceil());
                final canvasSize = Size(
                  math.max(
                    math.max(constraints.maxWidth, 760.0),
                    columns * 48.0,
                  ),
                  math.max(math.max(effectiveHeight, 520.0), rows * 48.0),
                );
                final nodeIds = nodes.map((node) => node.id).toSet();
                final edges = widget.graph.edges
                    .where(
                      (edge) =>
                          edge.hasValidEvidence &&
                          nodeIds.contains(edge.sourceNodeId) &&
                          nodeIds.contains(edge.targetNodeId),
                    )
                    .toList();
                if (_showAccessibleList) {
                  return _AccessibleEntityList(
                    nodes: nodes,
                    onSelected: _select,
                    focusNode: _graphFocusNode,
                  );
                }
                final key = _cacheKey(nodes, edges, canvasSize);
                if (_layoutKey != key) {
                  _layout = ForceDirectedKnowledgeGraphLayout.compute(
                    nodes,
                    edges,
                    canvasSize,
                  );
                  _layoutKey = key;
                  _layoutComputationCount++;
                  widget.onLayoutComputed?.call(
                    _layoutComputationCount,
                    _layout!.positions,
                  );
                }
                final layout = _layout!;
                _scheduleClusterFocus(layout);
                final focusedCluster = widget.clusters
                    .where((item) => item.id == widget.focusClusterId)
                    .firstOrNull;
                final effectiveHighlightedNodeIds = focusedCluster == null
                    ? widget.highlightedNodeIds
                    : focusedCluster.nodeIds.toSet();
                final clusterPainter = ClusterBoundaryPainter(
                  layout: layout,
                  clusters: widget.clusters,
                  focusClusterId: widget.focusClusterId,
                  onSemanticTap: widget.onClusterSelected,
                );
                GraphNode? heroNode;
                for (final node in nodes) {
                  if (node.id == _heroNodeId) {
                    heroNode = node;
                    break;
                  }
                }
                final heroPoint = heroNode == null
                    ? null
                    : layout.positions[heroNode.id];
                final customActions = <CustomSemanticsAction, VoidCallback>{
                  const CustomSemanticsAction(
                    label: 'Center graph and reset zoom',
                  ): _centerAll,
                  const CustomSemanticsAction(
                    label: 'Switch to accessible entity list',
                  ): () =>
                      _setAccessibleList(true),
                };
                if (_viewState.selectedId != null) {
                  customActions[const CustomSemanticsAction(
                        label: 'Center selected entity',
                      )] =
                      _centerSelected;
                }
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Focus(
                        focusNode: _graphFocusNode,
                        child: Semantics(
                          key: _graphSemanticsKey,
                          container: true,
                          explicitChildNodes: true,
                          label:
                              'Interactive knowledge graph, ${nodes.length} '
                              'entities and ${edges.length} connections. '
                              'Pan and zoom to explore.',
                          customSemanticsActions: customActions,
                          child: ClipRect(
                            child: InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              constrained: false,
                              minScale: 0.08,
                              maxScale: 4,
                              panEnabled: !_canvasGestures.isConnecting,
                              scaleEnabled: !_canvasGestures.isConnecting,
                              boundaryMargin: const EdgeInsets.all(80),
                              child: RepaintBoundary(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (details) {
                                    final node = layout.nodeAt(
                                      details.localPosition,
                                    );
                                    if (node != null) {
                                      _select(node);
                                      return;
                                    }
                                    final cluster = clusterPainter.clusterAt(
                                      details.localPosition,
                                    );
                                    if (cluster != null) {
                                      widget.onClusterSelected?.call(cluster);
                                    }
                                  },
                                  onLongPressStart:
                                      widget.readOnly ||
                                          widget.onEmptySpaceLongPress == null
                                      ? null
                                      : (details) {
                                          if (layout.nodeAt(
                                                details.localPosition,
                                              ) ==
                                              null) {
                                            widget.onEmptySpaceLongPress!(
                                              details.localPosition,
                                            );
                                          }
                                        },
                                  child: Listener(
                                    onPointerDown:
                                        widget.readOnly ||
                                            widget.onManualConnection == null
                                        ? null
                                        : (event) => _canvasGestures.begin(
                                            event.localPosition,
                                            layout,
                                          ),
                                    onPointerMove:
                                        widget.readOnly ||
                                            widget.onManualConnection == null
                                        ? null
                                        : (event) => _canvasGestures.update(
                                            event.localPosition,
                                            layout,
                                          ),
                                    onPointerUp:
                                        widget.readOnly ||
                                            widget.onManualConnection == null
                                        ? null
                                        : (event) {
                                            final connection = _canvasGestures
                                                .finish(
                                                  event.localPosition,
                                                  layout,
                                                );
                                            if (connection != null) {
                                              unawaited(
                                                Future.sync(
                                                  () =>
                                                      widget
                                                          .onManualConnection!(
                                                        connection.$1,
                                                        connection.$2,
                                                      ),
                                                ),
                                              );
                                            }
                                          },
                                    onPointerCancel: (_) =>
                                        _canvasGestures.cancel(),
                                    child: SizedBox.fromSize(
                                      size: canvasSize,
                                      child: Stack(
                                        children: [
                                          if (widget.clusters.isNotEmpty)
                                            Positioned.fill(
                                              child: CustomPaint(
                                                key: const Key(
                                                  'semantic-cluster-boundary-overlay',
                                                ),
                                                painter: clusterPainter,
                                                isComplex: true,
                                              ),
                                            ),
                                          Positioned.fill(
                                            child: CustomPaint(
                                              key: const Key(
                                                'interactive-knowledge-graph-canvas',
                                              ),
                                              painter: GraphPainter(
                                                layout: layout,
                                                edges: edges,
                                                viewState: _viewState,
                                                transformationController:
                                                    _transformationController,
                                                viewportSize: _viewportSize,
                                                pulse: _graphPulseController,
                                                newNodeIds: {
                                                  ..._newNodeIds,
                                                  ...widget.burstNodeIds,
                                                },
                                                newEdgeIds: {
                                                  ..._newEdgeIds,
                                                  ...widget.burstEdgeIds,
                                                },
                                                highlightedNodeIds:
                                                    effectiveHighlightedNodeIds,
                                                onSemanticTap: _select,
                                                historyMode: widget.readOnly,
                                                visualStyle: widget.visualStyle,
                                                textScaler:
                                                    MediaQuery.textScalerOf(
                                                      context,
                                                    ),
                                              ),
                                              isComplex: true,
                                              willChange: true,
                                            ),
                                          ),
                                          if (widget.spatialOverlayBuilder !=
                                              null)
                                            Positioned.fill(
                                              child:
                                                  widget.spatialOverlayBuilder!(
                                                    layout,
                                                  ),
                                            ),
                                          if (_canvasGestures.isConnecting &&
                                              _canvasGestures.pointer != null)
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                child: CustomPaint(
                                                  key: const Key(
                                                    'manual-edge-preview',
                                                  ),
                                                  painter: _ManualEdgePreviewPainter(
                                                    source:
                                                        layout
                                                            .positions[_canvasGestures
                                                            .sourceNode!
                                                            .id]!,
                                                    target:
                                                        _canvasGestures
                                                                .targetNode ==
                                                            null
                                                        ? _canvasGestures
                                                              .pointer!
                                                        : layout
                                                              .positions[_canvasGestures
                                                              .targetNode!
                                                              .id]!,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (heroNode != null &&
                                              heroPoint != null)
                                            Positioned(
                                              left:
                                                  heroPoint.dx -
                                                  knowledgeGraphNodeRadius(
                                                    heroNode,
                                                  ),
                                              top:
                                                  heroPoint.dy -
                                                  knowledgeGraphNodeRadius(
                                                    heroNode,
                                                  ),
                                              child: IgnorePointer(
                                                child: GraphNodeHeroAnimation(
                                                  node: heroNode,
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color:
                                                          knowledgeGraphNodeColor(
                                                            heroNode.type,
                                                          ),
                                                    ),
                                                    child: SizedBox.square(
                                                      dimension:
                                                          knowledgeGraphNodeRadius(
                                                            heroNode,
                                                          ) *
                                                          2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_showPerformanceOverlay)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: GraphPerformanceOverlay(
                          onClose: () =>
                              setState(() => _showPerformanceOverlay = false),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (kDebugMode)
                              IconButton(
                                key: const Key('graph-performance-toggle'),
                                tooltip: 'Toggle graph performance diagnostics',
                                onPressed: () => setState(
                                  () => _showPerformanceOverlay =
                                      !_showPerformanceOverlay,
                                ),
                                icon: const Icon(Icons.speed),
                              ),
                            Semantics(
                              button: true,
                              label: 'Center graph and reset zoom',
                              child: ExcludeSemantics(
                                child: IconButton(
                                  key: const Key('knowledge-graph-center-all'),
                                  tooltip: 'Center graph and reset zoom',
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: _centerAll,
                                  icon: const Icon(Icons.center_focus_strong),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _viewState,
                              builder: (context, child) => Semantics(
                                button: true,
                                enabled: _viewState.selectedId != null,
                                label: 'Center selected entity',
                                child: ExcludeSemantics(
                                  child: IconButton(
                                    key: const Key(
                                      'knowledge-graph-center-selected',
                                    ),
                                    tooltip: 'Center selected entity',
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    onPressed: _viewState.selectedId == null
                                        ? null
                                        : _centerSelected,
                                    icon: const Icon(Icons.my_location),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterMenu() {
    final currentLabel = _filter == null
        ? 'All'
        : knowledgeGraphNodeTypeLabel(_filter!);
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        key: const Key('knowledge-graph-filter-menu'),
        tooltip: 'Filter graph entities',
        onSelected: (value) =>
            _setFilter(value == 'all' ? null : NodeType.values.byName(value)),
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            key: Key('knowledge-graph-filter-all'),
            value: 'all',
            child: Text('All'),
          ),
          for (final type in NodeType.values)
            PopupMenuItem<String>(
              key: Key('knowledge-graph-filter-${type.name}'),
              value: type.name,
              child: Text(knowledgeGraphNodeTypeLabel(type)),
            ),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 8),
                Flexible(child: Text('Filter: $currentLabel')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cacheKey(List<GraphNode> nodes, List<GraphEdge> edges, Size size) {
    final nodeSignature = nodes
        .map((node) => '${node.id}:${node.evidence.length}')
        .join('|');
    final edgeSignature = edges
        .map(
          (edge) =>
              '${edge.id}:${edge.sourceNodeId}:${edge.targetNodeId}:'
              '${edge.weight}',
        )
        .join('|');
    return '${size.width.round()}x${size.height.round()};'
        '$nodeSignature;$edgeSignature';
  }
}

class _AccessibleEntityList extends StatelessWidget {
  const _AccessibleEntityList({
    required this.nodes,
    required this.onSelected,
    required this.focusNode,
  });

  final List<GraphNode> nodes;
  final ValueChanged<GraphNode> onSelected;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: focusNode,
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Knowledge graph entity list, ${nodes.length} entities',
      child: nodes.isEmpty
          ? Center(
              child: Semantics(
                liveRegion: true,
                label: 'No entities match this filter',
                child: const ExcludeSemantics(
                  child: Text('No entities match this filter.'),
                ),
              ),
            )
          : ListView.builder(
              key: const Key('knowledge-graph-entity-list'),
              itemCount: nodes.length,
              itemBuilder: (context, index) {
                final node = nodes[index];
                final count = node.evidence.length;
                return Semantics(
                  button: true,
                  label:
                      '${knowledgeGraphNodeTypeLabel(node.type)}, ${node.label}, '
                      '$count evidence ${count == 1 ? 'entry' : 'entries'}',
                  hint: 'Opens evidence details',
                  child: ExcludeSemantics(
                    child: ListTile(
                      key: Key('knowledge-graph-entity-${node.id}'),
                      title: Text(node.label),
                      subtitle: Text(
                        '${knowledgeGraphNodeTypeLabel(node.type)} · '
                        '$count evidence ${count == 1 ? 'entry' : 'entries'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSelected(node),
                    ),
                  ),
                );
              },
            ),
    ),
  );
}
