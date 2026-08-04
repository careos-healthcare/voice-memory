import '../../models/local_capture_context.dart';
import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import 'semantic_extraction_result.dart';

/// Synchronous boundary for a real on-device quantized model adapter.
///
/// Implementations must not make network requests or use platform channels.
abstract interface class QuantizedSemanticInferenceDriver {
  String get identifier;

  bool get isAvailable;

  SemanticExtractionResult infer(String text);
}

/// Neutral asynchronous boundary for native or isolate-backed semantic models.
///
/// Implementations are responsible for running expensive inference outside the
/// main isolate. This boundary deliberately does not import a concrete model
/// manager, so a native session such as `LlamaInferenceSession` can implement
/// it directly.
abstract interface class AsyncSemanticInferenceSession {
  bool get isReady;

  Future<SemanticExtractionResult> infer(String text);
}

@Deprecated('Use AsyncSemanticInferenceSession.')
typedef AsyncSemanticInferenceDriver = AsyncSemanticInferenceSession;

class UnavailableQuantizedSemanticInferenceDriver
    implements QuantizedSemanticInferenceDriver {
  const UnavailableQuantizedSemanticInferenceDriver({
    this.reason = 'No local inference driver is configured.',
  });

  final String reason;

  @override
  String get identifier => 'unavailable';

  @override
  bool get isAvailable => false;

  @override
  SemanticExtractionResult infer(String text) {
    throw StateError(reason);
  }
}

