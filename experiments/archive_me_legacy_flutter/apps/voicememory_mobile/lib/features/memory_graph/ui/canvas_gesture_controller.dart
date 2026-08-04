import 'package:flutter/widgets.dart';

import '../../../core/graph/graph_node.dart';
import '../../../ui/screens/life_os/knowledge_graph_layout.dart';

class CanvasGestureController extends ChangeNotifier {
  GraphNode? sourceNode;
  GraphNode? targetNode;
  Offset? pointer;

  bool get isConnecting => sourceNode != null;

  bool begin(Offset point, KnowledgeGraphLayout layout) {
    final source = layout.nodeAt(point);
    if (source == null) return false;
    sourceNode = source;
    pointer = point;
    notifyListeners();
    return true;
  }

  void update(Offset point, KnowledgeGraphLayout layout) {
    if (!isConnecting) return;
    pointer = point;
    final candidate = layout.nodeAt(point);
    targetNode = candidate?.id == sourceNode!.id ? null : candidate;
    notifyListeners();
  }

  (GraphNode, GraphNode)? finish(Offset point, KnowledgeGraphLayout layout) {
    if (!isConnecting) return null;
    update(point, layout);
    final source = sourceNode;
    final target = targetNode;
    cancel();
    return source != null && target != null ? (source, target) : null;
  }

  void cancel() {
    sourceNode = null;
    targetNode = null;
    pointer = null;
    notifyListeners();
  }
}
