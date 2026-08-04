import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/life_os_providers.dart';
import '../../../core/search/local_vector_search_engine.dart';

typedef GraphSearchEngineLoader = Future<LocalVectorSearchEngine> Function();
typedef GraphSearchSelection = void Function(KnowledgeGraphSearchHit hit);

/// Accessible launcher shared by the graph canvas and Archive Tools.
///
/// Provider lookup is deferred until the user explicitly opens search. This
/// keeps graph indexing out of unrelated tab builds and allows widget tests to
/// inject an isolated engine loader without initializing app services.
class GraphSearchLauncher extends StatelessWidget {
  const GraphSearchLauncher({super.key, this.engineLoader, this.onSelected});

  final GraphSearchEngineLoader? engineLoader;
  final GraphSearchSelection? onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Search personal knowledge graph',
    hint:
        'Search people, projects, emotions, decisions, outcomes, and exact evidence',
    child: ExcludeSemantics(
      child: SearchBar(
        key: const Key('life_os_graph_search_bar'),
        hintText: 'Search your life evidence',
        leading: const Icon(Icons.search),
        constraints: const BoxConstraints(minHeight: 48),
        onTap: () => _open(context),
      ),
    ),
  );

  Future<void> _open(BuildContext context) async {
    final load =
        engineLoader ??
        () => ProviderScope.containerOf(
          context,
          listen: false,
        ).read(hybridVectorSearchProvider.future);
    final hit = await showGeneralDialog<KnowledgeGraphSearchHit?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close graph search',
      barrierColor: Colors.black.withValues(alpha: .46),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          MagicalSearchOverlay(engine: load()),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: .82, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
    );
    if (hit != null && context.mounted) onSelected?.call(hit);
  }
}

class MagicalSearchOverlay extends StatefulWidget {
  const MagicalSearchOverlay({super.key, required this.engine});

  final Future<LocalVectorSearchEngine> engine;

  @override
  State<MagicalSearchOverlay> createState() => _MagicalSearchOverlayState();
}

class _MagicalSearchOverlayState extends State<MagicalSearchOverlay> {
  final _controller = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
        child: Material(
          key: const Key('magical_search_overlay'),
          elevation: 18,
          borderRadius: BorderRadius.circular(28),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SearchBar(
                    key: const Key('magical_search_field'),
                    controller: _controller,
                    autoFocus: true,
                    hintText: 'Search your life evidence',
                    leading: const Icon(Icons.auto_awesome),
                    trailing: [
                      IconButton(
                        tooltip: 'Close graph search',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Flexible(
                  child: _query.trim().isEmpty
                      ? const _GraphSearchPrompt()
                      : _GraphSearchResults(
                          engine: widget.engine,
                          query: _query,
                          onSelected: (hit) => Navigator.of(context).pop(hit),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class GraphSearchDelegate extends SearchDelegate<KnowledgeGraphSearchHit?> {
  GraphSearchDelegate({required this.engine});

  final Future<LocalVectorSearchEngine> engine;

  @override
  String get searchFieldLabel =>
      'Ask about people, projects, emotions, decisions, outcomes, or memories';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      Semantics(
        button: true,
        label: 'Clear graph search',
        child: ExcludeSemantics(
          child: IconButton(
            tooltip: 'Clear search',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => query = '',
            icon: const Icon(Icons.clear),
          ),
        ),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => Semantics(
    button: true,
    label: 'Close graph search',
    child: ExcludeSemantics(
      child: IconButton(
        tooltip: 'Back',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: () => close(context, null),
        icon: const BackButtonIcon(),
      ),
    ),
  );

  @override
  Widget buildResults(BuildContext context) => _GraphSearchResults(
    engine: engine,
    query: query,
    onSelected: (hit) => close(context, hit),
  );

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const _GraphSearchPrompt();
    }
    return _GraphSearchResults(
      engine: engine,
      query: query,
      onSelected: (hit) => close(context, hit),
    );
  }
}

class _GraphSearchPrompt extends StatelessWidget {
  const _GraphSearchPrompt();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Semantics(
        liveRegion: true,
        label:
            'Search examples: conversations with Sarah, or when did I feel '
            'anxious about my career',
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Try “Conversations with Sarah” or '
            '“When did I feel anxious about my career?”',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

class _GraphSearchResults extends StatelessWidget {
  const _GraphSearchResults({
    required this.engine,
    required this.query,
    required this.onSelected,
  });

  final Future<LocalVectorSearchEngine> engine;
  final String query;
  final ValueChanged<KnowledgeGraphSearchHit> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<LocalVectorSearchEngine>(
      future: engine,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Semantics(
              liveRegion: true,
              label: 'Life evidence search could not be loaded',
              child: const Text('Life evidence search could not be loaded.'),
            ),
          );
        }
        final searchEngine = snapshot.data;
        if (searchEngine == null) {
          return Center(
            child: Semantics(
              liveRegion: true,
              label: 'Loading private on-device search',
              child: const CircularProgressIndicator(),
            ),
          );
        }
        final hits = searchEngine.search(query);
        if (hits.isEmpty) {
          return Center(
            child: Semantics(
              liveRegion: true,
              label: 'No matching life evidence',
              child: const Text('No matching life evidence yet.'),
            ),
          );
        }
        return ListView.builder(
          key: const Key('life_os_graph_search_results'),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          itemCount: hits.length,
          itemBuilder: (context, index) {
            final hit = hits[index];
            final evidenceCount = hit.evidenceLinks.length;
            final type = _typeLabel(hit.node.type.name);
            return Semantics(
              button: true,
              label:
                  '${hit.node.label}, $type, '
                  '$evidenceCount evidence ${evidenceCount == 1 ? 'mention' : 'mentions'}',
              child: ListTile(
                key: Key('life_os_graph_search_result_${hit.node.id}'),
                leading: const ExcludeSemantics(
                  child: Icon(Icons.account_tree_outlined),
                ),
                title: Text(hit.node.label),
                subtitle: Text(
                  '$type · $evidenceCount '
                  '${evidenceCount == 1 ? 'evidence mention' : 'evidence mentions'}',
                ),
                trailing: const ExcludeSemantics(
                  child: Icon(Icons.chevron_right),
                ),
                onTap: () => onSelected(hit),
              ),
            );
          },
        );
      },
    ),
  );
}

String _typeLabel(String value) =>
    '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
