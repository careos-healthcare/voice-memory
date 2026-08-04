import '../../features/media/media_attachment.dart';

enum NodeType {
  person,
  place,
  event,
  goal,
  fear,
  habit,
  belief,
  memory,
  chapter,
  project,
  emotion,
  interaction,
  decision,
  outcome,
  journalEntry,
  identityShift,
  archiveInsight,
  actionItem,
  promise,
  topic,
  object,
  text,
}

enum NodeOrigin {
  extracted,
  manual,
  systemSeed,
  external,
  media,
  document,
  horizon,
  autonomousMuse;

  String get wireName => switch (this) {
    NodeOrigin.extracted => 'extracted',
    NodeOrigin.manual => 'manual',
    NodeOrigin.systemSeed => 'system_seed',
    NodeOrigin.external => 'external',
    NodeOrigin.media => 'media',
    NodeOrigin.document => 'document',
    NodeOrigin.horizon => 'horizon',
    NodeOrigin.autonomousMuse => 'autonomous_muse',
  };

  static NodeOrigin fromWireName(String? value) => switch (value) {
    'manual' => NodeOrigin.manual,
    'system_seed' => NodeOrigin.systemSeed,
    'external' => NodeOrigin.external,
    'media' => NodeOrigin.media,
    'document' => NodeOrigin.document,
    'horizon' => NodeOrigin.horizon,
    'autonomous_muse' => NodeOrigin.autonomousMuse,
    _ => NodeOrigin.extracted,
  };
}

enum ExternalSource {
  appleHealth,
  spotify;

  String get wireName => switch (this) {
    ExternalSource.appleHealth => 'apple_health',
    ExternalSource.spotify => 'spotify',
  };

  static ExternalSource? fromWireName(String? value) => switch (value) {
    'apple_health' => ExternalSource.appleHealth,
    'spotify' => ExternalSource.spotify,
    _ => null,
  };
}

enum EdgeType {
  triggeredBy,
  associatedWith,
  evolvedInto,
  mentionedWith,
  influences,
  decidedOn,
  resultedIn,
  feltAbout,
  partOf,
  supportsBelief,
  contradictsBelief,
  recordedIn,
  chapterContains,
  shiftFrom,
  shiftTo,
  concludesAbout,
  interactedWith,
  evokedEmotion,
}

double clampGraphScore(num value) => value.toDouble().clamp(0.0, 1.0);
double clampGraphValence(num value) => value.toDouble().clamp(-1.0, 1.0);

