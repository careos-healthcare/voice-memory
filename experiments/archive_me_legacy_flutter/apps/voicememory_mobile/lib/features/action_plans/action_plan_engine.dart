// ignore_for_file: prefer_initializing_formals

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import 'action_plan_models.dart';
import 'action_plan_reminder_scheduler.dart';
import 'action_plan_store.dart';

final class ActionPlanEngine {
  ActionPlanEngine({
    required ActionPlanStore store,
    required PersonalKnowledgeGraphStore graphStore,
    ActionPlanReminderScheduler reminderScheduler =
        const NoopActionPlanReminderScheduler(),
    Future<void> Function()? onPlansChanged,
  }) : _store = store,
       _graphStore = graphStore,
       _reminders = reminderScheduler,
       _onPlansChanged = onPlansChanged;

  final ActionPlanStore _store;
  final PersonalKnowledgeGraphStore _graphStore;
  final ActionPlanReminderScheduler _reminders;
  final Future<void> Function()? _onPlansChanged;

  Future<List<ActionPlan>> list() => _store.list();

  Future<void> clear() async {
    final plans = await _store.list();
    for (final step in plans.expand((plan) => plan.steps)) {
      await _reminders.cancel(step.id);
    }
    await _store.clear();
    await _onPlansChanged?.call();
  }

  Future<ActionPlan> create(ActionPlan plan) async {
    if (await _store.get(plan.id) != null) {
      throw StateError('Action plan already exists: ${plan.id}');
    }
    await _store.upsert(plan);
    await _onPlansChanged?.call();
    if (plan.status == ActionPlanStatus.active) {
      for (final step in plan.steps) {
        await _reminders.schedule(plan, step);
      }
    }
    return plan;
  }

  Future<ActionPlan> pause(String planId) =>
      _setStatus(planId, ActionPlanStatus.paused);

  Future<ActionPlan> resume(String planId) =>
      _setStatus(planId, ActionPlanStatus.active);

  Future<ActionPlanCheckInResult> checkIn(String stepId, DateTime date) async {
    final day = DateTime.utc(date.year, date.month, date.day);
    final dateKey = canonicalActionPlanDate(day);
    ActionPlan? previousPlan;
    MicroHabitStep? previousStep;
    for (final plan in await _store.list()) {
      for (final step in plan.steps) {
        if (step.id == stepId) {
          previousPlan = plan;
          previousStep = step;
          break;
        }
      }
      if (previousStep != null) break;
    }
    final foundStep = previousStep;
    if (foundStep == null) {
      throw StateError('Action plan step not found: $stepId');
    }
    final foundPlan = previousPlan!;
    if (!foundStep.frequency.isScheduled(day)) {
      throw ArgumentError.value(date, 'date', 'is not scheduled for this step');
    }
    if (foundStep.completionHistory[dateKey] == true) {
      return ActionPlanCheckInResult(
        plan: foundPlan,
        step: foundStep,
        alreadyCheckedIn: true,
      );
    }
    if (foundPlan.status != ActionPlanStatus.active) {
      throw StateError('Only active action plans can be checked in.');
    }

    late ActionPlan nextPlan;
    late MicroHabitStep nextStep;
    var didRecord = false;
    await _store.update<void>((plans) {
      final currentPlan = plans[foundPlan.id];
      if (currentPlan == null) {
        throw StateError('Action plan not found: ${foundPlan.id}');
      }
      final index = currentPlan.steps.indexWhere((step) => step.id == stepId);
      if (index < 0) throw StateError('Action plan step not found: $stepId');
      final currentStep = currentPlan.steps[index];
      if (currentStep.completionHistory[dateKey] == true) {
        nextPlan = currentPlan;
        nextStep = currentStep;
        return;
      }
      final history = {...currentStep.completionHistory, dateKey: true};
      final latestDate = history.keys.reduce(
        (left, right) => left.compareTo(right) >= 0 ? left : right,
      );
      nextStep = currentStep.copyWith(
        completionHistory: history,
        streakCount: calculateActionPlanStreak(
          frequency: currentStep.frequency,
          completionHistory: history,
          through: parseCanonicalActionPlanDate(latestDate),
        ),
      );
      didRecord = true;
      final steps = currentPlan.steps.toList()..[index] = nextStep;
      final completed =
          steps.isNotEmpty && steps.every((step) => step.streakCount >= 30);
      nextPlan = currentPlan.copyWith(
        steps: steps,
        status: completed ? ActionPlanStatus.completed : currentPlan.status,
      );
      plans[nextPlan.id] = nextPlan;
    });

    // A concurrent duplicate reaching the atomic store update must not
    // reinforce twice.
    if (!didRecord) {
      return ActionPlanCheckInResult(
        plan: nextPlan,
        step: nextStep,
        alreadyCheckedIn: true,
      );
    }

    final reinforcedNodes = <String>[];
    final reinforcedEdges = <String>[];
    await _graphStore.update((graph) {
      final targetExists = graph.nodes.any(
        (node) => node.id == nextStep.targetNodeId,
      );
      if (!targetExists) return graph;
      final nodes = graph.nodes.map((node) {
        if (node.id != nextStep.targetNodeId) return node;
        reinforcedNodes.add(node.id);
        return _nodeWithConfidence(
          node,
          (node.confidence + 0.03).clamp(0.0, 1.0),
        );
      }).toList();
      final edges = graph.edges.map((edge) {
        if (edge.sourceNodeId != nextStep.targetNodeId &&
            edge.targetNodeId != nextStep.targetNodeId) {
          return edge;
        }
        reinforcedEdges.add(edge.id);
        return _edgeWithWeight(edge, (edge.weight + 0.02).clamp(0.0, 1.0));
      }).toList();
      return PersonalKnowledgeGraph(
        schemaVersion: graph.schemaVersion,
        nodes: nodes,
        edges: edges,
        trajectories: graph.trajectories,
        materialization: graph.materialization,
        clock: graph.clock,
      );
    });

    if (nextPlan.status == ActionPlanStatus.completed) {
      for (final step in nextPlan.steps) {
        await _reminders.cancel(step.id);
      }
    } else {
      await _reminders.schedule(nextPlan, nextStep);
    }
    await _onPlansChanged?.call();
    final priorStreak = foundStep.streakCount;
    final milestone = const [
      7,
      14,
      30,
    ].where((value) => nextStep.streakCount == value && priorStreak < value);
    return ActionPlanCheckInResult(
      plan: nextPlan,
      step: nextStep,
      alreadyCheckedIn: false,
      reinforcedNodeIds: reinforcedNodes,
      reinforcedEdgeIds: reinforcedEdges,
      milestoneReached: milestone.firstOrNull,
    );
  }

