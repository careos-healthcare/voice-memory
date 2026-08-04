import '../../core/graph/personal_knowledge_graph.dart';
import '../../features/ai_engines/on_device_extraction_engine.dart';
import '../../features/ai_engines/models/hypothesis_evolution.dart';
import '../../models/journal_entry.dart';
import 'ai_cost_telemetry.dart';
import 'local_semantic_store.dart';

enum HybridAiOperation {
  entryIngestion,
  quickIntentClassification,
  localSemanticSearch,
  complexSemanticSearch,
  monthlyLifeStorySynthesis,
  crossTemporalReasoning,
  deepExplainability,
  scheduledBackgroundBatch,
}

enum HybridAiTier { onDevice, cloudEscalated, offlineFallback, cloudSkipped }

class HybridAiRequest {
  const HybridAiRequest({
    required this.operation,
    this.entry,
    this.existingGraph,
    this.query,
    this.userInitiated = false,
    this.scheduled = false,
    this.isOnline = true,
    this.estimatedOutputTokens = 256,
  });

  final HybridAiOperation operation;
  final JournalEntry? entry;
  final PersonalKnowledgeGraph? existingGraph;
  final String? query;
  final bool userInitiated;
  final bool scheduled;
  final bool isOnline;
  final int estimatedOutputTokens;

  String get estimationText => entry?.transcript ?? query ?? '';
}

class HybridCloudResult {
  const HybridCloudResult({this.payload, this.inputTokens, this.outputTokens});

  final Object? payload;
  final int? inputTokens;
  final int? outputTokens;
}

class HybridAiCloudContext {
  const HybridAiCloudContext({
    this.activeHypotheses = const [],
    this.truthAnchors = const [],
  });

  final List<HypothesisEvolution> activeHypotheses;
  final List<Map<String, dynamic>> truthAnchors;

  List<Map<String, dynamic>> get activeHypothesesJson => activeHypotheses
      .map((hypothesis) => hypothesis.toJson())
      .toList(growable: false);
}

class HybridAiRouteResult {
  const HybridAiRouteResult({
    required this.tier,
    this.localExtraction,
    this.localHits = const [],
    this.cloudPayload,
    this.activeHypotheses = const [],
  });

  final HybridAiTier tier;
  final OnDeviceExtractionResult? localExtraction;
  final List<LocalSemanticHit> localHits;
  final Object? cloudPayload;
  final List<HypothesisEvolution> activeHypotheses;
}

typedef HybridCloudExecutor = Future<HybridCloudResult> Function();
typedef ContextualHybridCloudExecutor =
    Future<HybridCloudResult> Function(HybridAiCloudContext context);

