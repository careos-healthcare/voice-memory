import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../services/ai/local_semantic_store.dart';
import '../action_plans/action_plan_models.dart';
import '../action_plans/action_plan_store.dart';
import '../semantic_clusters/semantic_cluster.dart';
import '../semantic_clusters/semantic_cluster_store.dart';
import 'autonomous_muse_models.dart';
import 'autonomous_muse_store.dart';

abstract interface class MuseBackgroundScheduler {
  Future<void> schedule(MuseGovernance governance);
  Future<void> cancel();
}

abstract interface class MuseResourceProbe {
  Future<MuseResourceState> current();
}

final class PlatformMuseResourceProbe implements MuseResourceProbe {
  PlatformMuseResourceProbe({Battery? battery, Connectivity? connectivity})
    : _battery = battery ?? Battery(),
      _connectivity = connectivity ?? Connectivity();

  final Battery _battery;
  final Connectivity _connectivity;

  @override
  Future<MuseResourceState> current() async {
    final batteryState = await _battery.batteryState;
    final connectivity = await _connectivity.checkConnectivity();
    return MuseResourceState(
      isCharging:
          batteryState == BatteryState.charging ||
          batteryState == BatteryState.full,
      isWifiConnected: connectivity.contains(ConnectivityResult.wifi),
      // Workmanager invokes this worker under its requiresDeviceIdle contract.
      isIdle: true,
      batteryPercent: await _battery.batteryLevel,
    );
  }
}

final class WorkmanagerMuseScheduler implements MuseBackgroundScheduler {
  static const taskName = 'archiveMe.autonomousMuse.sweep';
  static const uniqueName = 'com.voicememory.mobile.autonomous.muse';

  @override
  Future<void> schedule(MuseGovernance governance) =>
      Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: Duration(hours: governance.frequency.hours),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          networkType: governance.requireWifi
              ? NetworkType.unmetered
              : NetworkType.notRequired,
          requiresCharging: governance.runOnlyWhenCharging,
          requiresBatteryNotLow: true,
          requiresDeviceIdle: governance.requireIdle,
          requiresStorageNotLow: true,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 30),
      );

  @override
  Future<void> cancel() => Workmanager().cancelByUniqueName(uniqueName);
}

abstract interface class MuseLocalSynthesizer {
  Future<String> synthesize(List<MuseBridgeDiscovery> discoveries);
}

/// A deterministic, on-device fallback. A llama.cpp/Ollama adapter can be
/// injected, but this service deliberately has no network transport dependency.
final class DeterministicLocalMuseSynthesizer implements MuseLocalSynthesizer {
  const DeterministicLocalMuseSynthesizer();

  @override
  Future<String> synthesize(List<MuseBridgeDiscovery> discoveries) async {
    if (discoveries.isEmpty) {
      return 'The Muse completed a private local sweep. No strong new bridges '
          'were found yet.';
    }
    final strongest = discoveries.first;
    return 'A dormant thread connects “${strongest.sourceLabel}” with '
        '“${strongest.targetLabel}”. Revisit them together and notice what has '
        'changed in the space between.';
  }
}

final class AutonomousMuseService {
  AutonomousMuseService({
    required this.store,
    required this.graphStore,
    required this.clusterStore,
    required this.semanticStore,
    required this.actionPlanStore,
    required this.scheduler,
    this.synthesizer = const DeterministicLocalMuseSynthesizer(),
    MuseResourceProbe? resourceProbe,
    DateTime Function()? clock,
  }) : _resourceProbe = resourceProbe ?? PlatformMuseResourceProbe(),
       _clock = clock ?? DateTime.now;

  static const dormantAge = Duration(days: 30);
  static const minimumBridgeSimilarity = .78;
  static const maximumSweepNodes = 400;
  static const maximumBridges = 5;

  final AutonomousMuseStore store;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final LocalSemanticStore semanticStore;
  final ActionPlanStore actionPlanStore;
  final MuseBackgroundScheduler scheduler;
  final MuseLocalSynthesizer synthesizer;
  final MuseResourceProbe _resourceProbe;
  final DateTime Function() _clock;
  bool _running = false;

  MuseGovernance governance() => store.readGovernance();

  Future<void> updateGovernance(MuseGovernance value) async {
    store.writeGovernance(value);
    if (value.enabled) {
      await scheduler.schedule(value);
    } else {
      await scheduler.cancel();
    }
  }