/// A compact, model-independent local inference driver.
///
/// This is not a bundled generative LLM. It performs deterministic int8
/// token-to-prototype scoring and local span extraction. A native or Dart
/// adapter backed by an actual quantized model can implement
/// [QuantizedSemanticInferenceDriver] and be injected in its place.
class CompactQuantizedLocalInferenceDriver
    implements QuantizedSemanticInferenceDriver {
  const CompactQuantizedLocalInferenceDriver();

  @override
  String get identifier => 'compact-int8-token-prototype-v1';

  @override
  bool get isAvailable => true;

  static final List<_EntityPattern> _patterns = [
    _EntityPattern(
      SemanticEntityType.goal,
      RegExp(
        r'\b(?:my goal is|i want to|i plan to|i hope to)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      const {'goal': 112, 'want': 96, 'plan': 104, 'hope': 80},
    ),
    _EntityPattern(
      SemanticEntityType.fear,
      RegExp(
        r'\b(?:i am afraid of|i fear|i am worried about|i worry about)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      const {'afraid': 120, 'fear': 127, 'worried': 112, 'worry': 104},
    ),
    _EntityPattern(
      SemanticEntityType.habit,
      RegExp(
        r'\b(?:i usually|every day i|each day i|my habit is|i keep)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      const {'usually': 108, 'every': 88, 'habit': 127, 'keep': 72},
    ),
    _EntityPattern(
      SemanticEntityType.belief,
      RegExp(
        r'\b(?:i believe(?: that)?|i think that|my belief is)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      const {'believe': 127, 'belief': 127, 'think': 84},
    ),
    _EntityPattern(
      SemanticEntityType.decision,
      RegExp(
        r'\b(?:i decided to|i have decided to|my decision is to|we decided to)\s+([^.!?;\n]+?)(?=\s+(?:and\s+)?(?:it|this)\s+resulted in|[.!?;\n]|$)',
        caseSensitive: false,
      ),
      const {'decided': 127, 'decision': 127},
    ),
    _EntityPattern(
      SemanticEntityType.outcome,
      RegExp(
        r'\b(?:the outcome was|this resulted in|it resulted in|the result was)\s+([^.!?;\n]+)',
        caseSensitive: false,
      ),
      const {'outcome': 127, 'resulted': 120, 'result': 116},
    ),
    _EntityPattern(
      SemanticEntityType.project,
      RegExp(
        r'\b(?:project|working on|started|launched)\s+["“]?([A-Z][A-Za-z0-9_-]*(?:\s+[A-Z][A-Za-z0-9_-]*){0,4})["”]?',
      ),
      const {'project': 127, 'working': 100, 'started': 104, 'launched': 116},
    ),
    _EntityPattern(
      SemanticEntityType.emotion,
      RegExp(
        r'\b(?:i feel|i felt|i am feeling|i was feeling)\s+(happy|sad|angry|anxious|afraid|excited|grateful|proud|calm|upset|worried|relieved)\b',
        caseSensitive: false,
      ),
      const {'feel': 112, 'felt': 120, 'feeling': 112},
    ),
    _EntityPattern(
      SemanticEntityType.event,
      RegExp(
        r'\b(?:the|my|our)\s+((?:meeting|wedding|conference|trip|birthday|appointment)(?:\s+[^.!?;\n]+)?)',
        caseSensitive: false,
      ),
      const {
        'meeting': 112,
        'wedding': 120,
        'conference': 116,
        'trip': 104,
        'birthday': 112,
        'appointment': 108,
      },
    ),
    _EntityPattern(
      SemanticEntityType.place,
      RegExp(
        r'\b(?:at|in|near)\s+([A-Z][A-Za-z0-9]*(?:\s+[A-Z][A-Za-z0-9]*){0,3})',
      ),
      const {'at': 72, 'in': 64, 'near': 96},
    ),
    _EntityPattern(
      SemanticEntityType.person,
      RegExp(
        r'\b(?:i feel|i felt|i am feeling|i was feeling)\s+(?:happy|sad|angry|anxious|afraid|excited|grateful|proud|calm|upset|worried|relieved)\s+about\s+([A-Z][A-Za-z]*(?:\s+[A-Z][A-Za-z]*){0,2})',
      ),
      const {'feel': 112, 'felt': 120, 'about': 96},
    ),
    _EntityPattern(
      SemanticEntityType.person,
      RegExp(
        r'\b(?:with|met|called|spoke to|talked to)\s+([A-Z][A-Za-z]*(?:\s+[A-Z][A-Za-z]*){0,2})',
      ),
      const {'with': 72, 'met': 104, 'called': 88, 'spoke': 112, 'talked': 104},
    ),
  ];

  @override
  SemanticExtractionResult infer(String text) {
    final entities = <SemanticEntity>[];
    for (final pattern in _patterns) {
      for (final match in pattern.expression.allMatches(text)) {
        final label = _cleanLabel(match.group(1) ?? '');
        if (label.isEmpty) continue;
        final excerpt = text.substring(match.start, match.end);
        entities.add(
          SemanticEntity(
            type: pattern.type,
            label: label,
            confidence: _quantizedPrototypeScore(excerpt, pattern.prototype),
            sentiment: _localSentiment(excerpt),
            excerpt: excerpt,
            startUtf16: match.start,
            endUtf16: match.end,
          ),
        );
      }
    }
    final deduplicated = _deduplicateEntities(entities);
    final relations = _relations(text, deduplicated);
    final confidence = deduplicated.isEmpty
        ? 0.35
        : deduplicated
              .map((entity) => entity.confidence)
              .reduce((a, b) => a > b ? a : b);
    return SemanticExtractionResult(
      entities: deduplicated,
      relations: relations,
      sentiment: _localSentiment(text),
      confidence: confidence,
      inferenceDriver: identifier,
    );
  }

  static double _quantizedPrototypeScore(
    String excerpt,
    Map<String, int> prototype,
  ) {
    final tokens = RegExp(
      r"[a-z']+",
    ).allMatches(excerpt.toLowerCase()).map((match) => match.group(0)!).toSet();
    var int8DotProduct = 0;
    var strongestWeight = 0;
    for (final token in tokens) {
      final weight = prototype[token] ?? 0;
      int8DotProduct += weight;
      if (weight > strongestWeight) strongestWeight = weight;
    }
    final normalized = (int8DotProduct / (prototype.length * 127)).clamp(
      0.0,
      1.0,
    );
    final strongest = strongestWeight / 127;
    return (0.56 + (normalized * 0.18) + (strongest * 0.22)).clamp(0.0, 1.0);
  }

  static List<SemanticEntity> _deduplicateEntities(
    Iterable<SemanticEntity> entities,
  ) {
    final byKey = <String, SemanticEntity>{};
    for (final entity in entities) {
      final key = '${entity.type.name}:${_normalize(entity.label)}';
      final current = byKey[key];
      if (current == null || entity.confidence > current.confidence) {
        byKey[key] = entity;
      }
    }
    return List.unmodifiable(byKey.values);
  }

  static List<SemanticRelation> _relations(
    String text,
    List<SemanticEntity> entities,
  ) {
    final lower = text.toLowerCase();
    final relations = <SemanticRelation>[];
    for (final source in entities) {
      for (final target in entities) {
        if (identical(source, target)) continue;
        final sourceIndex = lower.indexOf(source.label.toLowerCase());
        final targetIndex = lower.indexOf(target.label.toLowerCase());
        if (sourceIndex < 0 || targetIndex <= sourceIndex) continue;
        final connector = lower.substring(
          sourceIndex + source.label.length,
          targetIndex,
        );
        final relation =
            source.type == SemanticEntityType.emotion &&
                RegExp(r'\babout\b').hasMatch(connector)
            ? (type: SemanticRelationType.feltAbout, weight: 0.92)
            : _relationPrototype(connector);
        if (relation == null) continue;
        relations.add(
          SemanticRelation(
            type: relation.type,
            sourceType: source.type,
            sourceLabel: source.label,
            targetType: target.type,
            targetLabel: target.label,
            weight: relation.weight,
            excerpt: text,
            startUtf16: 0,
            endUtf16: text.length,
          ),
        );
      }
    }
    return List.unmodifiable(relations);
  }

  static ({SemanticRelationType type, double weight})? _relationPrototype(
    String connector,
  ) {
    if (RegExp(r'\btriggered by\b').hasMatch(connector)) {
      return (type: SemanticRelationType.triggeredBy, weight: 0.82);
    }
    if (RegExp(r'\bevolved into\b').hasMatch(connector)) {
      return (type: SemanticRelationType.evolvedInto, weight: 0.88);
    }
    if (RegExp(r'\binfluences?\b').hasMatch(connector)) {
      return (type: SemanticRelationType.influences, weight: 0.78);
    }
    if (RegExp(r'\bdecided (?:on|to)\b').hasMatch(connector)) {
      return (type: SemanticRelationType.decidedOn, weight: 0.9);
    }
    if (RegExp(r'\bresulted in\b').hasMatch(connector)) {
      return (type: SemanticRelationType.resultedIn, weight: 0.92);
    }
    if (RegExp(r'\b(?:felt|feel|feels) .*?\babout\b').hasMatch(connector)) {
      return (type: SemanticRelationType.feltAbout, weight: 0.9);
    }
    if (RegExp(r'\bpart of\b').hasMatch(connector)) {
      return (type: SemanticRelationType.partOf, weight: 0.88);
    }
    if (RegExp(r'\bsupports? (?:my |the )?belief\b').hasMatch(connector)) {
      return (type: SemanticRelationType.supportsBelief, weight: 0.9);
    }
    if (RegExp(r'\bcontradicts? (?:my |the )?belief\b').hasMatch(connector)) {
      return (type: SemanticRelationType.contradictsBelief, weight: 0.9);
    }
    return null;
  }

  static double _localSentiment(String text) {
    const positive = {
      'calm': 2,
      'confident': 3,
      'excited': 3,
      'good': 2,
      'grateful': 3,
      'happy': 3,
      'hopeful': 2,
      'love': 3,
      'proud': 3,
      'relieved': 2,
    };
    const negative = {
      'afraid': 3,
      'angry': 3,
      'anxious': 3,
      'bad': 2,
      'fear': 3,
      'sad': 3,
      'stressed': 2,
      'upset': 2,
      'worried': 3,
      'worry': 3,
    };
    var score = 0;
    for (final match in RegExp(r"[a-z']+").allMatches(text.toLowerCase())) {
      final token = match.group(0)!;
      score += positive[token] ?? 0;
      score -= negative[token] ?? 0;
    }
    return (score / 6).clamp(-1.0, 1.0);
  }

  static String _cleanLabel(String value) {
    final words = value.trim().replaceAll(RegExp(r'\s+'), ' ').split(' ');
    return words
        .take(12)
        .join(' ')
        .replaceFirst(
          RegExp(r'\s+(?:and|but|because|when|while)$', caseSensitive: false),
          '',
        );
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class OnDeviceSemanticExtractor
    implements GraphEntityExtractor, AsyncGraphEntityExtractor {
  const OnDeviceSemanticExtractor({
    this.driver = const CompactQuantizedLocalInferenceDriver(),
    AsyncSemanticInferenceSession? asyncSession,
    @Deprecated('Use asyncSession.') AsyncSemanticInferenceSession? asyncDriver,
    this.fallback = const RuleBasedGraphEntityExtractor(),
    this.minimumPrimaryConfidence = 0.5,
    this.asyncInferenceTimeout = const Duration(seconds: 30),
  }) : asyncSession = asyncSession ?? asyncDriver;

  final QuantizedSemanticInferenceDriver driver;
  final AsyncSemanticInferenceSession? asyncSession;
  final RuleBasedGraphEntityExtractor fallback;
  final double minimumPrimaryConfidence;
  final Duration asyncInferenceTimeout;

  SemanticExtractionResult extractSemantic({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) => _resolve(text, localCaptureContext).semantic;

  @override
  GraphExtraction extract({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) {
    return _graphExtractionFromResolved(_resolve(text, localCaptureContext));
  }

  Future<SemanticExtractionResult> extractSemanticAsync({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) async => (await _resolveAsync(text, localCaptureContext)).semantic;

  @override
  Future<GraphExtraction> extractAsync({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) async {
    final resolved = await _resolveAsync(text, localCaptureContext);
    return _graphExtractionFromResolved(resolved);
  }

  ({SemanticExtractionResult semantic, GraphExtraction fallback}) _resolve(
    String text,
    LocalCaptureContext? localCaptureContext,
  ) {
    final fallbackExtraction = fallback.extract(
      text: text,
      localCaptureContext: localCaptureContext,
    );
    SemanticExtractionResult? primary;
    var degraded = !driver.isAvailable;
    if (!degraded) {
      try {
        primary = driver.infer(text);
        degraded =
            !primary.isValid ||
            !_isExactResult(primary, text) ||
            primary.confidence < minimumPrimaryConfidence;
      } catch (_) {
        degraded = true;
      }
    }

    return _mergeResolved(
      text: text,
      primary: primary,
      fallbackExtraction: fallbackExtraction,
      degraded: degraded,
      degradedDriver: driver.identifier,
    );
  }

  Future<({SemanticExtractionResult semantic, GraphExtraction fallback})>
  _resolveAsync(String text, LocalCaptureContext? localCaptureContext) async {
    final async = asyncSession;
    SemanticExtractionResult? primary;
    var degraded = async == null || !async.isReady;
    if (!degraded) {
      try {
        primary = await async.infer(text).timeout(asyncInferenceTimeout);
        degraded =
            !primary.isValid ||
            !_isExactResult(primary, text) ||
            primary.confidence < minimumPrimaryConfidence;
      } catch (_) {
        degraded = true;
      }
    }

    final compactAndRule = _resolve(text, localCaptureContext);
    if (primary == null || !primary.isValid || !_isExactResult(primary, text)) {
      return (
        semantic: _copyWithFallback(compactAndRule.semantic),
        fallback: compactAndRule.fallback,
      );
    }

    return _mergeResolved(
      text: text,
      primary: primary,
      supplementalSemantic: compactAndRule.semantic,
      fallbackExtraction: compactAndRule.fallback,
      degraded: degraded,
      degradedDriver: compactAndRule.semantic.inferenceDriver,
    );
  }

  static SemanticExtractionResult _copyWithFallback(
    SemanticExtractionResult result,
  ) => SemanticExtractionResult(
    entities: result.entities,
    relations: result.relations,
    sentiment: result.sentiment,
    confidence: result.confidence,
    inferenceDriver: result.inferenceDriver,
    usedFallback: true,
  );

  ({SemanticExtractionResult semantic, GraphExtraction fallback})
  _mergeResolved({
    required String text,
    required SemanticExtractionResult? primary,
    SemanticExtractionResult? supplementalSemantic,
    required GraphExtraction fallbackExtraction,
    required bool degraded,
    required String degradedDriver,
  }) {
    final fallbackSemantic = _semanticFromGraph(fallbackExtraction);
    final mergedEntities = _deduplicateSemanticEntities([
      ...?primary?.entities.where((item) => item.isExactSliceOf(text)),
      ...?supplementalSemantic?.entities.where(
        (item) => item.isExactSliceOf(text),
      ),
      ...fallbackSemantic.entities.where((item) => item.isExactSliceOf(text)),
    ]);
    final mergedRelations = _deduplicateSemanticRelations([
      ...?primary?.relations.where((item) => item.isExactSliceOf(text)),
      ...?supplementalSemantic?.relations.where(
        (item) => item.isExactSliceOf(text),
      ),
      ...fallbackSemantic.relations.where((item) => item.isExactSliceOf(text)),
    ]);
    final primaryUsable =
        primary != null && primary.isValid && _isExactResult(primary, text);
    return (
      semantic: SemanticExtractionResult(
        entities: mergedEntities,
        relations: mergedRelations,
        sentiment: primaryUsable
            ? primary.sentiment
            : CompactQuantizedLocalInferenceDriver._localSentiment(text),
        confidence: primaryUsable
            ? primary.confidence
            : fallbackSemantic.confidence,
        inferenceDriver: primaryUsable
            ? primary.inferenceDriver
            : degradedDriver,
        usedFallback: degraded,
      ),
      fallback: fallbackExtraction,
    );
  }

  GraphExtraction _graphExtractionFromResolved(
    ({SemanticExtractionResult semantic, GraphExtraction fallback}) resolved,
  ) {
    final entities = <GraphEntityMention>[...resolved.fallback.entities];
    final relations = <GraphRelationMention>[...resolved.fallback.relations];
    for (final entity in resolved.semantic.entities) {
      entities.add(_toGraphEntity(entity));
    }
    for (final relation in resolved.semantic.relations) {
      relations.add(_toGraphRelation(relation));
    }
    return GraphExtraction(
      entities: _deduplicateGraphEntities(entities),
      relations: _deduplicateGraphRelations(relations),
    );
  }

  static SemanticExtractionResult _semanticFromGraph(GraphExtraction graph) {
    final entities = graph.entities
        .map((entity) {
          final type = _semanticType(entity.type);
          if (type == null) return null;
          return SemanticEntity(
            type: type,
            label: entity.label,
            confidence: entity.confidence,
            sentiment: CompactQuantizedLocalInferenceDriver._localSentiment(
              entity.excerpt ?? entity.label,
            ),
            excerpt: entity.excerpt ?? entity.label,
            startUtf16: entity.startUtf16,
            endUtf16: entity.endUtf16,
          );
        })
        .whereType<SemanticEntity>()
        .toList();
    final relations = graph.relations
        .map((relation) {
          final type = _semanticRelationType(relation.type);
          final sourceType = _semanticType(relation.sourceType);
          final targetType = _semanticType(relation.targetType);
          if (type == null || sourceType == null || targetType == null) {
            return null;
          }
          return SemanticRelation(
            type: type,
            sourceType: sourceType,
            sourceLabel: relation.sourceLabel,
            targetType: targetType,
            targetLabel: relation.targetLabel,
            weight: relation.confidence,
            excerpt: relation.excerpt ?? '',
            startUtf16: relation.startUtf16,
            endUtf16: relation.endUtf16,
          );
        })
        .whereType<SemanticRelation>()
        .toList();
    final confidence = entities.isEmpty
        ? 0.0
        : entities
              .map((entity) => entity.confidence)
              .reduce((a, b) => a > b ? a : b);
    return SemanticExtractionResult(
      entities: entities,
      relations: relations,
      sentiment: 0,
      confidence: confidence,
      inferenceDriver: 'rule-based-fallback',
      usedFallback: true,
    );
  }

  static GraphEntityMention _toGraphEntity(SemanticEntity entity) =>
      GraphEntityMention(
        type: NodeType.values.byName(entity.type.name),
        label: entity.label,
        confidence: entity.confidence,
        excerpt: entity.excerpt,
        startUtf16: entity.startUtf16,
        endUtf16: entity.endUtf16,
      );

  static GraphRelationMention _toGraphRelation(SemanticRelation relation) =>
      GraphRelationMention(
        sourceType: NodeType.values.byName(relation.sourceType.name),
        sourceLabel: relation.sourceLabel,
        targetType: NodeType.values.byName(relation.targetType.name),
        targetLabel: relation.targetLabel,
        type: EdgeType.values.byName(relation.type.name),
        isDirected: true,
        confidence: relation.weight,
        excerpt: relation.excerpt,
        startUtf16: relation.startUtf16,
        endUtf16: relation.endUtf16,
      );

  static bool _isExactResult(SemanticExtractionResult result, String text) =>
      result.entities.every((item) => item.isExactSliceOf(text)) &&
      result.relations.every((item) => item.isExactSliceOf(text));

  static SemanticEntityType? _semanticType(NodeType type) {
    if (type == NodeType.memory || type == NodeType.chapter) return null;
    return SemanticEntityType.values.byName(type.name);
  }

  static SemanticRelationType? _semanticRelationType(EdgeType type) {
    if (!SemanticRelationType.values.any((item) => item.name == type.name)) {
      return null;
    }
    return SemanticRelationType.values.byName(type.name);
  }

  static List<SemanticEntity> _deduplicateSemanticEntities(
    Iterable<SemanticEntity> entities,
  ) {
    final byKey = <String, SemanticEntity>{};
    for (final entity in entities) {
      final key = '${entity.type.name}:${normalizeGraphLabel(entity.label)}';
      final current = byKey[key];
      if (current == null || entity.confidence > current.confidence) {
        byKey[key] = entity;
      }
    }
    return List.unmodifiable(byKey.values);
  }

  static List<SemanticRelation> _deduplicateSemanticRelations(
    Iterable<SemanticRelation> relations,
  ) {
    final byKey = <String, SemanticRelation>{};
    for (final relation in relations) {
      final key =
          '${relation.type.name}:${relation.sourceType.name}:'
          '${normalizeGraphLabel(relation.sourceLabel)}:'
          '${relation.targetType.name}:${normalizeGraphLabel(relation.targetLabel)}';
      final current = byKey[key];
      if (current == null || relation.weight > current.weight) {
        byKey[key] = relation;
      }
    }
    return List.unmodifiable(byKey.values);
  }

  static List<GraphEntityMention> _deduplicateGraphEntities(
    Iterable<GraphEntityMention> entities,
  ) {
    final byKey = <String, GraphEntityMention>{};
    for (final entity in entities) {
      final key = '${entity.type.name}:${normalizeGraphLabel(entity.label)}';
      final current = byKey[key];
      if (current == null || entity.confidence > current.confidence) {
        byKey[key] = entity;
      }
    }
    return List.unmodifiable(byKey.values);
  }

  static List<GraphRelationMention> _deduplicateGraphRelations(
    Iterable<GraphRelationMention> relations,
  ) {
    final byKey = <String, GraphRelationMention>{};
    for (final relation in relations) {
      final key =
          '${relation.type.name}:${relation.sourceType.name}:'
          '${normalizeGraphLabel(relation.sourceLabel)}:'
          '${relation.targetType.name}:${normalizeGraphLabel(relation.targetLabel)}';
      final current = byKey[key];
      if (current == null || relation.confidence > current.confidence) {
        byKey[key] = relation;
      }
    }
    return List.unmodifiable(byKey.values);
  }
}

class _EntityPattern {
  const _EntityPattern(this.type, this.expression, this.prototype);

  final SemanticEntityType type;
  final RegExp expression;
  final Map<String, int> prototype;
}
