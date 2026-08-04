import 'dart:isolate';

import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../services/life_os_graph_builder.dart';
import '../engines/memory_timeline_engine.dart';
import '../graph/personal_knowledge_graph.dart';

typedef PostSaveLifeOsAnalysisRunner =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);

class LifeOsEvidenceCitation {
  LifeOsEvidenceCitation({required this.entryId, required DateTime observedAt})
    : observedAt = observedAt.toUtc();

  final String entryId;
  final DateTime observedAt;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'observedAt': observedAt.toIso8601String(),
  };

  factory LifeOsEvidenceCitation.fromJson(Map<String, dynamic> json) =>
      LifeOsEvidenceCitation(
        entryId: json['entryId'] as String? ?? '',
        observedAt:
            DateTime.tryParse(json['observedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

class EntityFrequencyInsight {
  EntityFrequencyInsight({
    required this.nodeId,
    required this.entityLabel,
    required this.entityType,
    required this.isNewlyDetected,
    required this.currentMonthCount,
    required Iterable<LifeOsEvidenceCitation> citations,
  }) : citations = List.unmodifiable(citations);

  final String nodeId;
  final String entityLabel;
  final String entityType;
  final bool isNewlyDetected;
  final int currentMonthCount;
  final List<LifeOsEvidenceCitation> citations;

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'entityLabel': entityLabel,
    'entityType': entityType,
    'isNewlyDetected': isNewlyDetected,
    'currentMonthCount': currentMonthCount,
    'citations': citations.map((item) => item.toJson()).toList(),
  };

  factory EntityFrequencyInsight.fromJson(Map<String, dynamic> json) =>
      EntityFrequencyInsight(
        nodeId: json['nodeId'] as String? ?? '',
        entityLabel: json['entityLabel'] as String? ?? '',
        entityType: json['entityType'] as String? ?? '',
        isNewlyDetected: json['isNewlyDetected'] == true,
        currentMonthCount: (json['currentMonthCount'] as num?)?.toInt() ?? 0,
        citations: _jsonMaps(
          json['citations'],
        ).map(LifeOsEvidenceCitation.fromJson),
      );
}

class RelatedMemoryInsight {
  RelatedMemoryInsight({
    required this.nodeId,
    required this.entityLabel,
    required this.entityType,
    required this.currentEntryCitation,
    required this.relatedEntryCitation,
  });

  final String nodeId;
  final String entityLabel;
  final String entityType;
  final LifeOsEvidenceCitation currentEntryCitation;
  final LifeOsEvidenceCitation relatedEntryCitation;

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'entityLabel': entityLabel,
    'entityType': entityType,
    'currentEntryCitation': currentEntryCitation.toJson(),
    'relatedEntryCitation': relatedEntryCitation.toJson(),
  };

  factory RelatedMemoryInsight.fromJson(Map<String, dynamic> json) =>
      RelatedMemoryInsight(
        nodeId: json['nodeId'] as String? ?? '',
        entityLabel: json['entityLabel'] as String? ?? '',
        entityType: json['entityType'] as String? ?? '',
        currentEntryCitation: LifeOsEvidenceCitation.fromJson(
          _jsonMap(json['currentEntryCitation']),
        ),
        relatedEntryCitation: LifeOsEvidenceCitation.fromJson(
          _jsonMap(json['relatedEntryCitation']),
        ),
      );
}

class PostSaveLifeOsInsights {
  PostSaveLifeOsInsights({
    required this.finalizedEntryId,
    Iterable<EntityFrequencyInsight> entityFrequencies = const [],
    Iterable<RelatedMemoryInsight> relatedMemories = const [],
    this.isAiDerived = false,
  }) : entityFrequencies = List.unmodifiable(entityFrequencies),
       relatedMemories = List.unmodifiable(relatedMemories);

  final String finalizedEntryId;
  final List<EntityFrequencyInsight> entityFrequencies;
  final List<RelatedMemoryInsight> relatedMemories;
  final bool isAiDerived;

  bool get isEmpty =>
      isAiDerived || (entityFrequencies.isEmpty && relatedMemories.isEmpty);

  Map<String, dynamic> toJson() => {
    'finalizedEntryId': finalizedEntryId,
    'entityFrequencies': entityFrequencies
        .map((item) => item.toJson())
        .toList(),
    'relatedMemories': relatedMemories.map((item) => item.toJson()).toList(),
    'isAiDerived': isAiDerived,
  };

  factory PostSaveLifeOsInsights.fromJson(Map<String, dynamic> json) =>
      PostSaveLifeOsInsights(
        finalizedEntryId: json['finalizedEntryId'] as String? ?? '',
        entityFrequencies: _jsonMaps(
          json['entityFrequencies'],
        ).map(EntityFrequencyInsight.fromJson),
        relatedMemories: _jsonMaps(
          json['relatedMemories'],
        ).map(RelatedMemoryInsight.fromJson),
        isAiDerived: json['isAiDerived'] == true,
      );
}

class PostSaveLifeOsInsightsService {
  PostSaveLifeOsInsightsService({
    PostSaveLifeOsAnalysisRunner? runner,
    AsyncLifeOsGraphBuilder? graphBuilder,
  }) : _runner = runner ?? _runInBackgroundIsolate,
       _graphBuilder =
           graphBuilder ??
           (runner == null && AppServices.isInitialized
               ? buildProductionLifeOsGraph
               : null);

  final PostSaveLifeOsAnalysisRunner _runner;
  final AsyncLifeOsGraphBuilder? _graphBuilder;

  Future<PostSaveLifeOsInsights> analyze({
    required List<JournalEntry> entries,
    required String finalizedEntryId,
  }) async {
    final request = <String, dynamic>{
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'finalizedEntryId': finalizedEntryId,
    };
    final graphBuilder = _graphBuilder;
    final finalized = entries
        .where((entry) => entry.id == finalizedEntryId)
        .firstOrNull;
    if (graphBuilder != null && finalized != null) {
      final finalizedAt = finalized.createdAt.toUtc();
      final throughFinalization = entries
          .where(
            (entry) =>
                entry.id == finalizedEntryId ||
                !entry.createdAt.toUtc().isAfter(finalizedAt),
          )
          .toList();
      final graphs = await Future.wait([
        graphBuilder(
          throughFinalization.where((entry) => entry.id != finalizedEntryId),
        ),
        graphBuilder(throughFinalization),
      ]);
      request['graphBefore'] = graphs[0].toJson();
      request['graphAfter'] = graphs[1].toJson();
    }
    final response = await _runner(request);
    final result = PostSaveLifeOsInsights.fromJson(response);
    if (graphBuilder != null) {
      // Native semantic output currently lacks exact quote offsets and a
      // meaningful alternative, so it must not reach a user-visible surface.
      return PostSaveLifeOsInsights(
        finalizedEntryId: result.finalizedEntryId,
        isAiDerived: true,
      );
    }
    return result;
  }

  static Future<Map<String, dynamic>> _runInBackgroundIsolate(
    Map<String, dynamic> request,
  ) => Isolate.run(() => postSaveLifeOsInsightsWorker(request));
}

Map<String, dynamic> postSaveLifeOsInsightsWorker(
  Map<String, dynamic> request,
) {
  final finalizedEntryId = request['finalizedEntryId'] as String? ?? '';
  final entries = _jsonMaps(
    request['entries'],
  ).map(JournalEntry.fromJson).toList();
  final finalized = entries
      .where((entry) => entry.id == finalizedEntryId)
      .firstOrNull;
  if (finalized == null || finalizedEntryId.isEmpty) {
    return PostSaveLifeOsInsights(finalizedEntryId: finalizedEntryId).toJson();
  }

  final finalizedAt = finalized.createdAt.toUtc();
  final entriesThroughFinalization = entries
      .where(
        (entry) =>
            entry.id == finalizedEntryId ||
            !entry.createdAt.toUtc().isAfter(finalizedAt),
      )
      .toList();
  final suppliedBefore = request['graphBefore'];
  final suppliedAfter = request['graphAfter'];
  final graphEngine = PersonalKnowledgeGraphEngine();
  final graphBefore = suppliedBefore is Map
      ? PersonalKnowledgeGraph.fromJson(
          Map<String, dynamic>.from(suppliedBefore),
        )
      : graphEngine.rebuild(
          entriesThroughFinalization.where(
            (entry) => entry.id != finalizedEntryId,
          ),
        );
  final graphAfter = suppliedAfter is Map
      ? PersonalKnowledgeGraph.fromJson(
          Map<String, dynamic>.from(suppliedAfter),
        )
      : graphEngine.rebuild(entriesThroughFinalization);
  final beforeNodeIds = graphBefore.nodes.map((node) => node.id).toSet();
  final currentNodes =
      graphAfter.nodes
          .where(
            (node) => node.evidence.any(
              (evidence) => evidence.entryId == finalizedEntryId,
            ),
          )
          .toList()
        ..sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );

  if (currentNodes.isEmpty) {
    return PostSaveLifeOsInsights(finalizedEntryId: finalizedEntryId).toJson();
  }

  final monthStart = DateTime.utc(
    finalized.createdAt.toUtc().year,
    finalized.createdAt.toUtc().month,
  );
  final monthEnd = DateTime.utc(monthStart.year, monthStart.month + 1);
  final timeline = MemoryTimelineEngine(graphAfter);
  final frequencies = <EntityFrequencyInsight>[];
  final related = <RelatedMemoryInsight>[];

  for (final node in currentNodes) {
    final frequency = timeline.getMentionFrequency(
      node.label,
      since: monthStart,
    );
    final monthEvidence = frequency.evidence
        .where(
          (evidence) =>
              evidence.observedAt.isBefore(monthEnd) &&
              !evidence.observedAt.isAfter(finalizedAt),
        )
        .toList();
    frequencies.add(
      EntityFrequencyInsight(
        nodeId: node.id,
        entityLabel: node.label,
        entityType: node.type.name,
        isNewlyDetected: !beforeNodeIds.contains(node.id),
        currentMonthCount: monthEvidence.length,
        citations: monthEvidence.map(
          (evidence) => LifeOsEvidenceCitation(
            entryId: evidence.entryId,
            observedAt: evidence.observedAt,
          ),
        ),
      ),
    );

    final currentEvidence = node.evidence
        .where((evidence) => evidence.entryId == finalizedEntryId)
        .firstOrNull;
    final priorEvidence =
        (node.evidence
                .where(
                  (evidence) =>
                      evidence.entryId != finalizedEntryId &&
                      evidence.observedAt.isBefore(finalizedAt),
                )
                .toList()
              ..sort((a, b) {
                final byTime = b.observedAt.compareTo(a.observedAt);
                return byTime != 0 ? byTime : b.entryId.compareTo(a.entryId);
              }))
            .firstOrNull;
    if (currentEvidence != null && priorEvidence != null) {
      related.add(
        RelatedMemoryInsight(
          nodeId: node.id,
          entityLabel: node.label,
          entityType: node.type.name,
          currentEntryCitation: LifeOsEvidenceCitation(
            entryId: currentEvidence.entryId,
            observedAt: currentEvidence.observedAt,
          ),
          relatedEntryCitation: LifeOsEvidenceCitation(
            entryId: priorEvidence.entryId,
            observedAt: priorEvidence.observedAt,
          ),
        ),
      );
    }
  }

  return PostSaveLifeOsInsights(
    finalizedEntryId: finalizedEntryId,
    entityFrequencies: frequencies,
    relatedMemories: related,
  ).toJson();
}

Map<String, dynamic> _jsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

Iterable<Map<String, dynamic>> _jsonMaps(Object? value) =>
    (value as List? ?? const []).whereType<Map>().map(
      (item) => Map<String, dynamic>.from(item),
    );