  Future<ActionPlan> _setStatus(String planId, ActionPlanStatus status) async {
    final current = await _store.get(planId);
    if (current == null) throw StateError('Action plan not found: $planId');
    if (current.status == ActionPlanStatus.completed) {
      throw StateError('A completed action plan cannot change lifecycle.');
    }
    if (current.status == status) return current;
    final next = current.copyWith(status: status);
    await _store.upsert(next);
    await _onPlansChanged?.call();
    for (final step in next.steps) {
      if (status == ActionPlanStatus.active) {
        await _reminders.schedule(next, step);
      } else {
        await _reminders.cancel(step.id);
      }
    }
    return next;
  }
}

int calculateActionPlanStreak({
  required ActionPlanFrequency frequency,
  required Map<String, bool> completionHistory,
  required DateTime through,
}) {
  var cursor = DateTime.utc(
    through.toUtc().year,
    through.toUtc().month,
    through.toUtc().day,
  );
  while (!frequency.isScheduled(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (true) {
    final completed = completionHistory[canonicalActionPlanDate(cursor)];
    if (completed != true) return streak;
    streak++;
    do {
      cursor = cursor.subtract(const Duration(days: 1));
    } while (!frequency.isScheduled(cursor));
  }
}

GraphNode _nodeWithConfidence(GraphNode node, num confidence) => GraphNode(
  id: node.id,
  type: node.type,
  label: node.label,
  confidence: confidence,
  evidence: node.evidence,
  origin: node.origin,
  createdAt: node.createdAt,
  archivedAt: node.archivedAt,
  theoryId: node.theoryId,
  externalSource: node.externalSource,
  mediaAttachments: node.mediaAttachments,
  tags: node.tags,
);

GraphEdge _edgeWithWeight(GraphEdge edge, num weight) => GraphEdge(
  id: edge.id,
  sourceNodeId: edge.sourceNodeId,
  targetNodeId: edge.targetNodeId,
  type: edge.type,
  isDirected: edge.isDirected,
  weight: weight,
  interactionDate: edge.interactionDate,
  emotionalValenceScore: edge.emotionalValenceScore,
  intensity: edge.intensity,
  evidence: edge.evidence,
  origin: edge.origin,
  createdAt: edge.createdAt,
  archivedAt: edge.archivedAt,
  theoryId: edge.theoryId,
  externalSource: edge.externalSource,
);
