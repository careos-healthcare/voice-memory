import 'dart:collection';

enum VisionEntityKind {
  person,
  place,
  object,
  text;

  static VisionEntityKind parse(Object? value) {
    if (value is! String) {
      throw const FormatException('Vision entity kind is invalid.');
    }
    return values.where((kind) => kind.name == value).firstOrNull ??
        (throw const FormatException('Vision entity kind is invalid.'));
  }
}

class VisionEntity {
  VisionEntity({
    required this.kind,
    required String label,
    required num confidence,
  }) : label = _boundedString(label, 160, 'Vision entity label'),
       confidence = _confidence(confidence);

  final VisionEntityKind kind;
  final String label;
  final double confidence;

  factory VisionEntity.fromJson(Object? value) {
    final json = _strictRecord(value, const {
      'kind',
      'label',
      'confidence',
    }, 'Vision entity');
    return VisionEntity(
      kind: VisionEntityKind.parse(json['kind']),
      label: _boundedString(json['label'], 160, 'Vision entity label'),
      confidence: _confidence(json['confidence']),
    );
  }
}

class VisionRelationship {
  VisionRelationship({
    required String source,
    required String target,
    required String relationship,
    required num confidence,
  }) : source = _boundedString(source, 160, 'Relationship source'),
       target = _boundedString(target, 160, 'Relationship target'),
       relationship = _boundedString(relationship, 160, 'Relationship label'),
       confidence = _confidence(confidence);

  final String source;
  final String target;
  final String relationship;
  final double confidence;

  factory VisionRelationship.fromJson(Object? value) {
    final json = _strictRecord(value, const {
      'source',
      'target',
      'relationship',
      'confidence',
    }, 'Vision relationship');
    return VisionRelationship(
      source: _boundedString(json['source'], 160, 'Relationship source'),
      target: _boundedString(json['target'], 160, 'Relationship target'),
      relationship: _boundedString(
        json['relationship'],
        160,
        'Relationship label',
      ),
      confidence: _confidence(json['confidence']),
    );
  }
}

class VisionExtraction {
  VisionExtraction({
    required String sceneSummary,
    required Iterable<String> visibleText,
    required Iterable<VisionEntity> entities,
    required Iterable<VisionRelationship> relationships,
  }) : sceneSummary = _boundedString(sceneSummary, 1000, 'sceneSummary'),
       visibleText = List.unmodifiable(
         visibleText.map(
           (item) => _boundedString(item, 500, 'visibleText item'),
         ),
       ),
       entities = List.unmodifiable(entities),
       relationships = List.unmodifiable(relationships) {
    if (this.visibleText.length > 100 ||
        this.entities.length > 100 ||
        this.relationships.length > 100) {
      throw const FormatException(
        'Vision extraction arrays must contain at most 100 items.',
      );
    }
    final labels = this.entities.map((entity) => entity.label).toSet();
    if (this.relationships.any(
      (edge) => !labels.contains(edge.source) || !labels.contains(edge.target),
    )) {
      throw const FormatException(
        'Relationship endpoints must reference entity labels.',
      );
    }
  }

  final String sceneSummary;
  final List<String> visibleText;
  final List<VisionEntity> entities;
  final List<VisionRelationship> relationships;

  factory VisionExtraction.fromJson(Object? value) {
    final json = _strictRecord(value, const {
      'sceneSummary',
      'visibleText',
      'entities',
      'relationships',
    }, 'Vision extraction');
    final visibleText = _array(json['visibleText'], 'visibleText');
    final entities = _array(json['entities'], 'entities');
    final relationships = _array(json['relationships'], 'relationships');
    return VisionExtraction(
      sceneSummary: _boundedString(json['sceneSummary'], 1000, 'sceneSummary'),
      visibleText: visibleText.map(
        (item) => _boundedString(item, 500, 'visibleText item'),
      ),
      entities: entities.map(VisionEntity.fromJson),
      relationships: relationships.map(VisionRelationship.fromJson),
    );
  }
}

class LocalVisionExtraction {
  LocalVisionExtraction({
    required this.width,
    required this.height,
    required this.mimeType,
    required Iterable<String> visibleText,
    required Iterable<String> tags,
  }) : visibleText = List.unmodifiable(visibleText),
       tags = UnmodifiableSetView(Set.of(tags));

  final int width;
  final int height;
  final String mimeType;
  final List<String> visibleText;
  final Set<String> tags;

  VisionExtraction asLocalOnlyExtraction() => VisionExtraction(
    sceneSummary: 'Visual memory, $width × $height $mimeType.',
    visibleText: visibleText,
    entities: [
      for (final text in visibleText)
        VisionEntity(
          kind: VisionEntityKind.text,
          label: text.length > 160 ? text.substring(0, 160) : text,
          confidence: 0.8,
        ),
    ],
    relationships: const [],
  );
}

class VisionExtractionResult {
  const VisionExtractionResult({
    required this.local,
    required this.extraction,
    required this.usedCloud,
  });

  final LocalVisionExtraction local;
  final VisionExtraction extraction;
  final bool usedCloud;
}

Map<String, dynamic> _strictRecord(
  Object? value,
  Set<String> keys,
  String label,
) {
  if (value is! Map) throw FormatException('$label must be an object.');
  final json = Map<String, dynamic>.from(value);
  if (json.keys.toSet().difference(keys).isNotEmpty) {
    throw FormatException('$label contains unknown fields.');
  }
  if (!json.keys.toSet().containsAll(keys)) {
    throw FormatException('$label is missing required fields.');
  }
  return json;
}

List<Object?> _array(Object? value, String label) {
  if (value is! List || value.length > 100) {
    throw FormatException('$label must be an array with at most 100 items.');
  }
  return value;
}

String _boundedString(Object? value, int max, String label) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > max ||
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]').hasMatch(value)) {
    throw FormatException('$label is invalid.');
  }
  return value.trim();
}

double _confidence(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 1) {
    throw const FormatException('Confidence must be a number between 0 and 1.');
  }
  return value.toDouble();
}
