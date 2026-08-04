import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_models.dart';
import 'package:voicememory_mobile/features/action_plans/ui/action_plans_overlay.dart';
import 'package:voicememory_mobile/features/memory_graph/memory_graph_canvas.dart';
import 'package:voicememory_mobile/widgets/life_os/interactive_knowledge_graph_widget.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 12);

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required ActionPlan plan,
    ActionPlanCheckIn? checkIn,
    ActionPlanLifecycle? pause,
    ActionPlanLifecycle? resume,
    ValueChanged<ActionPlanCheckInResult>? onMilestone,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: ActionPlansOverlay(
            load: () async => [plan],
            checkIn: checkIn,
            pause: pause,
            resume: resume,
            onMilestone: onMilestone,
            now: now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('checks off with selection haptic', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final plan = _plan();
    await pumpOverlay(
      tester,
      plan: plan,
      checkIn: (_, _) async => _result(plan, count: 1),
    );

    await tester.tap(find.byKey(const Key('micro-habit-check-step')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Completed today'), findsOneWidget);
    expect(
      calls,
      contains(
        isA<MethodCall>()
            .having((call) => call.method, 'method', 'HapticFeedback.vibrate')
            .having(
              (call) => call.arguments,
              'arguments',
              'HapticFeedbackType.selectionClick',
            ),
      ),
    );
  });

  testWidgets('uses medium haptic and reports a milestone', (tester) async {
    final calls = <MethodCall>[];
    ActionPlanCheckInResult? celebrated;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final plan = _plan(count: 6);
    await pumpOverlay(
      tester,
      plan: plan,
      checkIn: (_, _) async => _result(plan, count: 7, milestone: 7),
      onMilestone: (result) => celebrated = result,
    );

    await tester.tap(find.byKey(const Key('micro-habit-check-step')));
    await tester.pumpAndSettle();

    expect(celebrated?.milestoneReached, 7);
    expect(
      calls,
      contains(
        isA<MethodCall>()
            .having((call) => call.method, 'method', 'HapticFeedback.vibrate')
            .having(
              (call) => call.arguments,
              'arguments',
              'HapticFeedbackType.mediumImpact',
            ),
      ),
    );
  });

  testWidgets('pauses and resumes plans', (tester) async {
    var plan = _plan();
    await pumpOverlay(
      tester,
      plan: plan,
      pause: (_) async {
        plan = plan.copyWith(status: ActionPlanStatus.paused);
        return plan;
      },
      resume: (_) async {
        plan = plan.copyWith(status: ActionPlanStatus.active);
        return plan;
      },
    );

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('stays compact with large Dynamic Type', (tester) async {
    await pumpOverlay(tester, plan: _plan(), textScale: 2);

    expect(find.byKey(const Key('micro-habit-step')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('days in a row'), findsOneWidget);
  });

  testWidgets('canvas highlights reinforcement and celebrates milestones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = _plan(count: 6);
    ActionPlanCheckInResult? celebrated;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MemoryGraphCanvas(
              graph: PersonalKnowledgeGraph(
                nodes: [
                  GraphNode(
                    id: 'target',
                    type: NodeType.habit,
                    label: 'Quiet breath',
                    confidence: .5,
                  ),
                ],
              ),
              actionPlansLoader: () async => [plan],
              actionPlanCheckIn: (_, _) async =>
                  _result(plan, count: 7, milestone: 7),
              onActionPlanMilestone: (result) => celebrated = result,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('action-plans-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('micro-habit-check-step')));
    await tester.pump();

    final graph = tester.widget<InteractiveKnowledgeGraphWidget>(
      find.byType(InteractiveKnowledgeGraphWidget),
    );
    expect(graph.highlightedNodeIds, contains('target'));
    expect(graph.burstNodeIds, contains('target'));
    expect(celebrated?.milestoneReached, 7);

    await tester.pump(const Duration(seconds: 3));
    final settledGraph = tester.widget<InteractiveKnowledgeGraphWidget>(
      find.byType(InteractiveKnowledgeGraphWidget),
    );
    expect(settledGraph.burstNodeIds, isNot(contains('target')));
  });
}

ActionPlan _plan({int count = 0}) {
  const id = 'plan';
  return ActionPlan(
    id: id,
    clusterId: 'cluster',
    title: 'Feel more grounded',
    targetOutcome: 'Make calm easier to reach',
    createdAt: DateTime.utc(2026, 7, 1),
    steps: [
      MicroHabitStep(
        id: 'step',
        planId: id,
        title: 'Take one quiet breath',
        frequency: ActionPlanFrequency.daily(),
        targetNodeId: 'target',
        streakCount: count,
      ),
    ],
  );
}

ActionPlanCheckInResult _result(
  ActionPlan plan, {
  required int count,
  int? milestone,
}) {
  final step = plan.steps.single.copyWith(
    streakCount: count,
    completionHistory: const {'2026-07-27': true},
  );
  final updated = plan.copyWith(steps: [step]);
  return ActionPlanCheckInResult(
    plan: updated,
    step: step,
    alreadyCheckedIn: false,
    reinforcedNodeIds: const ['target'],
    reinforcedEdgeIds: const ['edge'],
    milestoneReached: milestone,
  );
}
