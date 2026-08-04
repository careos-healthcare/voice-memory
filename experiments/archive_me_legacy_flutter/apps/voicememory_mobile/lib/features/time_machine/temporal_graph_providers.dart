import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/providers/life_os_providers.dart';
import '../../services/app_services_providers.dart';
import 'temporal_graph_engine.dart';

final canvasTargetTimeListenable = ValueNotifier<DateTime?>(null);

class CanvasTargetTimeNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void show(DateTime targetTime) {
    state = targetTime.toUtc();
    canvasTargetTimeListenable.value = state;
  }

  void present() {
    state = null;
    canvasTargetTimeListenable.value = null;
  }
}

final canvasTargetTimeProvider =
    NotifierProvider<CanvasTargetTimeNotifier, DateTime?>(
      CanvasTargetTimeNotifier.new,
    );

final temporalGraphProvider = FutureProvider.autoDispose
    .family<PersonalKnowledgeGraph, DateTime>((ref, targetTime) async {
      final graph = await ref.watch(knowledgeGraphProvider.future);
      return TemporalGraphEngine(
        semanticStore: ref.watch(localSemanticStoreProvider),
        historyStore: ref.watch(temporalGraphHistoryStoreProvider),
      ).reconstruct(currentGraph: graph, targetTime: targetTime);
    });

final temporalGraphMarkersProvider = Provider.autoDispose<List<DateTime>>((
  ref,
) {
  final graph = ref.watch(knowledgeGraphProvider).value;
  if (graph == null) return const [];
  return TemporalGraphEngine(
    semanticStore: ref.watch(localSemanticStoreProvider),
  ).markers(graph);
});
