import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_store.dart';
import 'package:voicememory_mobile/features/cognitive_analytics/burnout_detector.dart';
import 'package:voicememory_mobile/features/cognitive_analytics/cognitive_metrics_engine.dart';
import 'package:voicememory_mobile/features/cognitive_analytics/cognitive_metrics_models.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('calculates null-aware moving averages for 7, 30 and 90 days', () {
    final values = <double?>[1, null, -1, .5];

    expect(CognitiveMetricsEngine.movingAverage(values, 2), [1, 1, -1, -.25]);
    expect(
      CognitiveMetricsEngine.movingAverage(values, 30).last,
      closeTo(.1667, .001),
    );
    expect(CognitiveMetricsEngine.movingAverage(values, 90), hasLength(4));
  });

  test('aggregates reflection mood and intensity into bounded sentiment', () {
    final positive = _entry(
      'positive',
      DateTime.utc(2026, 7, 28),
      mood: 'grateful and hopeful',
      intensity: 8,
    );
    final negative = _entry(
      'negative',
      DateTime.utc(2026, 7, 28),
      mood: 'overwhelmed and exhausted',
      intensity: 9,
    );

    expect(CognitiveMetricsEngine.sentimentForEntry(positive), greaterThan(.5));
    expect(CognitiveMetricsEngine.sentimentForEntry(negative), lessThan(-.5));
  });

  test(
    'filters the local SQLite metric index by selected date range',
    () async {
      final harness = _Harness.create();
      addTearDown(harness.dispose);
      final today = DateTime.utc(2026, 7, 28);
      harness.index.replace([
        for (var offset = 399; offset >= 0; offset--)
          _point(today.subtract(Duration(days: offset))),
      ]);

      final week = await harness.engine.calculate(
        CognitiveTimeRange.week,
        refresh: false,
      );
      final month = await harness.engine.calculate(
        CognitiveTimeRange.month,
        refresh: false,
      );
      final year = await harness.engine.calculate(
        CognitiveTimeRange.year,
        refresh: false,
      );
      final all = await harness.engine.calculate(
        CognitiveTimeRange.allTime,
        refresh: false,
      );

      expect(week.points, hasLength(7));
      expect(month.points, hasLength(30));
      expect(year.points, hasLength(365));
      expect(all.points, hasLength(400));
    },
  );

  test(
    'rebuild stores only daily aggregates from journal reflections',
    () async {
      final harness = _Harness.create(
        entries: [
          _entry(
            'one',
            DateTime.utc(2026, 7, 27, 9),
            mood: 'hopeful',
            intensity: 6,
          ),
          _entry(
            'two',
            DateTime.utc(2026, 7, 27, 18),
            mood: 'grateful',
            intensity: 7,
          ),
        ],
      );
      addTearDown(harness.dispose);

      await harness.engine.rebuild();
      final rows = harness.index.query();

      expect(rows.lastWhere((point) => point.day.day == 27).journalCount, 2);
      expect(
        rows.lastWhere((point) => point.day.day == 27).valence,
        greaterThan(0),
      );
      expect(
        latin1.decode(
          File('${harness.root.path}/metrics.db').readAsBytesSync(),
        ),
        isNot(contains('hopeful')),
      );
    },
  );

  test('flags three consecutive days of converging fatigue signals', () {
    final start = DateTime.utc(2026, 7, 26);
    final points = [
      for (var index = 0; index < 3; index++)
        CognitiveMetricPoint(
          day: start.add(Duration(days: index)),
          valence: -.5,
          movingAverage7: -.4,
          movingAverage30: -.3,
          movingAverage90: -.2,
          cognitiveLoad: .8,
          semanticVelocity: .1,
          habitMomentum: .3 - index * .1,
          sleepHours: 7 - index * .5,
          journalCount: 1,
          negativeClusterDensity: .7,
          activeNodeCount: 8,
          resolvedClusterCount: 1,
        ),
    ];

    final advisory = const BurnoutDetector().evaluate(points);

    expect(advisory?.level, BurnoutRiskLevel.elevated);
    expect(advisory?.message, contains('not a diagnosis'));
  });
}

JournalEntry _entry(
  String id,
  DateTime createdAt, {
  required String mood,
  required int intensity,
}) => JournalEntry(
  id: id,
  createdAt: createdAt,
  transcript: 'Private source words.',
  durationSeconds: 30,
  reflection: Reflection(
    mood: mood,
    emotionalIntensity: intensity,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: mood,
    repeatedSignal: mood,
  ),
);

CognitiveMetricPoint _point(DateTime day) => CognitiveMetricPoint(
  day: day,
  valence: .1,
  movingAverage7: .1,
  movingAverage30: .1,
  movingAverage90: .1,
  cognitiveLoad: .4,
  semanticVelocity: .3,
  habitMomentum: .5,
  sleepHours: 7,
  journalCount: 1,
  negativeClusterDensity: 0,
  activeNodeCount: 2,
  resolvedClusterCount: 2,
);

final class _Harness {
  const _Harness(
    this.root,
    this.journal,
    this.graph,
    this.clusters,
    this.plans,
    this.index,
    this.engine,
  );

  final Directory root;
  final JournalStore journal;
  final PersonalKnowledgeGraphStore graph;
  final SemanticClusterStore clusters;
  final ActionPlanStore plans;
  final CognitiveMetricsIndex index;
  final CognitiveMetricsEngine engine;

  static _Harness create({List<JournalEntry> entries = const []}) {
    final root = Directory.systemTemp.createTempSync('cognitive-metrics-');
    final journalFile = File('${root.path}/journal.json')
      ..writeAsStringSync(
        jsonEncode(entries.map((entry) => entry.toJson()).toList()),
      );
    final journal = JournalStore(file: journalFile);
    final keys = InMemoryPrivateDataEncryptionKeyStore();
    EncryptedJsonFileStore encrypted(String name) => EncryptedJsonFileStore(
      file: File('${root.path}/$name.enc'),
      keyStore: keys,
    );
    final graph = PersonalKnowledgeGraphStore(storage: encrypted('graph'));
    final clusters = SemanticClusterStore(storage: encrypted('clusters'));
    final plans = ActionPlanStore(storage: encrypted('plans'));
    final index = CognitiveMetricsIndex.open('${root.path}/metrics.db');
    final engine = CognitiveMetricsEngine(
      journalStore: journal,
      graphStore: graph,
      clusterStore: clusters,
      actionPlanStore: plans,
      index: index,
      clock: () => DateTime.utc(2026, 7, 28),
    );
    return _Harness(root, journal, graph, clusters, plans, index, engine);
  }

  Future<void> dispose() async {
    plans.dispose();
    clusters.dispose();
    await graph.dispose();
    index.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
