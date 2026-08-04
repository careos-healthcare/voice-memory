import 'dart:collection';

enum SemanticClusterCategory {
  theme,
  project,
  peopleNetwork,
  habitCluster,
  belief;

  String get wireName => switch (this) {
    SemanticClusterCategory.peopleNetwork => 'people_network',
    SemanticClusterCategory.habitCluster => 'habit_cluster',
    _ => name,
  };

  static SemanticClusterCategory parse(Object? value) => switch (value) {
    'project' => SemanticClusterCategory.project,
    'people_network' ||
    'peopleNetwork' => SemanticClusterCategory.peopleNetwork,
    'habit_cluster' || 'habitCluster' => SemanticClusterCategory.habitCluster,
    'belief' => SemanticClusterCategory.belief,
    'theme' || null => SemanticClusterCategory.theme,
    _ => throw FormatException('Unknown semantic cluster category: $value'),
  };
}

final class SemanticCluster {
  SemanticCluster({
    required String id,
    required String title,
    required this.category,
    required Iterable<String> nodeIds,
    required num activityVelocity,
    required num confidenceScore,
    this.summary = '',
    this.pinned = false,
    DateTime? updatedAt,
    this.userEdited = false,
  }) : id = _requiredText(id, 'id'),
       title = _requiredText(title, 'title'),
       nodeIds = UnmodifiableListView(
         (nodeIds.map((id) => _requiredText(id, 'nodeIds')).toSet().toList()
           ..sort()),
       ),
       activityVelocity = _score(activityVelocity, 'activityVelocity'),
       confidenceScore = _score(confidenceScore, 'confidenceScore'),
       updatedAt =
           (updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
               .toUtc();

  final String id;
  final String title;
  final SemanticClusterCategory category;
  final List<String> nodeIds;
  final double activityVelocity;
  final double confidenceScore;
  final String summary;
  final bool pinned;
  final DateTime updatedAt;
  final bool userEdited;

  SemanticCluster copyWith({
    String? id,
    String? title,
    SemanticClusterCategory? category,
    Iterable<String>? nodeIds,
    num? activityVelocity,
    num? confidenceScore,
    String? summary,
    bool? pinned,
    DateTime? updatedAt,
    bool? userEdited,
  }) => SemanticCluster(
    id: id ?? this.id,
    title: title ?? this.title,
    category: category ?? this.category,
    nodeIds: nodeIds ?? this.nodeIds,
    activityVelocity: activityVelocity ?? this.activityVelocity,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    summary: summary ?? this.summary,
    pinned: pinned ?? this.pinned,
    updatedAt: updatedAt ?? this.updatedAt,
    userEdited: userEdited ?? this.userEdited,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.wireName,
    'nodeIds': nodeIds,
    'activityVelocity': activityVelocity,
    'confidenceScore': confidenceScore,
    'summary': summary,
    'pinned': pinned,
    'updatedAt': updatedAt.toIso8601String(),
    'userEdited': userEdited,
  };

  Map<String, Object> toPortableJson() => Map<String, Object>.unmodifiable({
    for (final entry in toJson().entries) entry.key: entry.value as Object,
  });

  factory SemanticCluster.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final rawNodeIds = json['nodeIds'] ?? json['node_ids'];
    if (id is! String || title is! String || rawNodeIds is! List) {
      throw const FormatException('Invalid semantic cluster identity.');
    }
    final nodeIds = <String>[];
    for (final value in rawNodeIds) {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid semantic cluster node ID.');
      }
      nodeIds.add(value);
    }
    final velocity = json['activityVelocity'] ?? json['activity_velocity'] ?? 0;
    final confidence = json['confidenceScore'] ?? json['confidence_score'] ?? 0;
    if (velocity is! num || confidence is! num) {
      throw const FormatException('Invalid semantic cluster scores.');
    }
    final pinned = json['pinned'] ?? false;
    final userEdited = json['userEdited'] ?? json['user_edited'] ?? false;
    if (pinned is! bool || userEdited is! bool) {
      throw const FormatException('Invalid semantic cluster edit metadata.');
    }
    final rawUpdatedAt = json['updatedAt'] ?? json['updated_at'];
    final updatedAt = rawUpdatedAt == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.tryParse(rawUpdatedAt.toString());
    if (updatedAt == null) {
      throw const FormatException('Invalid semantic cluster timestamp.');
    }
    final summary = json['summary'] ?? '';
    if (summary is! String) {
      throw const FormatException('Invalid semantic cluster summary.');
    }
    return SemanticCluster(
      id: id,
      title: title,
      category: SemanticClusterCategory.parse(json['category']),
      nodeIds: nodeIds,
      activityVelocity: velocity,
      confidenceScore: confidence,
      summary: summary,
      pinned: pinned,
      updatedAt: updatedAt,
      userEdited: userEdited,
    );
  }

  static String _requiredText(String value, String field) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return trimmed;
  }

  static double _score(num value, String field) {
    final result = value.toDouble();
    if (!result.isFinite || result < 0 || result > 1) {
      throw ArgumentError.value(
        value,
        field,
        'must be finite and between 0 and 1',
      );
    }
    return result;
  }
}
