import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/engines/ai_time_machine_engine.dart';
import 'package:voicememory_mobile/core/engines/evidence_coaching_engine.dart';
import 'package:voicememory_mobile/core/engines/goal_evidence_engine.dart';
import 'package:voicememory_mobile/core/engines/identity_evolution_engine.dart';
import 'package:voicememory_mobile/core/engines/life_chapters_engine.dart';
import 'package:voicememory_mobile/core/engines/life_story_engine.dart';
import 'package:voicememory_mobile/core/engines/long_term_predictor_engine.dart';
import 'package:voicememory_mobile/core/engines/memory_timeline_engine.dart';
import 'package:voicememory_mobile/core/engines/relationship_memory_engine.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';

void main() {
  group('RelationshipMemoryEngine', () {
    test('calculates sentiment trajectory, delta, topics, and citations', () {
      final alex = _node('alex', NodeType.person, 'Alex', [
        _evidence('relationship-1', '2025-01-01', 'Alex was angry and tense.'),
        _evidence(
          'relationship-2',
          '2025-02-15',
          'Alex was kind, supportive, and calm.',
        ),
      ]);
      final work = _node('work', NodeType.event, 'Work', [
        _evidence('topic-1', '2025-01-02', 'Work was discussed.'),
      ]);
      final travel = _node('travel', NodeType.event, 'Travel', [
        _evidence('topic-2', '2025-02-20', 'Travel was discussed.'),
      ]);
      final graph = PersonalKnowledgeGraph(
        nodes: [alex, work, travel],
        edges: [
          _edge('alex-work', alex, work),
          _edge('alex-travel', alex, travel),
        ],
      );

      final result = RelationshipMemoryEngine(
        graph,
      ).analyze(window: const Duration(days: 30)).single;

      expect(result.sentimentTrajectory, hasLength(2));
      expect(result.sentimentTrajectory.first.positivity, 0);
      expect(result.sentimentTrajectory.last.positivity, 1);
      expect(result.positivityPercentDelta, 100);
      expect(result.earlierTopics, contains('Work'));
      expect(result.laterTopics, contains('Travel'));
      expect(result.evidence.map((item) => item.entryId), [
        'relationship-1',
        'relationship-2',
      ]);
    });

    test('handles people without evidence safely', () {
      final graph = PersonalKnowledgeGraph(
        nodes: [_node('person', NodeType.person, 'No evidence', const [])],
      );
      expect(RelationshipMemoryEngine(graph).analyze(), isEmpty);
    });
  });

  group('MemoryTimelineEngine', () {
    test('returns exact deduplicated count and IDs with since filtering', () {
      final graph = PersonalKnowledgeGraph(
        nodes: [
          _node('running', NodeType.habit, 'Running', [
            _evidence('entry-1', '2024-01-01', 'Morning run'),
            _evidence('entry-2', '2025-01-01', 'Running before work'),
          ]),
          _node('memory', NodeType.memory, 'Weekend', [
            _evidence('entry-2', '2025-01-01', 'Running before work'),
            _evidence('entry-3', '2025-02-01', 'I considered running again'),
          ]),
        ],
      );
      final engine = MemoryTimelineEngine(graph);

      final all = engine.getMentionFrequency(' RUNNING ');
      expect(all.count, 3);
      expect(all.memoryEntryIds, ['entry-1', 'entry-2', 'entry-3']);

      final recent = engine.getMentionFrequency(
        'running',
        since: DateTime.utc(2025),
      );
      expect(recent.count, 2);
      expect(recent.memoryEntryIds, ['entry-2', 'entry-3']);
    });

    test('correlates event nodes through shared edge evidence IDs', () {
      final event = _node('event', NodeType.event, 'Conference', [
        _evidence('conference-1', '2025-04-01', 'Conference with Sam'),
      ]);
      final sam = _node('sam', NodeType.person, 'Sam', [
        _evidence('conference-1', '2025-04-01', 'Conference with Sam'),
      ]);
      final graph = PersonalKnowledgeGraph(
        nodes: [event, sam],
        edges: [_edge('event-sam', event, sam)],
      );
      final result = MemoryTimelineEngine(graph).correlateAnchorEvents().single;
      expect(result.relatedLabel, 'Sam');
      expect(result.evidence.single.entryId, 'conference-1');
    });
  });

  group('AITimeMachineEngine', () {
    final now = DateTime.utc(2026, 7, 23, 12);

    test('resolves two years ago and includes only window evidence', () {
      final graph = PersonalKnowledgeGraph(
        nodes: [
          _node('old', NodeType.belief, 'Curious', [
            _evidence('in-window', '2024-07-23', 'I felt curious.'),
          ]),
          _node('recent', NodeType.belief, 'Busy', [
            _evidence('out-window', '2026-07-01', 'I felt busy.'),
          ]),
        ],
      );
      final result = AITimeMachineEngine(
        graph,
        clock: () => now,
      ).query('What was I like two years ago?');

      expect(result.parsedQuery.intent, HistoricalQueryIntent.relativeSnapshot);
      expect(result.snapshots.single.label, 'Curious');
      expect(result.evidence.single.entryId, 'in-window');
    });

    test('finds earliest confidence transition with exact citation', () {
      final graph = PersonalKnowledgeGraph(
        nodes: [
          _node('confidence', NodeType.belief, 'Confidence', [
            _evidence(
              'confidence-first',
              '2025-03-10',
              'I became confident speaking.',
            ),
            _evidence(
              'confidence-later',
              '2025-08-10',
              'I still felt confident.',
            ),
          ]),
        ],
      );
      final result = AITimeMachineEngine(
        graph,
        clock: () => now,
      ).query('When did I become confident?');

      expect(result.parsedQuery.intent, HistoricalQueryIntent.transition);
      expect(result.parsedQuery.subject, 'confident');
      expect(result.evidence.map((e) => e.entryId), ['confidence-first']);
    });

    test('uses a bounded fallback rather than all history', () {
      final graph = PersonalKnowledgeGraph(
        nodes: [
          _node('memory', NodeType.memory, 'Memory', [
            _evidence('old', '2020-01-01', 'An old memory'),
            _evidence('recent', '2026-07-01', 'A recent memory'),
          ]),
        ],
      );
      final result = AITimeMachineEngine(
        graph,
        clock: () => now,
      ).query('Show me something unspecified');

      expect(result.parsedQuery.intent, HistoricalQueryIntent.boundedFallback);
      expect(result.evidence.map((e) => e.entryId), ['recent']);
    });

    test('builds a bounded snapshot for a selected graph entity', () {
      final confidence = _node('confidence', NodeType.belief, 'Confidence', [
        _evidence('confidence-1', '2025-03-10', 'I felt confident speaking.'),
        _evidence('confidence-2', '2025-04-10', 'Confidence continued.'),
      ]);
      final graph = PersonalKnowledgeGraph(nodes: [confidence]);

      final result = AITimeMachineEngine(
        graph,
        clock: () => now,
      ).queryEntity(confidence);

      expect(result.parsedQuery.intent, HistoricalQueryIntent.entitySnapshot);
      expect(result.parsedQuery.subject, 'Confidence');
      expect(result.snapshots.single.nodeId, confidence.id);
      expect(result.evidence.map((item) => item.entryId), [
        'confidence-1',
        'confidence-2',
      ]);
      expect(result.parsedQuery.start, DateTime.utc(2025, 2, 8));
      expect(result.parsedQuery.end, DateTime.utc(2025, 5, 10));
    });
  });

  group('chapter, story, coaching, goal, and identity engines', () {
    late PersonalKnowledgeGraph graph;
    late GraphNode goal;
    late GraphNode habit;

    setUp(() {
      goal = _node('goal', NodeType.goal, 'Launch company', [
        _evidence('goal-1', '2025-01-01', 'My goal is launch company.'),
        _evidence('goal-2', '2025-02-01', 'Still planning the company.'),
      ]);
      habit = _node('habit', NodeType.habit, 'Weekly planning', [
        _evidence('habit-1', '2025-01-01T08:00:00Z', 'Weekly planning'),
        _evidence('habit-2', '2025-02-01T08:00:00Z', 'Weekly planning'),
      ]);
      final university = _node('university', NodeType.chapter, 'University', [
        _evidence('uni-1', '2012-09-01', 'Started university on campus.'),
        _evidence('uni-2', '2015-06-01', 'University graduation.'),
      ]);
      final beliefBefore = _node('before', NodeType.belief, 'I avoid risk', [
        _evidence('belief-before', '2024-01-01', 'I believe I avoid risk.'),
      ]);
      final beliefAfter = _node('after', NodeType.belief, 'I can try', [
        _evidence('belief-after', '2025-02-01', 'I believe I can try.'),
      ]);
      graph = PersonalKnowledgeGraph(
        nodes: [goal, habit, university, beliefBefore, beliefAfter],
        edges: [
          _edge('goal-habit', goal, habit),
          GraphEdge(
            id: 'belief-evolution',
            sourceNodeId: beliefBefore.id,
            targetNodeId: beliefAfter.id,
            type: EdgeType.evolvedInto,
            isDirected: true,
            weight: 0.8,
            evidence: [
              _edgeEvidence(
                'belief-reason',
                '2025-01-15',
                'Trying small projects changed the belief.',
              ),
            ],
          ),
        ],
      );
    });

    test('detects a cited known chapter and builds a quoted story', () {
      final chapter = LifeChaptersEngine(graph).detect().firstWhere(
        (item) => item.category == LifeChapterCategory.university,
      );
      expect(chapter.category, LifeChapterCategory.university);
      expect(chapter.evidence.map((e) => e.entryId), ['uni-1', 'uni-2']);
      expect(chapter.explainability.reasoning, isNotEmpty);
      expect(chapter.explainability.alternativeExplanation, isNotEmpty);
      expect(chapter.explainability.uncertainty, isNotEmpty);

      final story = LifeStoryEngine(graph).build();
      final universityStory = story.chapters.firstWhere(
        (item) => item.category == LifeChapterCategory.university,
      );
      expect(universityStory.narrative, contains('[uni-1]'));
      expect(universityStory.narrative, contains('University graduation.'));
    });

    test('surfaces cautious cross-domain observations with two IDs', () {
      final observations = EvidenceCoachingEngine(graph).find();
      final observation = observations.firstWhere(
        (item) => {
          item.firstLabel,
          item.secondLabel,
        }.containsAll({'Launch company', 'Weekly planning'}),
      );
      expect(observation.evidence.map((e) => e.entryId).toSet().length, 4);
      expect(observation.optionalReflection, contains('might consider'));
    });

    test('counts goal mentions and includes associated habit evidence', () {
      final record = GoalEvidenceEngine(graph).build().single;
      expect(record.mentionCount, 2);
      expect(record.evidence.map((e) => e.entryId), ['goal-1', 'goal-2']);
      expect(record.associatedHabitsAndActions.single.label, 'Weekly planning');
    });

    test('requires before, after, and edge-backed identity evidence', () {
      final shift = IdentityEvolutionEngine(
        graph,
      ).analyze(boundary: DateTime.utc(2025)).single;
      expect(shift.beforeEvidence.single.entryId, 'belief-before');
      expect(shift.afterEvidence.single.entryId, 'belief-after');
      expect(shift.reasonEvidence.single.entryId, 'belief-reason');
      expect(shift.confidence, 0.8);
      expect(shift.explainability.evidence, hasLength(3));
      expect(shift.explainability.reasoning, isNotEmpty);
    });
  });

  group('LongTermPredictorEngine', () {
    test('uses nonlinear monthly changes for a conditional forecast', () {
      final graph = PersonalKnowledgeGraph(
        nodes: [
          _node('exercise', NodeType.habit, 'Exercise', [
            _evidence('jan-1', '2025-01-01', 'Exercise'),
            _evidence('feb-1', '2025-02-01', 'Exercise'),
            _evidence('feb-2', '2025-02-10', 'Exercise'),
            _evidence('mar-1', '2025-03-01', 'Exercise'),
            _evidence('mar-2', '2025-03-10', 'Exercise'),
            _evidence('mar-3', '2025-03-20', 'Exercise'),
            _evidence('mar-4', '2025-03-25', 'Exercise'),
          ]),
        ],
      );
      final forecast = LongTermPredictorEngine(graph).forecast().single;
      expect(forecast.direction, TrajectoryDirection.increasing);
      expect(forecast.probability, inInclusiveRange(0, 1));
      expect(forecast.conditionalStatement, startsWith('If '));
      expect(forecast.evidence, hasLength(7));
      expect(forecast.explainability.confidence, inInclusiveRange(0, 100));
      expect(forecast.explainability.alternativeExplanation, isNotEmpty);
      expect(forecast.explainability.uncertainty, isNotEmpty);
    });

    test('omits sparse evidence', () {
      final graph = PersonalKnowledgeGraph(
        nodes: [
          _node('fear', NodeType.fear, 'Flying', [
            _evidence('fear-1', '2025-01-01', 'Fear of flying'),
          ]),
        ],
      );
      expect(LongTermPredictorEngine(graph).forecast(), isEmpty);
    });
  });
}

GraphNode _node(
  String id,
  NodeType type,
  String label,
  List<GraphNodeEvidence> evidence,
) => GraphNode(
  id: id,
  type: type,
  label: label,
  confidence: 0.9,
  evidence: evidence,
);

GraphNodeEvidence _evidence(String id, String at, String excerpt) =>
    GraphNodeEvidence(
      entryId: id,
      observedAt: _parseUtc(at),
      confidence: 0.9,
      excerpt: excerpt,
      startUtf16: 0,
      endUtf16: excerpt.length,
    );

GraphEdgeEvidence _edgeEvidence(String id, String at, String excerpt) =>
    GraphEdgeEvidence(
      entryId: id,
      observedAt: _parseUtc(at),
      confidence: 0.8,
      excerpt: excerpt,
      startUtf16: 0,
      endUtf16: excerpt.length,
    );

DateTime _parseUtc(String value) {
  final parsed = DateTime.parse(value);
  return parsed.isUtc
      ? parsed
      : DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
}

GraphEdge _edge(String id, GraphNode source, GraphNode target) => GraphEdge(
  id: id,
  sourceNodeId: source.id,
  targetNodeId: target.id,
  type: EdgeType.mentionedWith,
  isDirected: false,
  weight: 0.7,
);
