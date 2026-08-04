import 'package:flutter/material.dart';

import '../../../core/graph/graph_node.dart';
import '../../../ui/screens/life_os/graph_painter.dart';

String graphNodeHeroTag(String nodeId) => 'memory-graph-node-$nodeId';

class GraphNodeHeroAnimation extends StatelessWidget {
  const GraphNodeHeroAnimation({
    super.key,
    required this.node,
    required this.child,
  });

  final GraphNode node;
  final Widget child;

  @override
  Widget build(BuildContext context) => Hero(
    tag: graphNodeHeroTag(node.id),
    createRectTween: (begin, end) =>
        MaterialRectCenterArcTween(begin: begin, end: end),
    flightShuttleBuilder:
        (context, animation, direction, fromContext, toContext) =>
            FadeTransition(
              opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
              child: Material(
                color: knowledgeGraphNodeColor(node.type),
                shape: const CircleBorder(),
                elevation: 8,
                child: const SizedBox.square(dimension: 52),
              ),
            ),
    child: child,
  );
}
