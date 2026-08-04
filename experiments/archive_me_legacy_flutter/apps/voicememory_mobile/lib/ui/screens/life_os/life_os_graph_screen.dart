import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/engines/evidence_reference.dart';
import '../../../core/graph/graph_node.dart';
import '../../../core/graph/personal_knowledge_graph.dart';
import '../../../core/providers/life_os_providers.dart';
import '../../../features/memory_graph/memory_graph_canvas.dart';
import '../../../features/cold_start/cold_start_engine.dart';
import '../../../features/omni_search/omni_search_engine.dart';
import '../../../features/omni_search/omni_search_overlay.dart';
import '../../../features/omni_search/search_graph_focus.dart';
import '../../../features/omni_search/search_query_translator.dart';
import '../../../models/journal_entry.dart';
import '../../../router/route_catalog.dart';
import '../../../services/app_services.dart';
import '../../../services/app_services_providers.dart';
import '../../../services/hallucination_guard/hallucination_guard_service.dart';
import '../../../shared/ui/citation_playback_widget.dart';
import '../../../widgets/accessibility/accessible_primary_surface.dart';

class LifeOsGraphScreen extends ConsumerWidget {
  const LifeOsGraphScreen({super.key, this.view, this.nodeId});

  static const route = '/life-os/graph';

  final String? view;
  final String? nodeId;

  bool get _isEvidenceView => view == 'evidence';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(knowledgeGraphProvider);
    final entries =
        ref.watch(journalEntriesStreamProvider).value ?? const <JournalEntry>[];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('memory_graph_back'),
          tooltip: 'Back to Archive',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteCatalog.archiveHome);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_isEvidenceView ? 'Evidence mentions' : 'Memory Graph'),
      ),
      body: AccessiblePrimarySurface(
        label: _isEvidenceView
            ? 'Knowledge graph evidence mentions'
            : 'Personal knowledge graph',
        child: SafeArea(
          child: graph.when(
            loading: () => const _GraphLoading(),
            error: (error, stackTrace) => _GraphError(
              onRetry: () => ref.invalidate(knowledgeGraphProvider),
            ),
            data: (value) => _isEvidenceView
                ? _EvidenceTimeline(graph: value, nodeId: nodeId)
                : _GraphCanvas(graph: value, entries: entries),
          ),
        ),
      ),
    );
  }
}

class _GraphLoading extends StatelessWidget {
  const _GraphLoading();

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: 'Loading visual knowledge graph',
      child: const CircularProgressIndicator(),
    ),
  );
}

class _GraphError extends StatelessWidget {
  const _GraphError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: 'Visual knowledge graph could not be loaded',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Visual knowledge graph could not be loaded.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _GraphCanvas extends ConsumerStatefulWidget {
  const _GraphCanvas({required this.graph, required this.entries});

  final PersonalKnowledgeGraph graph;
  final List<JournalEntry> entries;

  @override
  ConsumerState<_GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends ConsumerState<_GraphCanvas> {
  final SearchGraphFocus _searchFocus = SearchGraphFocus();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  Future<OmniSearchEngine> _loadEngine() async {
    final services = AppServices.instance;
    return OmniSearchEngine(
      lexicalSource: SqliteOmniLexicalSource(
        loadGraph: () async => widget.graph,
        journalStore: services.journalStore,
      ),
      semanticSource: VectorOmniSemanticSource(
        loadGraph: () async => widget.graph,
        journalStore: services.journalStore,
        semanticIndexStore: services.archiveSemanticIndexStore,
      ),
      theorySource: ActiveTheoryOmniSource(services.localSemanticStore),
    );
  }

  SearchQueryTranslator get _translator {
    if (!AppServices.isInitialized) return const LocalSearchQueryTranslator();
    final services = AppServices.instance;
    return CloudSearchQueryTranslator(
      transport: services.apiTransport,
      attest: services.attest,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OmniSearchLauncher(
            engineLoader: _loadEngine,
            translator: _translator,
            onGraphNodeSelected: (candidate) {
              final node = candidate.node;
              if (node != null) _searchFocus.focus(node.id);
            },
            onAudioMemorySelected: (candidate) =>
                _showAudioMemory(context, candidate),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.graph.nodes.length} entities · '
            '${widget.graph.edges.length} connections',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (widget.graph.nodes.isEmpty)
            _EmptyGraphPrompt(
              onRecord: () => context.go(RouteCatalog.recordHome),
            )
          else
            FutureBuilder<ColdStartSeedData?>(
              future: AppServices.isInitialized
                  ? ColdStartSeedStore(AppServices.instance.prefs).load()
                  : Future.value(),
              builder: (context, snapshot) => MemoryGraphCanvas(
                graph: widget.graph,
                entries: widget.entries,
                seedData: snapshot.data,
                searchGraphFocus: _searchFocus,
                showFirstEntryBurst: widget.entries.length == 1,
                onSparkSelected: (spark) {
                  final route = Uri(
                    path: RouteCatalog.recordHome,
                    queryParameters: {'prompt': spark.prompt, 'autostart': '1'},
                  );
                  context.go(route.toString());
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAudioMemory(
    BuildContext context,
    OmniSearchCandidate candidate,
  ) async {
    final citation = candidate.citation;
    if (citation == null || !AppServices.isInitialized) return;
    await openCitationPlayback(
      context,
      citation: citation,
      guard: HallucinationGuardService(
        loadEntry: AppServices.instance.journalStore.getById,
      ),
    );
  }
}

class _EmptyGraphPrompt extends StatelessWidget {
  const _EmptyGraphPrompt({required this.onRecord});

  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'No knowledge graph entities yet',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Record your first entries to begin building your personal '
              'knowledge graph.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.mic_none),
              label: const Text('Record'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EvidenceTimeline extends StatelessWidget {
  const _EvidenceTimeline({required this.graph, required this.nodeId});

  final PersonalKnowledgeGraph graph;
  final String? nodeId;

  @override
  Widget build(BuildContext context) {
    GraphNode? node;
    for (final candidate in graph.nodes) {
      if (candidate.id == nodeId) {
        node = candidate;
        break;
      }
    }
    if (node == null) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: 'Evidence entity not found',
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This entity is no longer available in your knowledge graph.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final references = referencesForNode(graph, node);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          header: true,
          child: Text(
            node.label,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Chronological evidence mentions. Entry IDs and dates only.',
        ),
        const SizedBox(height: 16),
        if (references.isEmpty)
          const Text('No evidence mentions are available for this entity.')
        else
          ...references.map(
            (reference) => Card(
              child: Semantics(
                button: true,
                label:
                    '${_date(reference.observedAt)}, '
                    'Entry ID ${reference.entryId}',
                child: ExcludeSemantics(
                  child: ListTile(
                    title: Text(_date(reference.observedAt)),
                    subtitle: Text('Entry ID: ${reference.entryId}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/entry/${Uri.encodeComponent(reference.entryId)}',
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
