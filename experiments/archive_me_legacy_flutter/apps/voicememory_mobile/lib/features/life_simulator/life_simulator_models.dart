import '../../core/graph/graph_node.dart';
import '../ai_engines/models/ai_explainability.dart';

enum SimulationTargetKind {
  graphNode,
  semanticCluster,
  habit;

  String get wireName => switch (this) {
    SimulationTargetKind.graphNode => 'graph_node',
    SimulationTargetKind.semanticCluster => 'semantic_cluster',
    SimulationTargetKind.habit => 'habit',
  };

  static SimulationTargetKind parse(Object? value) => switch (value) {
    'graph_node' || 'graphNode' || 'node' => SimulationTargetKind.graphNode,
    'semantic_cluster' ||
    'semanticCluster' ||
    'cluster' => SimulationTargetKind.semanticCluster,
    'habit' => SimulationTargetKind.habit,
    _ => throw FormatException('Unknown simulation target kind: $value'),
  };
}

typedef SimulationTargetType = SimulationTargetKind;

/// A lightweight graph reference. The referenced node or cluster is resolved
/// by [LifeSimulatorEngine], so private graph objects are never persisted here.
final class SimulationTarget {
  SimulationTarget({
    required this.kind,
    required String referenceId,
    String? displayLabel,
  }) : referenceId = _requiredText(referenceId, 'referenceId'),
       displayLabel = _optionalText(displayLabel);

  factory SimulationTarget.graphNode(String nodeId, {String? displayLabel}) =>
      SimulationTarget(
        kind: SimulationTargetKind.graphNode,
        referenceId: nodeId,
        displayLabel: displayLabel,
      );

  factory SimulationTarget.semanticCluster(
    String clusterId, {
    String? displayLabel,
  }) => SimulationTarget(
    kind: SimulationTargetKind.semanticCluster,
    referenceId: clusterId,
    displayLabel: displayLabel,
  );

  factory SimulationTarget.habit(String nodeId, {String? displayLabel}) =>
      SimulationTarget(
        kind: SimulationTargetKind.habit,
        referenceId: nodeId,
        displayLabel: displayLabel,
      );

  final SimulationTargetKind kind;
  final String referenceId;
  final String? displayLabel;

  SimulationTargetKind get type => kind;
  String get id => referenceId;
  String get targetId => referenceId;
  String? get label => displayLabel;

  Map<String, dynamic> toJson() => {
    'kind': kind.wireName,
    'referenceId': referenceId,
    if (displayLabel != null) 'displayLabel': displayLabel,
  };

  factory SimulationTarget.fromJson(Map<String, dynamic> json) {
    final id = json['referenceId'] ?? json['reference_id'] ?? json['targetId'];
    final label =
        json['displayLabel'] ?? json['display_label'] ?? json['label'];
    if (id is! String || label != null && label is! String) {
      throw const FormatException('Invalid simulation target.');
    }
    return SimulationTarget(
      kind: SimulationTargetKind.parse(json['kind'] ?? json['type']),
      referenceId: id,
      displayLabel: label as String?,
    );
  }
}

enum SimulationPath {
  continueTrajectory,
  stopTrajectory,
  pivotTrajectory;

  String get wireName => switch (this) {
    SimulationPath.continueTrajectory => 'continue_trajectory',
    SimulationPath.stopTrajectory => 'stop_trajectory',
    SimulationPath.pivotTrajectory => 'pivot_trajectory',
  };

  static SimulationPath parse(Object? value) => switch (value) {
    'continue_trajectory' ||
    'continueTrajectory' ||
    'continue' => SimulationPath.continueTrajectory,
    'stop_trajectory' ||
    'stopTrajectory' ||
    'stop' => SimulationPath.stopTrajectory,
    'pivot_trajectory' ||
    'pivotTrajectory' ||
    'pivot' => SimulationPath.pivotTrajectory,
    _ => throw FormatException('Unknown simulation path: $value'),
  };
}

