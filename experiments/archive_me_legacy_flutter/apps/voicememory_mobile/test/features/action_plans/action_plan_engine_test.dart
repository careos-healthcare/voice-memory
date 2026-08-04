import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_engine.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_models.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_reminder_scheduler.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('daily and custom schedules count only consecutive scheduled days', () {
    expect(
      calculateActionPlanStreak(
        frequency: ActionPlanFrequency.daily(),
        completionHistory: const {
          '2026-07-24': true,
          '2026-07-25': false,
          '2026-07-26': true,
          '2026-07-27': true,
        },
        through: DateTime.utc(2026, 7, 27),
      ),
      2,
    );
    expect(
      calculateActionPlanStreak(
        frequency: ActionPlanFrequency.customDays({
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        }),
        completionHistory: const {
          '2026-07-20': true,
          '2026-07-22': true,
          '2026-07-24': true,
          '2026-07-27': true,
        },
        through: DateTime.utc(2026, 7, 27),
      ),
      4,
    );
    expect(
      calculateActionPlanStreak(
        frequency: ActionPlanFrequency.customDays({
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        }),
        completionHistory: const {
          '2026-07-20': true,
          '2026-07-24': true,
          '2026-07-27': true,
        },
        through: DateTime.utc(2026, 7, 27),
      ),
      2,
    );
  });

  test(
    'check-in is idempotent and reinforces graph without data loss',
    () async {
      final root = await Directory.systemTemp.createTemp('action_plan_engine_');
      final keyStore = InMemoryPrivateDataEncryptionKeyStore();
      EncryptedJsonFileStore encrypted(String name) => EncryptedJsonFileStore(
        file: File('${root.path}/$name.enc'),
        keyStore: keyStore,
      );
      final graphStore = PersonalKnowledgeGraphStore(
        storage: encrypted('graph'),
      );
      final planStore = ActionPlanStore(storage: encrypted('plans'));
      final reminders = FakeActionPlanReminderScheduler();
      final engine = ActionPlanEngine(
        store: planStore,
        graphStore: graphStore,
        reminderScheduler: reminders,
      );
      addTearDown(() async {
        planStore.dispose();
        await graphStore.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      });
      final target = _node('target', 0.95);
      final other = _node('other', 0.4);
      final edge = GraphEdge(
        id: 'edge',
        sourceNodeId: target.id,
        targetNodeId: other.id,
        type: EdgeType.influences,
        isDirected: true,
        weight: 0.99,
        evidence: [_edgeEvidence()],
        createdAt: DateTime.utc(2026),
      );
      await graphStore.save(
        PersonalKnowledgeGraph(
          nodes: [target, other],
          edges: [edge],
          trajectories: [
            GraphTrajectory(
              type: GraphTrajectoryType.projectProgress,
              subjectNodeId: target.id,
            ),
          ],
        ),
      );
      final plan = _plan();
      await engine.create(plan);
      expect(reminders.scheduled, contains('step'));

      final first = await engine.checkIn('step', DateTime.utc(2026, 7, 27));
      final duplicate = await engine.checkIn(
        'step',
        DateTime.utc(2026, 7, 27, 23),
      );

      expect(first.alreadyCheckedIn, isFalse);
      expect(first.reinforcedNodeIds, ['target']);
      expect(first.reinforcedEdgeIds, ['edge']);
      expect(duplicate.alreadyCheckedIn, isTrue);
      final graph = await graphStore.load();
      expect(
        graph.nodes.singleWhere((node) => node.id == 'target').confidence,
        0.98,
      );
      expect(
        graph.nodes.singleWhere((node) => node.id == 'other').confidence,
        0.4,
      );
      expect(graph.edges.single.weight, 1);
      expect(graph.edges.single.evidence.single.excerpt, 'edge');
      expect(graph.materialization.extractorVersion, '');
    },
  );

  test('milestones and lifecycle reminders follow plan state', () async {
    final root = await Directory.systemTemp.createTemp(
      'action_plan_lifecycle_',
    );
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    EncryptedJsonFileStore encrypted(String name) => EncryptedJsonFileStore(
      file: File('${root.path}/$name.enc'),
      keyStore: keyStore,
    );
    final graphStore = PersonalKnowledgeGraphStore(storage: encrypted('graph'));
    final store = ActionPlanStore(storage: encrypted('plans'));
    final reminders = FakeActionPlanReminderScheduler();
    final engine = ActionPlanEngine(
      store: store,
      graphStore: graphStore,
      reminderScheduler: reminders,
    );
    addTearDown(() async {
      store.dispose();
      await graphStore.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    });
    await engine.create(_plan());
    await engine.pause('plan');
    expect(reminders.scheduled, isEmpty);
    await engine.resume('plan');
    expect(reminders.scheduled, contains('step'));

    ActionPlanCheckInResult? result;
    for (var day = 1; day <= 30; day++) {
      result = await engine.checkIn('step', DateTime.utc(2026, 7, day));
      if (day == 7 || day == 14 || day == 30) {
        expect(result.milestoneReached, day);
      }
    }
    expect(result!.plan.status, ActionPlanStatus.completed);
    expect(reminders.scheduled, isEmpty);
  });

  test('check-in preserves the supplied local calendar day', () async {
    final root = await Directory.systemTemp.createTemp(
      'action_plan_local_day_',
    );
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    EncryptedJsonFileStore encrypted(String name) => EncryptedJsonFileStore(
      file: File('${root.path}/$name.enc'),
      keyStore: keyStore,
    );
    final graphStore = PersonalKnowledgeGraphStore(storage: encrypted('graph'));
    final store = ActionPlanStore(storage: encrypted('plans'));
    final engine = ActionPlanEngine(store: store, graphStore: graphStore);
    addTearDown(() async {
      store.dispose();
      await graphStore.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    });
    await engine.create(_plan());

    final suppliedLocalDay = DateTime(2026, 1, 1, 0, 15);
    final result = await engine.checkIn('step', suppliedLocalDay);

    expect(result.step.completionHistory, contains('2026-01-01'));
    expect(result.step.completionHistory, isNot(contains('2025-12-31')));
  });

  test(
    'clear cancels reminders, clears encrypted state, and records change',
    () async {
      final root = await Directory.systemTemp.createTemp('action_plan_clear_');
      final keyStore = InMemoryPrivateDataEncryptionKeyStore();
      final planFile = File('${root.path}/plans.enc');
      final planStorage = EncryptedJsonFileStore(
        file: planFile,
        keyStore: keyStore,
      );
      final graphStore = PersonalKnowledgeGraphStore(
        storage: EncryptedJsonFileStore(
          file: File('${root.path}/graph.enc'),
          keyStore: keyStore,
        ),
      );
      final store = ActionPlanStore(storage: planStorage);
      final reminders = FakeActionPlanReminderScheduler();
      var changes = 0;
      final engine = ActionPlanEngine(
        store: store,
        graphStore: graphStore,
        reminderScheduler: reminders,
        onPlansChanged: () async {
          changes++;
        },
      );
      addTearDown(() async {
        store.dispose();
        await graphStore.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      });
      await engine.create(_plan());
      expect(reminders.scheduled, contains('step'));
      changes = 0;

      await engine.clear();

      expect(reminders.cancelled, contains('step'));
      expect(reminders.scheduled, isEmpty);
      expect(await store.list(), isEmpty);
      expect(await planStorage.readJson(), {
        'schemaVersion': 1,
        'plans': <Object>[],
      });
      expect(
        await planFile.readAsString(),
        isNot(contains('Build consistency')),
      );
      expect(changes, 1);
    },
  );
}

ActionPlan _plan() => ActionPlan(
  id: 'plan',
  clusterId: 'cluster',
  title: 'Build consistency',
  targetOutcome: 'A durable habit',
  createdAt: DateTime.utc(2026, 7, 1),
  steps: [
    MicroHabitStep(
      id: 'step',
      planId: 'plan',
      title: 'Practice',
      frequency: ActionPlanFrequency.daily(),
      targetNodeId: 'target',
    ),
  ],
);

GraphNode _node(String id, double confidence) => GraphNode(
  id: id,
  type: NodeType.habit,
  label: id,
  confidence: confidence,
  evidence: [
    GraphNodeEvidence(
      entryId: 'entry-$id',
      observedAt: DateTime.utc(2026),
      confidence: confidence,
      excerpt: id,
      startUtf16: 0,
      endUtf16: id.length,
    ),
  ],
  createdAt: DateTime.utc(2026),
);

GraphEdgeEvidence _edgeEvidence() => GraphEdgeEvidence(
  entryId: 'entry-edge',
  observedAt: DateTime.utc(2026),
  confidence: 0.8,
  excerpt: 'edge',
  startUtf16: 0,
  endUtf16: 4,
);
