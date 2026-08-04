import 'dart:typed_data';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/llm/on_device_extractor.dart';
import '../../core/search/local_vector_search_engine.dart';
import '../../features/archive_evidence/comparable_evidence_text.dart';
import '../../models/journal_entry.dart';
import '../../models/local_capture_context.dart';

enum LocalEntryIntent {
  reflection,
  actionPlanning,
  commitment,
  emotionalProcessing,
  factualMemory,
}

class OnDeviceExtractionResult {
  const OnDeviceExtractionResult({
    required this.entryId,
    required this.graph,
    required this.intent,
    required this.tags,
    required this.primaryTopics,
    required this.embedding,
  });

  final String entryId;
  final PersonalKnowledgeGraph graph;
  final LocalEntryIntent intent;
  final Set<String> tags;
  final List<String> primaryTopics;
  final Float32List embedding;
}

/// Local-only transcript parser used by the zero-cost routing tier.
///
/// It delegates broad entity recognition to the existing compact semantic
/// extractor, then adds deterministic action, promise, emotion, and topic
/// spans. Every emitted mention is an exact UTF-16 slice of user text.
class OnDeviceExtractionEngine
    implements GraphEntityExtractor, AsyncGraphEntityExtractor {
  OnDeviceExtractionEngine({
    OnDeviceSemanticExtractor? semanticExtractor,
    LocalEmbeddingDriver embeddingDriver = const HashedLocalEmbeddingDriver(),
  }) : _semanticExtractor =
           semanticExtractor ?? const OnDeviceSemanticExtractor(),
       // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _embeddingDriver = embeddingDriver {
    graphEngine = PersonalKnowledgeGraphEngine(extractor: this);
  }

  final OnDeviceSemanticExtractor _semanticExtractor;
  final LocalEmbeddingDriver _embeddingDriver;
  late final PersonalKnowledgeGraphEngine graphEngine;

  Future<OnDeviceExtractionResult> processEntry(
    JournalEntry entry, {
    PersonalKnowledgeGraph? into,
  }) async {
    final text = ComparableEvidenceText.userText(entry);
    final graph = await graphEngine.ingestTranscriptionAsync(entry, into: into);
    final extraction = await extractAsync(
      text: text,
      localCaptureContext: entry.localCaptureContext,
    );
    final topics = extraction.entities
        .where((item) => item.type == NodeType.topic)
        .map((item) => normalizeGraphLabel(item.label))
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(5)
        .toList(growable: false);
    final tags = {
      for (final item in extraction.entities) item.type.name,
      _classifyIntent(text).name,
    };
    return OnDeviceExtractionResult(
      entryId: entry.id,
      graph: graph,
      intent: _classifyIntent(text),
      tags: Set.unmodifiable(tags),
      primaryTopics: topics,
      embedding: _embeddingDriver.embed(text),
    );
  }

  @override
  GraphExtraction extract({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) => _augment(
    text,
    _semanticExtractor.extract(
      text: text,
      localCaptureContext: localCaptureContext,
    ),
  );

  @override
  Future<GraphExtraction> extractAsync({
    required String text,
    LocalCaptureContext? localCaptureContext,
  }) async => _augment(
    text,
    await _semanticExtractor.extractAsync(
      text: text,
      localCaptureContext: localCaptureContext,
    ),
  );

  GraphExtraction _augment(String text, GraphExtraction base) {
    if (text.trim().isEmpty) return base;
    final entities = [...base.entities];
    _addMatches(entities, text, _actionPattern, NodeType.actionItem, 0.88);
    _addMatches(entities, text, _promisePattern, NodeType.promise, 0.92);
    _addMatches(entities, text, _emotionPattern, NodeType.emotion, 0.84);
    _addMatches(entities, text, _interactionPattern, NodeType.interaction, 0.9);
    _addMatches(entities, text, _topicPattern, NodeType.topic, 0.78);

    final unique = <String, GraphEntityMention>{};
    for (final item in entities) {
      unique['${item.type.name}:${item.startUtf16}:${item.endUtf16}:'
              '${normalizeGraphLabel(item.label)}'] =
          item;
    }
    final values = unique.values.toList(growable: false);
    final relations = [...base.relations];
    for (final interaction in values.where(
      (item) => item.type == NodeType.interaction,
    )) {
      final person = _nearest(
        interaction,
        values.where((item) => item.type == NodeType.person),
      );
      final emotion = _nearest(
        interaction,
        values.where((item) => item.type == NodeType.emotion),
      );
      if (person == null || emotion == null) continue;
      relations
        ..add(
          _triadRelation(text, person, interaction, EdgeType.interactedWith),
        )
        ..add(
          _triadRelation(text, interaction, emotion, EdgeType.evokedEmotion),
        );
    }
    return GraphExtraction(entities: values, relations: relations);
  }

  static GraphEntityMention? _nearest(
    GraphEntityMention anchor,
    Iterable<GraphEntityMention> candidates,
  ) {
    final ordered = candidates.toList()
      ..sort(
        (a, b) => (a.startUtf16 - anchor.startUtf16).abs().compareTo(
          (b.startUtf16 - anchor.startUtf16).abs(),
        ),
      );
    return ordered.firstOrNull;
  }

  static GraphRelationMention _triadRelation(
    String text,
    GraphEntityMention source,
    GraphEntityMention target,
    EdgeType type,
  ) {
    final start = source.startUtf16 < target.startUtf16
        ? source.startUtf16
        : target.startUtf16;
    final end = source.endUtf16 > target.endUtf16
        ? source.endUtf16
        : target.endUtf16;
    return GraphRelationMention(
      sourceType: source.type,
      sourceLabel: source.label,
      targetType: target.type,
      targetLabel: target.label,
      type: type,
      isDirected: true,
      confidence: 0.88,
      excerpt: text.substring(start, end),
      startUtf16: start,
      endUtf16: end,
    );
  }

  static void _addMatches(
    List<GraphEntityMention> target,
    String text,
    RegExp pattern,
    NodeType type,
    double confidence,
  ) {
    for (final match in pattern.allMatches(text)) {
      final excerpt = match.group(0)?.trim();
      if (excerpt == null || excerpt.isEmpty) continue;
      final leadingWhitespace =
          match.group(0)!.length - match.group(0)!.trimLeft().length;
      final start = match.start + leadingWhitespace;
      target.add(
        GraphEntityMention(
          type: type,
          label: excerpt,
          confidence: confidence,
          excerpt: excerpt,
          startUtf16: start,
          endUtf16: start + excerpt.length,
        ),
      );
    }
  }

  static LocalEntryIntent _classifyIntent(String text) {
    if (_promisePattern.hasMatch(text)) return LocalEntryIntent.commitment;
    if (_actionPattern.hasMatch(text)) return LocalEntryIntent.actionPlanning;
    if (_emotionPattern.hasMatch(text)) {
      return LocalEntryIntent.emotionalProcessing;
    }
    if (RegExp(
      r'\b(?:today|yesterday|remember|happened)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return LocalEntryIntent.factualMemory;
    }
    return LocalEntryIntent.reflection;
  }

  static final RegExp _actionPattern = RegExp(
    r"\b(?:I need to|I have to|I must|todo|remember to)\b[^.!?\n]*",
    caseSensitive: false,
  );
  static final RegExp _promisePattern = RegExp(
    r"\b(?:I promise|I will|I'll|I commit to)\b[^.!?\n]*",
    caseSensitive: false,
  );
  static final RegExp _emotionPattern = RegExp(
    r'\b(?:happy|joyful|calm|excited|sad|angry|afraid|anxious|worried|'
    r'overwhelmed|burned out|grateful|lonely|hopeful|frustrated)\b',
    caseSensitive: false,
  );
  static final RegExp _interactionPattern = RegExp(
    r"\b(?:met|called|texted|visited|argued with|spoke (?:with|to)|"
    r"talked (?:with|to)|worked with|had (?:dinner|lunch|coffee) with)\b"
    r"[^.!?\n]*",
    caseSensitive: false,
  );
  static final RegExp _topicPattern = RegExp(
    r'\b(?:work|career|family|health|money|relationship|creativity|'
    r'travel|home|friendship|parenting|study|business)\b',
    caseSensitive: false,
  );
}