final class ProjectedMilestone {
  ProjectedMilestone({
    required this.days,
    required num projectedConfidence,
    required num stressImpactScore,
    num? healthCorrelation,
    required String narrativeSummary,
    Iterable<String> affectedNodeIds = const [],
    Iterable<String> affectedEdgeIds = const [],
    Iterable<String> localCitationHandles = const [],
    Iterable<VerifiableCitation> citations = const [],
    Map<String, num> projectedNodeScores = const {},
    Map<String, num> projectedEdgeWeights = const {},
    Map<String, num> externalCorrelations = const {},
  }) : projectedConfidence = _bounded(
         projectedConfidence,
         0,
         1,
         'projectedConfidence',
       ),
       stressImpactScore = _bounded(
         stressImpactScore,
         -1,
         1,
         'stressImpactScore',
       ),
       healthCorrelation = healthCorrelation == null
           ? null
           : _bounded(healthCorrelation, -1, 1, 'healthCorrelation'),
       narrativeSummary = _requiredText(narrativeSummary, 'narrativeSummary'),
       affectedNodeIds = _immutableIds(affectedNodeIds, 'affectedNodeIds'),
       affectedEdgeIds = _immutableIds(affectedEdgeIds, 'affectedEdgeIds'),
       localCitationHandles = _immutableIds(
         localCitationHandles,
         'localCitationHandles',
       ),
       citations = List.unmodifiable(citations),
       projectedNodeScores = _boundedMap(
         projectedNodeScores,
         0,
         1,
         'projectedNodeScores',
       ),
       projectedEdgeWeights = _boundedMap(
         projectedEdgeWeights,
         0,
         1,
         'projectedEdgeWeights',
       ),
       externalCorrelations = _boundedMap(
         externalCorrelations,
         -1,
         1,
         'externalCorrelations',
       ) {
    if (days != 30 && days != 90 && days != 365) {
      throw ArgumentError.value(days, 'days', 'must be 30, 90, or 365');
    }
  }

  final int days;
  final double projectedConfidence;
  final double stressImpactScore;
  final double? healthCorrelation;
  final String narrativeSummary;
  final List<String> affectedNodeIds;
  final List<String> affectedEdgeIds;
  final List<String> localCitationHandles;
  final List<VerifiableCitation> citations;
  final Map<String, double> projectedNodeScores;
  final Map<String, double> projectedEdgeWeights;
  final Map<String, double> externalCorrelations;

  int get horizonDays => days;
  List<String> get citationHandles => localCitationHandles;

  Map<String, dynamic> toJson() => {
    'days': days,
    'projectedConfidence': projectedConfidence,
    'stressImpactScore': stressImpactScore,
    'healthCorrelation': healthCorrelation,
    'narrativeSummary': narrativeSummary,
    'affectedNodeIds': affectedNodeIds,
    'affectedEdgeIds': affectedEdgeIds,
    'localCitationHandles': localCitationHandles,
    if (citations.isNotEmpty)
      'citations': citations.map((citation) => citation.toJson()).toList(),
    'projectedNodeScores': projectedNodeScores,
    'projectedEdgeWeights': projectedEdgeWeights,
    'externalCorrelations': externalCorrelations,
  };