/// Cost-aware boundary between instant private processing and rare cloud work.
class HybridAiRouter {
  const HybridAiRouter({
    required OnDeviceExtractionEngine onDevice,
    required LocalSemanticStore semanticStore,
    required AiCostTelemetry telemetry,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _onDevice = onDevice,
       // ignore: prefer_initializing_formals
       _semanticStore = semanticStore,
       // ignore: prefer_initializing_formals
       _telemetry = telemetry;

  final OnDeviceExtractionEngine _onDevice;
  final LocalSemanticStore _semanticStore;
  final AiCostTelemetry _telemetry;

  bool shouldEscalate(HybridAiRequest request) {
    if (!_cloudEligible(request.operation)) return false;
    if (request.operation == HybridAiOperation.scheduledBackgroundBatch) {
      return request.scheduled;
    }
    return request.userInitiated;
  }

  Future<HybridAiRouteResult> execute(
    HybridAiRequest request, {
    HybridCloudExecutor? cloud,
    ContextualHybridCloudExecutor? cloudWithContext,
  }) async {
    final stopwatch = Stopwatch()..start();
    final estimatedTokens = _estimateCloudTokens(request);
    final wantsCloud = shouldEscalate(request);

    if (wantsCloud &&
        request.isOnline &&
        (cloud != null || cloudWithContext != null)) {
      final activeHypotheses = await _semanticStore.activeHypotheses();
      final truthAnchors = await _semanticStore.truthAnchorsJson();
      final context = HybridAiCloudContext(
        activeHypotheses: activeHypotheses,
        truthAnchors: truthAnchors,
      );
      final result = cloudWithContext != null
          ? await cloudWithContext(context)
          : await cloud!();
      stopwatch.stop();
      final cloudTokens =
          (result.inputTokens ?? 0) + (result.outputTokens ?? 0);
      await _telemetry.record(
        operation: request.operation.name,
        route: AiExecutionRoute.cloud,
        latency: stopwatch.elapsed,
        estimatedCloudTokens: cloudTokens > 0 ? cloudTokens : estimatedTokens,
      );
      return HybridAiRouteResult(
        tier: HybridAiTier.cloudEscalated,
        cloudPayload: result.payload,
        activeHypotheses: activeHypotheses,
      );
    }

    final local = await _executeLocal(request);
    stopwatch.stop();
    final tier = wantsCloud
        ? request.isOnline
              ? HybridAiTier.cloudSkipped
              : HybridAiTier.offlineFallback
        : HybridAiTier.onDevice;
    await _telemetry.record(
      operation: request.operation.name,
      route: switch (tier) {
        HybridAiTier.onDevice => AiExecutionRoute.local,
        HybridAiTier.offlineFallback => AiExecutionRoute.offlineFallback,
        HybridAiTier.cloudSkipped => AiExecutionRoute.cloudSkipped,
        HybridAiTier.cloudEscalated => AiExecutionRoute.cloud,
      },
      latency: stopwatch.elapsed,
      estimatedTokensSaved: estimatedTokens,
    );
    return HybridAiRouteResult(
      tier: tier,
      localExtraction: local.extraction,
      localHits: local.hits,
    );
  }

  Future<void> indexPersistedEntry(
    JournalEntry entry,
    PersonalKnowledgeGraph graph,
  ) async {
    final stopwatch = Stopwatch()..start();
    final changed = await _semanticStore.upsertFromGraph(entry, graph);
    stopwatch.stop();
    if (!changed) return;
    await _telemetry.record(
      operation: HybridAiOperation.entryIngestion.name,
      route: AiExecutionRoute.local,
      latency: stopwatch.elapsed,
      estimatedTokensSaved: _estimateTextTokens(entry.transcript, 128),
    );
  }

  Future<void> reconcilePersistedEntries(
    List<JournalEntry> entries,
    PersonalKnowledgeGraph graph,
  ) async {
    final stopwatch = Stopwatch()..start();
    final changed = await _semanticStore.reconcileFromGraph(entries, graph);
    stopwatch.stop();
    if (changed == 0) return;
    final estimatedTokens = entries.fold<int>(
      0,
      (sum, entry) => sum + _estimateTextTokens(entry.transcript, 128),
    );
    await _telemetry.record(
      operation: HybridAiOperation.entryIngestion.name,
      route: AiExecutionRoute.local,
      latency: stopwatch.elapsed,
      estimatedTokensSaved: estimatedTokens,
    );
  }

  Future<void> persistHypotheses(
    Iterable<HypothesisEvolution> hypotheses,
  ) async {
    for (final hypothesis in hypotheses) {
      await _semanticStore.upsertHypothesis(hypothesis);
    }
  }

  Future<({OnDeviceExtractionResult? extraction, List<LocalSemanticHit> hits})>
  _executeLocal(HybridAiRequest request) async {
    final entry = request.entry;
    if (entry != null) {
      final extraction = await _onDevice.processEntry(
        entry,
        into: request.existingGraph,
      );
      if (!entry.isArchived &&
          !entry.keepSeparate &&
          !entry.treatAsNew &&
          entry.memorySurfacing != 'do_not_surface') {
        await _semanticStore.upsert(extraction);
      }
      return (extraction: extraction, hits: const <LocalSemanticHit>[]);
    }
    final query = request.query?.trim();
    if (query != null && query.isNotEmpty) {
      return (extraction: null, hits: await _semanticStore.search(query));
    }
    return (extraction: null, hits: const <LocalSemanticHit>[]);
  }

  static bool _cloudEligible(HybridAiOperation operation) =>
      switch (operation) {
        HybridAiOperation.complexSemanticSearch ||
        HybridAiOperation.monthlyLifeStorySynthesis ||
        HybridAiOperation.crossTemporalReasoning ||
        HybridAiOperation.deepExplainability ||
        HybridAiOperation.scheduledBackgroundBatch => true,
        HybridAiOperation.entryIngestion ||
        HybridAiOperation.quickIntentClassification ||
        HybridAiOperation.localSemanticSearch => false,
      };

  static int _estimateCloudTokens(HybridAiRequest request) =>
      _estimateTextTokens(
        request.estimationText,
        request.estimatedOutputTokens,
      );

  static int _estimateTextTokens(String text, int outputTokens) =>
      ((text.length / 4).ceil() + outputTokens.clamp(0, 8192)).clamp(
        1,
        1 << 30,
      );
}