  Future<void> schedule() async {
    final settings = governance();
    if (settings.enabled) {
      await scheduler.schedule(settings);
    } else {
      await scheduler.cancel();
    }
  }

  void markClusterVisited(String clusterId) =>
      store.markClusterVisited(clusterId, _clock().toUtc());

  MuseBriefing? latestBriefing() => store.latestBriefing();

  bool shouldPresent(MuseBriefing briefing) =>
      _sameDay(briefing.localDay, _clock()) &&
      !store.wasBriefingPresented(briefing.localDay);

  void markPresented(MuseBriefing briefing) =>
      store.markBriefingPresented(briefing.localDay);

  Future<MuseSweepResult> runSweep({
    MuseResourceState? resources,
    bool force = false,
  }) async {
    if (_running) {
      return const MuseSweepResult(status: MuseSweepStatus.skippedDue);
    }
    final now = _clock();
    final settings = governance();
    if (!force && !settings.enabled) {
      return const MuseSweepResult(status: MuseSweepStatus.skippedDisabled);
    }
    final resourceState =
        resources ??
        (force
            ? const MuseResourceState.schedulerGuaranteed()
            : await _resourceProbe.current());
    if (!force && !resourceState.allows(settings)) {
      return const MuseSweepResult(status: MuseSweepStatus.skippedResources);
    }
    final lastRun = store.lastCompletedAt;
    if (!force &&
        lastRun != null &&
        now.toUtc().difference(lastRun) <
            Duration(hours: settings.frequency.hours)) {
      return const MuseSweepResult(status: MuseSweepStatus.skippedDue);
    }

    _running = true;
    final runId = 'muse-${now.toUtc().microsecondsSinceEpoch}';
    store.beginRun(runId, now);
    try {
      final graph = await graphStore.load();
      final clusters = await clusterStore.list();
      final discoveries = await _discover(graph, clusters, now);
      final revived = await _reviveActionPlan();
      final summary = await synthesizer.synthesize(discoveries);
      final briefing = MuseBriefing(
        id: runId,
        localDay: DateTime(now.year, now.month, now.day),
        discoveries: discoveries,
        summary: summary,
        actionPrompt: revived == null
            ? null
            : 'Revive “${revived.title}”: ${revived.targetOutcome}',
        actionPlanId: revived?.id,
      );
      store.transaction(() {
        store.saveBriefing(briefing);
        store.finishRun(
          runId,
          completedAt: _clock(),
          status: MuseSweepStatus.completed,
          bridgeCount: discoveries.length,
        );
      });
      return MuseSweepResult(
        status: MuseSweepStatus.completed,
        briefing: briefing,
        createdBridgeCount: discoveries.length,
      );
    } on Object {
      store.finishRun(
        runId,
        completedAt: _clock(),
        status: MuseSweepStatus.skippedResources,
        bridgeCount: 0,
      );
      rethrow;
    } finally {
      _running = false;
    }
  }

