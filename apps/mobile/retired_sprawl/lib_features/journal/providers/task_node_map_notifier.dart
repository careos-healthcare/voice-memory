import 'package:archiveme_mobile/features/journal/domain/task_node.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_entity_slices.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Normalized task-node map independent of task timeline ordering.
final class TaskNodeMapNotifier extends AsyncNotifier<TaskNodeMapState> {
  @override
  Future<TaskNodeMapState> build() async {
    ref.keepAlive();
    return const TaskNodeMapState.empty();
  }

  void mergeParsed(Map<String, TaskNode> nodes) {
    if (nodes.isEmpty) return;
    final current = state.value ?? const TaskNodeMapState.empty();
    state = AsyncData(current.putAll(nodes));
  }

  void upsert(TaskNode node) {
    final current = state.value ?? const TaskNodeMapState.empty();
    state = AsyncData(current.putNode(node));
  }

  void remove(String nodeId) {
    final current = state.value ?? const TaskNodeMapState.empty();
    state = AsyncData(current.removeNode(nodeId));
  }
}

final taskNodeMapProvider =
    AsyncNotifierProvider<TaskNodeMapNotifier, TaskNodeMapState>(
  TaskNodeMapNotifier.new,
);