  factory ProjectedMilestone.fromJson(Map<String, dynamic> json) {
    final days = json['days'] ?? json['horizonDays'] ?? json['horizon_days'];
    final confidence =
        json['projectedConfidence'] ?? json['projected_confidence'];
    final stress = json['stressImpactScore'] ?? json['stress_impact_score'];
    final health = json['healthCorrelation'] ?? json['health_correlation'];
    final narrative = json['narrativeSummary'] ?? json['narrative_summary'];
    if (days is! num ||
        days.toInt() != days ||
        confidence is! num ||
        stress is! num ||
        health != null && health is! num ||
        narrative is! String) {
      throw const FormatException('Invalid projected milestone.');
    }
    return ProjectedMilestone(
      days: days.toInt(),
      projectedConfidence: confidence,
      stressImpactScore: stress,
      healthCorrelation: health as num?,
      narrativeSummary: narrative,
      affectedNodeIds: _parseStringList(
        json['affectedNodeIds'] ?? json['affected_node_ids'],
        'affectedNodeIds',
      ),
      affectedEdgeIds: _parseStringList(
        json['affectedEdgeIds'] ?? json['affected_edge_ids'],
        'affectedEdgeIds',
      ),
      localCitationHandles: _parseStringList(
        json['localCitationHandles'] ??
            json['local_citation_handles'] ??
            json['citationHandles'],
        'localCitationHandles',
      ),
      citations: _parseCitations(json['citations']),
      projectedNodeScores: _parseNumberMap(
        json['projectedNodeScores'] ?? json['projected_node_scores'],
        'projectedNodeScores',
      ),
      projectedEdgeWeights: _parseNumberMap(
        json['projectedEdgeWeights'] ?? json['projected_edge_weights'],
        'projectedEdgeWeights',
      ),
      externalCorrelations: _parseNumberMap(
        json['externalCorrelations'] ?? json['external_correlations'],
        'externalCorrelations',
      ),
    );
  }
}

final class SimulationTrajectory {
  SimulationTrajectory({
    String? id,
    required this.target,
    required this.path,
    required Iterable<ProjectedMilestone> milestones,
    DateTime? generatedAt,
  }) : milestones = _validatedMilestones(milestones),
       generatedAt =
           (generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
               .toUtc(),
       id =
           id ??
           stableGraphId('simulation-trajectory', [
             target.kind.wireName,
             target.referenceId,
             path.wireName,
           ]);

  final String id;
  final SimulationTarget target;
  final SimulationPath path;
  final List<ProjectedMilestone> milestones;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'target': target.toJson(),
    'path': path.wireName,
    'milestones': milestones.map((item) => item.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory SimulationTrajectory.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final target = json['target'];
    final rawMilestones = json['milestones'];
    final rawGeneratedAt = json['generatedAt'] ?? json['generated_at'];
    if (id != null && id is! String ||
        target is! Map ||
        rawMilestones is! List ||
        rawGeneratedAt != null && rawGeneratedAt is! String) {
      throw const FormatException('Invalid simulation trajectory.');
    }
    final generatedAt = rawGeneratedAt == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.tryParse(rawGeneratedAt);
    if (generatedAt == null) {
      throw const FormatException('Invalid trajectory timestamp.');
    }
    return SimulationTrajectory(
      id: id == null ? null : _requiredText(id, 'id'),
      target: SimulationTarget.fromJson(Map<String, dynamic>.from(target)),
      path: SimulationPath.parse(json['path']),
      milestones: rawMilestones.map((value) {
        if (value is! Map) {
          throw const FormatException('Invalid trajectory milestone.');
        }
        return ProjectedMilestone.fromJson(Map<String, dynamic>.from(value));
      }),
      generatedAt: generatedAt,
    );
  }
}

final class CounterfactualScenario {
  CounterfactualScenario({
    String? id,
    required this.continueTrajectory,
    required this.alternativeTrajectory,
  }) : id =
           id ??
           stableGraphId('counterfactual-scenario', [
             continueTrajectory.target.kind.wireName,
             continueTrajectory.target.referenceId,
             alternativeTrajectory.path.wireName,
           ]) {
    if (continueTrajectory.path != SimulationPath.continueTrajectory) {
      throw ArgumentError.value(
        continueTrajectory.path,
        'continueTrajectory',
        'must use continueTrajectory',
      );
    }
    if (alternativeTrajectory.path == SimulationPath.continueTrajectory) {
      throw ArgumentError.value(
        alternativeTrajectory.path,
        'alternativeTrajectory',
        'must use stopTrajectory or pivotTrajectory',
      );
    }
    if (continueTrajectory.target.kind != alternativeTrajectory.target.kind ||
        continueTrajectory.target.referenceId !=
            alternativeTrajectory.target.referenceId) {
      throw const FormatException(
        'Counterfactual trajectories must reference the same target.',
      );
    }
  }