  Future<List<MuseBridgeDiscovery>> _discover(
    PersonalKnowledgeGraph graph,
    List<SemanticCluster> clusters,
    DateTime now,
  ) async {
    final visits = store.clusterVisits();
    final cutoff = now.toUtc().subtract(dormantAge);
    final dormant = clusters.where((cluster) {
      final lastTouched = visits[cluster.id] ?? cluster.updatedAt;
      return lastTouched.isBefore(cutoff);
    }).toList();
    if (dormant.length < 2) return const [];

    final nodeToCluster = <String, String>{};
    for (final cluster in dormant) {
      for (final nodeId in cluster.nodeIds) {
        nodeToCluster.putIfAbsent(nodeId, () => cluster.id);
      }
    }
    final candidateIds = nodeToCluster.keys.take(maximumSweepNodes).toSet();
    final vectors = await semanticStore.readAggregatedNodeVectors(
      nodeIds: candidateIds,
    );
    final nodes = {for (final node in graph.nodes) node.id: node};
    final connectedPairs = {
      for (final edge in graph.edges)
        _pair(edge.sourceNodeId, edge.targetNodeId),
    };
    final degree = <String, int>{};
    for (final edge in graph.edges) {
      degree.update(edge.sourceNodeId, (value) => value + 1, ifAbsent: () => 1);
      degree.update(edge.targetNodeId, (value) => value + 1, ifAbsent: () => 1);
    }

    final vectorsByNode = {for (final vector in vectors) vector.nodeId: vector};
    final candidates =
        <
          ({
            AggregatedNodeVector left,
            AggregatedNodeVector right,
            double score,
          })
        >[];
    final seenPairs = <String>{};
    for (final left in vectors) {
      final hits = await semanticStore.searchVector(
        left.vector,
        allowedNodeIds: candidateIds,
        limit: 16,
      );
      for (final rightId in hits.expand((hit) => hit.nodeIds)) {
        final right = vectorsByNode[rightId];
        if (right == null || right.nodeId == left.nodeId) continue;
        final pair = _pair(left.nodeId, right.nodeId);
        if (nodeToCluster[left.nodeId] == nodeToCluster[right.nodeId] ||
            connectedPairs.contains(pair) ||
            !seenPairs.add(pair)) {
          continue;
        }
        final score = _cosine(left.vector, right.vector);
        if (score < minimumBridgeSimilarity) continue;
        final orphanBonus =
            (degree[left.nodeId] ?? 0) == 0 || (degree[right.nodeId] ?? 0) == 0
            ? .04
            : 0;
        candidates.add((
          left: left,
          right: right,
          score: (score + orphanBonus).clamp(0, 1),
        ));
      }
    }
    candidates.sort((left, right) => right.score.compareTo(left.score));

    final discoveries = <MuseBridgeDiscovery>[];
    final edges = <GraphEdge>[];
    for (final candidate in candidates) {
      if (discoveries.length >= maximumBridges) break;
      final left = nodes[candidate.left.nodeId];
      final right = nodes[candidate.right.nodeId];
      if (left == null || right == null) continue;
      final evidence =
          (left.evidence.isNotEmpty ? left : right).evidence.firstOrNull;
      if (evidence == null) continue;
      final id = 'muse-bridge-${_pair(left.id, right.id)}';
      edges.add(
        GraphEdge(
          id: id,
          sourceNodeId: left.id,
          targetNodeId: right.id,
          type: EdgeType.associatedWith,
          isDirected: false,
          weight: candidate.score,
          origin: NodeOrigin.autonomousMuse,
          createdAt: now,
          evidence: [
            GraphEdgeEvidence(
              entryId: evidence.entryId,
              observedAt: evidence.observedAt,
              confidence: candidate.score,
              excerpt: evidence.excerpt,
              startUtf16: evidence.startUtf16,
              endUtf16: evidence.endUtf16,
            ),
          ],
        ),
      );
      discoveries.add(
        MuseBridgeDiscovery(
          id: id,
          sourceNodeId: left.id,
          targetNodeId: right.id,
          sourceLabel: left.label,
          targetLabel: right.label,
          sourceYear: left.createdAt.year,
          targetYear: right.createdAt.year,
          similarity: candidate.score,
          createdAt: now,
        ),
      );
    }
    if (edges.isNotEmpty) {
      await graphStore.update(
        (current) => PersonalKnowledgeGraph(
          schemaVersion: current.schemaVersion,
          nodes: current.nodes,
          edges: [...current.edges, ...edges],
          trajectories: current.trajectories,
          materialization: current.materialization,
          clock: current.clock,
        ),
      );
    }
    return List.unmodifiable(discoveries);
  }

  Future<ActionPlan?> _reviveActionPlan() async {
    final plans = await actionPlanStore.list();
    final incomplete =
        plans
            .where((plan) => plan.status != ActionPlanStatus.completed)
            .toList()
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return incomplete.firstOrNull;
  }
}

double _cosine(List<double> left, List<double> right) {
  if (left.length != right.length || left.isEmpty) return -1;
  var dot = 0.0;
  var leftNorm = 0.0;
  var rightNorm = 0.0;
  for (var index = 0; index < left.length; index++) {
    dot += left[index] * right[index];
    leftNorm += left[index] * left[index];
    rightNorm += right[index] * right[index];
  }
  if (leftNorm == 0 || rightNorm == 0) return -1;
  return dot / (math.sqrt(leftNorm) * math.sqrt(rightNorm));
}

String _pair(String left, String right) =>
    left.compareTo(right) <= 0 ? '$left::$right' : '$right::$left';

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
