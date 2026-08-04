import 'dart:collection';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';

enum TimelineBranchStatus { active, archived, converged }

enum HorizonProjection { oneYear, threeYears, fiveYears }

final class HorizonRiskVector {
  HorizonRiskVector({
    required num financial,
    required num emotional,
    required num career,
    required num cognitiveLoad,
    required num alignment,
    required num reward,
  }) : financial = _unit(financial),
       emotional = _unit(emotional),
       career = _unit(career),
       cognitiveLoad = _unit(cognitiveLoad),
       alignment = _unit(alignment),
       reward = _unit(reward);

  final double financial;
  final double emotional;
  final double career;
  final double cognitiveLoad;
  final double alignment;
  final double reward;

  double get aggregateRisk => (financial + emotional + career) / 3;

  Map<String, dynamic> toJson() => {
    'financial': financial,
    'emotional': emotional,
    'career': career,
    'cognitiveLoad': cognitiveLoad,
    'alignment': alignment,
    'reward': reward,
  };

  factory HorizonRiskVector.fromJson(Map<String, dynamic> json) =>
      HorizonRiskVector(
        financial: json['financial'] as num? ?? 0,
        emotional: json['emotional'] as num? ?? 0,
        career: json['career'] as num? ?? 0,
        cognitiveLoad: json['cognitiveLoad'] as num? ?? 0,
        alignment: json['alignment'] as num? ?? 0,
        reward: json['reward'] as num? ?? 0,
      );
}

final class HorizonProjectedNode {
  HorizonProjectedNode({
    required this.id,
    required this.horizon,
    required String label,
    required num probability,
    required this.type,
    required this.risks,
    Iterable<String> rippleTargetIds = const [],
  }) : label = label.trim(),
       probability = _unit(probability),
       rippleTargetIds = UnmodifiableListView(
         rippleTargetIds.where((value) => value.trim().isNotEmpty).toSet(),
       ) {
    if (id.trim().isEmpty || this.label.isEmpty) {
      throw ArgumentError('Projected nodes require an id and label.');
    }
  }

  final String id;
  final HorizonProjection horizon;
  final String label;
  final double probability;
  final NodeType type;
  final HorizonRiskVector risks;
  final List<String> rippleTargetIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'horizon': horizon.name,
    'label': label,
    'probability': probability,
    'type': type.name,
    'risks': risks.toJson(),
    'rippleTargetIds': rippleTargetIds,
  };

  factory HorizonProjectedNode.fromJson(Map<String, dynamic> json) =>
      HorizonProjectedNode(
        id: json['id'] as String,
        horizon: HorizonProjection.values.byName(json['horizon'] as String),
        label: json['label'] as String,
        probability: json['probability'] as num,
        type: NodeType.values.byName(json['type'] as String),
        risks: HorizonRiskVector.fromJson(
          Map<String, dynamic>.from(json['risks'] as Map),
        ),
        rippleTargetIds: (json['rippleTargetIds'] as List? ?? const [])
            .whereType<String>(),
      );
}

final class TimelineBranch {
  TimelineBranch({
    required this.id,
    required String name,
    required this.parentBranchId,
    required this.divergenceNodeId,
    required this.status,
    required this.overlay,
    required Iterable<String> forkedNodeIds,
    required Iterable<String> forkedEdgeIds,
    Iterable<HorizonProjectedNode> projections = const [],
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = name.trim(),
       forkedNodeIds = Set.unmodifiable(forkedNodeIds),
       forkedEdgeIds = Set.unmodifiable(forkedEdgeIds),
       projections = UnmodifiableListView(projections),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    if (id.trim().isEmpty ||
        this.name.isEmpty ||
        divergenceNodeId.trim().isEmpty ||
        !this.forkedNodeIds.contains(divergenceNodeId)) {
      throw ArgumentError('Invalid timeline branch.');
    }
  }

  final String id;
  final String name;
  final String? parentBranchId;
  final String divergenceNodeId;
  final TimelineBranchStatus status;
  final PersonalKnowledgeGraph overlay;
  final Set<String> forkedNodeIds;
  final Set<String> forkedEdgeIds;
  final List<HorizonProjectedNode> projections;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimelineBranch copyWith({
    TimelineBranchStatus? status,
    PersonalKnowledgeGraph? overlay,
    Iterable<HorizonProjectedNode>? projections,
    DateTime? updatedAt,
  }) => TimelineBranch(
    id: id,
    name: name,
    parentBranchId: parentBranchId,
    divergenceNodeId: divergenceNodeId,
    status: status ?? this.status,
    overlay: overlay ?? this.overlay,
    forkedNodeIds: forkedNodeIds,
    forkedEdgeIds: forkedEdgeIds,
    projections: projections ?? this.projections,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentBranchId': parentBranchId,
    'divergenceNodeId': divergenceNodeId,
    'status': status.name,
    'overlay': overlay.toJson(),
    'forkedNodeIds': forkedNodeIds.toList()..sort(),
    'forkedEdgeIds': forkedEdgeIds.toList()..sort(),
    'projections': projections.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TimelineBranch.fromJson(Map<String, dynamic> json) => TimelineBranch(
    id: json['id'] as String,
    name: json['name'] as String,
    parentBranchId: json['parentBranchId'] as String?,
    divergenceNodeId: json['divergenceNodeId'] as String,
    status: TimelineBranchStatus.values.byName(json['status'] as String),
    overlay: PersonalKnowledgeGraph.fromJson(
      Map<String, dynamic>.from(json['overlay'] as Map),
    ),
    forkedNodeIds: (json['forkedNodeIds'] as List? ?? const [])
        .whereType<String>(),
    forkedEdgeIds: (json['forkedEdgeIds'] as List? ?? const [])
        .whereType<String>(),
    projections: (json['projections'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              HorizonProjectedNode.fromJson(Map<String, dynamic>.from(item)),
        ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

double _unit(num value) => value.toDouble().clamp(0, 1);
