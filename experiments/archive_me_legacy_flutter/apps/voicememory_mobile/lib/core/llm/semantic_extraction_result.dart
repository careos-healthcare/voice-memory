enum SemanticEntityType {
  person,
  place,
  event,
  goal,
  fear,
  habit,
  belief,
  project,
  emotion,
  decision,
  outcome,
}

enum SemanticRelationType {
  triggeredBy,
  influences,
  evolvedInto,
  decidedOn,
  resultedIn,
  feltAbout,
  partOf,
  supportsBelief,
  contradictsBelief,
}

double _clampUnit(num value) => value.toDouble().clamp(0.0, 1.0);

double _clampSentiment(num value) => value.toDouble().clamp(-1.0, 1.0);

class SemanticEntity {
  SemanticEntity({
    required this.type,
    required String label,
    required num confidence,
    num sentiment = 0,
    required this.excerpt,
    this.startUtf16 = -1,
    this.endUtf16 = -1,
  }) : label = label.trim(),
       confidence = _clampUnit(confidence),
       sentiment = _clampSentiment(sentiment);

  final SemanticEntityType type;
  final String label;
  final double confidence;
  final double sentiment;
  final String excerpt;
  final int startUtf16;
  final int endUtf16;

  bool isExactSliceOf(String text) =>
      startUtf16 >= 0 &&
      endUtf16 > startUtf16 &&
      endUtf16 <= text.length &&
      text.substring(startUtf16, endUtf16) == excerpt;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'label': label,
    'confidence': confidence,
    'sentiment': sentiment,
    'excerpt': excerpt,
    'startUtf16': startUtf16,
    'endUtf16': endUtf16,
  };

  factory SemanticEntity.fromJson(Map<String, dynamic> json) => SemanticEntity(
    type: SemanticEntityType.values.byName(
      json['type'] as String? ?? SemanticEntityType.event.name,
    ),
    label: json['label'] as String? ?? '',
    confidence: json['confidence'] as num? ?? 0,
    sentiment: json['sentiment'] as num? ?? 0,
    excerpt: json['excerpt'] as String? ?? '',
    startUtf16: (json['startUtf16'] as num?)?.toInt() ?? -1,
    endUtf16: (json['endUtf16'] as num?)?.toInt() ?? -1,
  );
}

class SemanticRelation {
  SemanticRelation({
    required this.type,
    required this.sourceType,
    required String sourceLabel,
    required this.targetType,
    required String targetLabel,
    required num weight,
    required this.excerpt,
    this.startUtf16 = -1,
    this.endUtf16 = -1,
  }) : sourceLabel = sourceLabel.trim(),
       targetLabel = targetLabel.trim(),
       weight = _clampUnit(weight);

  final SemanticRelationType type;
  final SemanticEntityType sourceType;
  final String sourceLabel;
  final SemanticEntityType targetType;
  final String targetLabel;
  final double weight;
  final String excerpt;
  final int startUtf16;
  final int endUtf16;

  bool get isDirected => true;

  bool isExactSliceOf(String text) =>
      startUtf16 >= 0 &&
      endUtf16 > startUtf16 &&
      endUtf16 <= text.length &&
      text.substring(startUtf16, endUtf16) == excerpt;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'sourceType': sourceType.name,
    'sourceLabel': sourceLabel,
    'targetType': targetType.name,
    'targetLabel': targetLabel,
    'weight': weight,
    'isDirected': true,
    'excerpt': excerpt,
    'startUtf16': startUtf16,
    'endUtf16': endUtf16,
  };

  factory SemanticRelation.fromJson(Map<String, dynamic> json) =>
      SemanticRelation(
        type: SemanticRelationType.values.byName(
          json['type'] as String? ?? SemanticRelationType.influences.name,
        ),
        sourceType: SemanticEntityType.values.byName(
          json['sourceType'] as String? ?? SemanticEntityType.event.name,
        ),
        sourceLabel: json['sourceLabel'] as String? ?? '',
        targetType: SemanticEntityType.values.byName(
          json['targetType'] as String? ?? SemanticEntityType.event.name,
        ),
        targetLabel: json['targetLabel'] as String? ?? '',
        weight: json['weight'] as num? ?? 0,
        excerpt: json['excerpt'] as String? ?? '',
        startUtf16: (json['startUtf16'] as num?)?.toInt() ?? -1,
        endUtf16: (json['endUtf16'] as num?)?.toInt() ?? -1,
      );
}

class SemanticExtractionResult {
  SemanticExtractionResult({
    Iterable<SemanticEntity> entities = const [],
    Iterable<SemanticRelation> relations = const [],
    required num sentiment,
    required num confidence,
    this.inferenceDriver = '',
    this.usedFallback = false,
  }) : entities = List.unmodifiable(entities),
       relations = List.unmodifiable(relations),
       sentiment = _clampSentiment(sentiment),
       confidence = _clampUnit(confidence);

  final List<SemanticEntity> entities;
  final List<SemanticRelation> relations;
  final double sentiment;
  final double confidence;
  final String inferenceDriver;
  final bool usedFallback;

  bool get isValid =>
      confidence > 0 &&
      entities.every(
        (entity) =>
            entity.label.isNotEmpty &&
            entity.excerpt.isNotEmpty &&
            entity.startUtf16 >= 0 &&
            entity.endUtf16 > entity.startUtf16,
      ) &&
      relations.every(
        (relation) =>
            relation.sourceLabel.isNotEmpty &&
            relation.targetLabel.isNotEmpty &&
            relation.sourceLabel != relation.targetLabel &&
            relation.excerpt.isNotEmpty &&
            relation.startUtf16 >= 0 &&
            relation.endUtf16 > relation.startUtf16,
      );

  Map<String, dynamic> toJson() => {
    'entities': entities.map((entity) => entity.toJson()).toList(),
    'relations': relations.map((relation) => relation.toJson()).toList(),
    'sentiment': sentiment,
    'confidence': confidence,
    'inferenceDriver': inferenceDriver,
    'usedFallback': usedFallback,
  };

  factory SemanticExtractionResult.fromJson(
    Map<String, dynamic> json,
  ) => SemanticExtractionResult(
    entities: (json['entities'] as List? ?? const []).whereType<Map>().map(
      (entity) => SemanticEntity.fromJson(Map<String, dynamic>.from(entity)),
    ),
    relations: (json['relations'] as List? ?? const []).whereType<Map>().map(
      (relation) =>
          SemanticRelation.fromJson(Map<String, dynamic>.from(relation)),
    ),
    sentiment: json['sentiment'] as num? ?? 0,
    confidence: json['confidence'] as num? ?? 0,
    inferenceDriver: json['inferenceDriver'] as String? ?? '',
    usedFallback: json['usedFallback'] == true,
  );
}