  final String id;
  final SimulationTrajectory continueTrajectory;
  final SimulationTrajectory alternativeTrajectory;

  SimulationTrajectory? get stopTrajectory =>
      alternativeTrajectory.path == SimulationPath.stopTrajectory
      ? alternativeTrajectory
      : null;
  SimulationTrajectory? get pivotTrajectory =>
      alternativeTrajectory.path == SimulationPath.pivotTrajectory
      ? alternativeTrajectory
      : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'continueTrajectory': continueTrajectory.toJson(),
    'alternativeTrajectory': alternativeTrajectory.toJson(),
  };

  factory CounterfactualScenario.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final continuing =
        json['continueTrajectory'] ?? json['continue_trajectory'];
    final alternative =
        json['alternativeTrajectory'] ??
        json['alternative_trajectory'] ??
        json['stopTrajectory'] ??
        json['pivotTrajectory'];
    if (id != null && id is! String ||
        continuing is! Map ||
        alternative is! Map) {
      throw const FormatException('Invalid counterfactual scenario.');
    }
    return CounterfactualScenario(
      id: id == null ? null : _requiredText(id, 'id'),
      continueTrajectory: SimulationTrajectory.fromJson(
        Map<String, dynamic>.from(continuing),
      ),
      alternativeTrajectory: SimulationTrajectory.fromJson(
        Map<String, dynamic>.from(alternative),
      ),
    );
  }
}

String _requiredText(String value, String field) {
  final result = value.trim();
  if (result.isEmpty) {
    throw ArgumentError.value(value, field, 'must not be empty');
  }
  return result;
}

String? _optionalText(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}

double _bounded(num value, double minimum, double maximum, String field) {
  final result = value.toDouble();
  if (!result.isFinite || result < minimum || result > maximum) {
    throw ArgumentError.value(
      value,
      field,
      'must be finite and between $minimum and $maximum',
    );
  }
  return result;
}

List<String> _immutableIds(Iterable<String> values, String field) {
  final result = <String>{};
  for (final value in values) {
    result.add(_requiredText(value, field));
  }
  final sorted = result.toList()..sort();
  return List.unmodifiable(sorted);
}

Map<String, double> _boundedMap(
  Map<String, num> values,
  double minimum,
  double maximum,
  String field,
) {
  final result = <String, double>{};
  for (final entry in values.entries) {
    result[_requiredText(entry.key, field)] = _bounded(
      entry.value,
      minimum,
      maximum,
      field,
    );
  }
  return Map.unmodifiable(result);
}

List<String> _parseStringList(Object? value, String field) {
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Invalid $field.');
  }
  return value.cast<String>();
}

Map<String, num> _parseNumberMap(Object? value, String field) {
  if (value == null) return const {};
  if (value is! Map) throw FormatException('Invalid $field.');
  final result = <String, num>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! num) {
      throw FormatException('Invalid $field.');
    }
    result[entry.key as String] = entry.value as num;
  }
  return result;
}

List<VerifiableCitation> _parseCitations(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('Invalid citations.');
  final result = <VerifiableCitation>[];
  for (final item in value) {
    final citation = VerifiableCitation.fromJson(item);
    if (citation == null) throw const FormatException('Invalid citations.');
    result.add(citation);
  }
  return result;
}

List<ProjectedMilestone> _validatedMilestones(
  Iterable<ProjectedMilestone> values,
) {
  final result = values.toList()..sort((a, b) => a.days.compareTo(b.days));
  if (result.length != 3 ||
      result[0].days != 30 ||
      result[1].days != 90 ||
      result[2].days != 365) {
    throw const FormatException(
      'A trajectory requires 30, 90, and 365 day milestones.',
    );
  }
  return List.unmodifiable(result);
}