DateTime _entityCreatedAt(
  DateTime? explicit,
  Iterable<DateTime> evidenceDates,
) {
  if (explicit != null) return explicit.toUtc();
  DateTime? earliest;
  for (final date in evidenceDates) {
    final utc = date.toUtc();
    if (earliest == null || utc.isBefore(earliest)) earliest = utc;
  }
  return earliest ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

String stableGraphId(String namespace, Iterable<String> parts) {
  final input = '$namespace\u001f${parts.join('\u001f')}';
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return '${namespace}_${hash.toRadixString(16).padLeft(8, '0')}';
}

const String journalEntryGraphNamespace = 'journal-entry';

String normalizeGraphLabel(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9\s'-]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class GraphNodeEvidence {
  GraphNodeEvidence({
    required this.entryId,
    required DateTime observedAt,
    required num confidence,
    required this.excerpt,
    this.startUtf16 = -1,
    this.endUtf16 = -1,
  }) : observedAt = observedAt.toUtc(),
       confidence = clampGraphScore(confidence);

  final String entryId;
  final DateTime observedAt;
  final double confidence;
  final String excerpt;
  final int startUtf16;
  final int endUtf16;

  bool get hasStructurallyValidCitation =>
      entryId.isNotEmpty &&
      excerpt.isNotEmpty &&
      startUtf16 >= 0 &&
      endUtf16 > startUtf16 &&
      endUtf16 - startUtf16 == excerpt.length;

  bool isExactSliceOf(String text) =>
      hasStructurallyValidCitation &&
      endUtf16 <= text.length &&
      text.substring(startUtf16, endUtf16) == excerpt;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'observedAt': observedAt.toIso8601String(),
    'confidence': confidence,
    'excerpt': excerpt,
    'startUtf16': startUtf16,
    'endUtf16': endUtf16,
  };

  factory GraphNodeEvidence.fromJson(Map<String, dynamic> json) =>
      GraphNodeEvidence(
        entryId: json['entryId'] as String? ?? '',
        observedAt:
            DateTime.tryParse(json['observedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        confidence: json['confidence'] as num? ?? 0,
        excerpt: json['excerpt'] as String? ?? '',
        startUtf16: (json['startUtf16'] as num?)?.toInt() ?? -1,
        endUtf16: (json['endUtf16'] as num?)?.toInt() ?? -1,
      );
}

/// A citation carried by a materialized temporal window.
///
/// This is intentionally the same shape as node evidence so every derived
/// temporal statement remains explainable down to an exact UTF-16 slice.
typedef GraphTrajectoryEvidence = GraphNodeEvidence;

class GraphEdgeEvidence {
  GraphEdgeEvidence({
    required this.entryId,
    required DateTime observedAt,
    required num confidence,
    required this.excerpt,
    this.startUtf16 = -1,
    this.endUtf16 = -1,
  }) : observedAt = observedAt.toUtc(),
       confidence = clampGraphScore(confidence);

  final String entryId;
  final DateTime observedAt;
  final double confidence;
  final String excerpt;
  final int startUtf16;
  final int endUtf16;

  bool get hasStructurallyValidCitation =>
      entryId.isNotEmpty &&
      excerpt.isNotEmpty &&
      startUtf16 >= 0 &&
      endUtf16 > startUtf16 &&
      endUtf16 - startUtf16 == excerpt.length;

  bool isExactSliceOf(String text) =>
      hasStructurallyValidCitation &&
      endUtf16 <= text.length &&
      text.substring(startUtf16, endUtf16) == excerpt;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'observedAt': observedAt.toIso8601String(),
    'confidence': confidence,
    'excerpt': excerpt,
    'startUtf16': startUtf16,
    'endUtf16': endUtf16,
  };

  factory GraphEdgeEvidence.fromJson(Map<String, dynamic> json) =>
      GraphEdgeEvidence(
        entryId: json['entryId'] as String? ?? '',
        observedAt:
            DateTime.tryParse(json['observedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        confidence: json['confidence'] as num? ?? 0,
        excerpt: json['excerpt'] as String? ?? '',
        startUtf16: (json['startUtf16'] as num?)?.toInt() ?? -1,
        endUtf16: (json['endUtf16'] as num?)?.toInt() ?? -1,
      );
}

class GraphNode {
  GraphNode({
    String? id,
    required this.type,
    required String label,
    required num confidence,
    Iterable<GraphNodeEvidence> evidence = const [],
    this.origin = NodeOrigin.extracted,
    DateTime? createdAt,
    DateTime? archivedAt,
    this.theoryId,
    this.externalSource,
    Iterable<MediaAttachment> mediaAttachments = const [],
    Iterable<String> tags = const [],
  }) : label = label.trim(),
       confidence = origin == NodeOrigin.manual || origin == NodeOrigin.external
           ? 1
           : clampGraphScore(confidence),
       evidence = List.unmodifiable(
         evidence.where((item) => item.hasStructurallyValidCitation),
       ),
       createdAt = _entityCreatedAt(
         createdAt,
         evidence.map((item) => item.observedAt),
       ),
       archivedAt = archivedAt?.toUtc(),
       mediaAttachments = immutableMediaAttachments(mediaAttachments),
       tags = Set.unmodifiable(
         tags
             .map((tag) => tag.trim().toLowerCase())
             .where((tag) => tag.isNotEmpty)
             .take(32),
       ),
       id =
           id ?? stableGraphId('node', [type.name, normalizeGraphLabel(label)]);

  final String id;
  final NodeType type;
  final String label;
  final double confidence;
  final List<GraphNodeEvidence> evidence;
  final NodeOrigin origin;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final String? theoryId;
  final ExternalSource? externalSource;
  final List<MediaAttachment> mediaAttachments;
  final Set<String> tags;

  bool get hasValidEvidence =>
      evidence.isNotEmpty &&
      evidence.every((item) => item.hasStructurallyValidCitation);

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'label': label,
    'confidence': confidence,
    'origin': origin.wireName,
    'createdAt': createdAt.toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
    if (theoryId != null) 'theoryId': theoryId,
    if (externalSource != null) 'externalSource': externalSource!.wireName,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    if (mediaAttachments.isNotEmpty)
      'mediaAttachments': mediaAttachments
          .map((attachment) => attachment.toJson())
          .toList(),
    if (tags.isNotEmpty) 'tags': tags.toList()..sort(),
  };

  factory GraphNode.fromJson(Map<String, dynamic> json) => GraphNode(
    id: json['id'] as String?,
    type: NodeType.values.byName(json['type'] as String? ?? 'memory'),
    label: json['label'] as String? ?? '',
    confidence: json['confidence'] as num? ?? 0,
    origin: NodeOrigin.fromWireName(json['origin'] as String?),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    archivedAt: DateTime.tryParse(json['archivedAt'] as String? ?? ''),
    theoryId: json['theoryId'] as String?,
    externalSource: ExternalSource.fromWireName(
      json['externalSource'] as String?,
    ),
    evidence: (json['evidence'] as List? ?? const []).whereType<Map>().map(
      (item) => GraphNodeEvidence.fromJson(Map<String, dynamic>.from(item)),
    ),
    mediaAttachments: (json['mediaAttachments'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => MediaAttachment.fromJson(Map<String, dynamic>.from(item)),
        ),
    tags: (json['tags'] as List? ?? const []).whereType<String>(),
  );

  GraphNode copyWith({
    Iterable<MediaAttachment>? mediaAttachments,
    Iterable<String>? tags,
  }) {
    return GraphNode(
      id: id,
      type: type,
      label: label,
      confidence: confidence,
      evidence: evidence,
      origin: origin,
      createdAt: createdAt,
      archivedAt: archivedAt,
      theoryId: theoryId,
      externalSource: externalSource,
      mediaAttachments: mediaAttachments ?? this.mediaAttachments,
      tags: tags ?? this.tags,
    );
  }

  GraphNode withMediaAttachment(MediaAttachment attachment) {
    return copyWith(mediaAttachments: [...mediaAttachments, attachment]);
  }

  GraphNode withoutMediaAttachment(String attachmentId) {
    return copyWith(
      mediaAttachments: mediaAttachments.where(
        (attachment) => attachment.id != attachmentId,
      ),
    );
  }
}

class GraphEdge {
  GraphEdge({
    String? id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.type,
    required this.isDirected,
    required num weight,
    DateTime? interactionDate,
    num? emotionalValenceScore,
    num? intensity,
    Iterable<GraphEdgeEvidence> evidence = const [],
    this.origin = NodeOrigin.extracted,
    DateTime? createdAt,
    DateTime? archivedAt,
    this.theoryId,
    this.externalSource,
  }) : weight = origin == NodeOrigin.manual || origin == NodeOrigin.external
           ? 1
           : clampGraphScore(weight),
       interactionDate = interactionDate?.toUtc(),
       emotionalValenceScore = emotionalValenceScore == null
           ? null
           : clampGraphValence(emotionalValenceScore),
       intensity = intensity == null ? null : clampGraphScore(intensity),
       evidence = List.unmodifiable(
         evidence.where((item) => item.hasStructurallyValidCitation),
       ),
       createdAt = _entityCreatedAt(
         createdAt,
         evidence.map((item) => item.observedAt),
       ),
       archivedAt = archivedAt?.toUtc(),
       id =
           id ??
           stableGraphId('edge', [
             type.name,
             sourceNodeId,
             targetNodeId,
             isDirected.toString(),
           ]);

  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final EdgeType type;
  final bool isDirected;
  final double weight;
  final DateTime? interactionDate;
  final double? emotionalValenceScore;
  final double? intensity;
  final List<GraphEdgeEvidence> evidence;
  final NodeOrigin origin;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final String? theoryId;
  final ExternalSource? externalSource;

  bool get hasValidEvidence =>
      evidence.isNotEmpty &&
      evidence.every((item) => item.hasStructurallyValidCitation);

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceNodeId': sourceNodeId,
    'targetNodeId': targetNodeId,
    'type': type.name,
    'isDirected': isDirected,
    'weight': weight,
    'origin': origin.wireName,
    'createdAt': createdAt.toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
    if (theoryId != null) 'theoryId': theoryId,
    if (externalSource != null) 'externalSource': externalSource!.wireName,
    if (interactionDate != null)
      'interactionDate': interactionDate!.toIso8601String(),
    if (emotionalValenceScore != null)
      'emotionalValenceScore': emotionalValenceScore,
    if (intensity != null) 'intensity': intensity,
    'evidence': evidence.map((item) => item.toJson()).toList(),
  };

  factory GraphEdge.fromJson(Map<String, dynamic> json) => GraphEdge(
    id: json['id'] as String?,
    sourceNodeId: json['sourceNodeId'] as String? ?? '',
    targetNodeId: json['targetNodeId'] as String? ?? '',
    type: EdgeType.values.byName(
      json['type'] as String? ?? EdgeType.associatedWith.name,
    ),
    isDirected: json['isDirected'] == true,
    weight: json['weight'] as num? ?? 0,
    origin: NodeOrigin.fromWireName(json['origin'] as String?),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    archivedAt: DateTime.tryParse(json['archivedAt'] as String? ?? ''),
    theoryId: json['theoryId'] as String?,
    externalSource: ExternalSource.fromWireName(
      json['externalSource'] as String?,
    ),
    interactionDate: DateTime.tryParse(
      json['interactionDate'] as String? ?? '',
    ),
    emotionalValenceScore: json['emotionalValenceScore'] as num?,
    intensity: json['intensity'] as num?,
    evidence: (json['evidence'] as List? ?? const []).whereType<Map>().map(
      (item) => GraphEdgeEvidence.fromJson(Map<String, dynamic>.from(item)),
    ),
  );
}
