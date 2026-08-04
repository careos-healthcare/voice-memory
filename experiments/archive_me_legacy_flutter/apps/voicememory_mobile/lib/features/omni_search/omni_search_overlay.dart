import 'dart:ui';

import 'package:flutter/material.dart';

import '../../shared/ui/citation_playback_widget.dart';
import 'omni_search_engine.dart';
import 'search_query_translator.dart';
import 'search_intent.dart';

typedef OmniSearchEngineLoader = Future<OmniSearchEngine> Function();

class OmniSearchLauncher extends StatelessWidget {
  const OmniSearchLauncher({
    super.key,
    required this.engineLoader,
    required this.translator,
    this.fallbackTranslator = const LocalSearchQueryTranslator(),
    this.onGraphNodeSelected,
    this.onAudioMemorySelected,
  });

  final OmniSearchEngineLoader engineLoader;
  final SearchQueryTranslator translator;
  final SearchQueryTranslator fallbackTranslator;
  final ValueChanged<OmniSearchCandidate>? onGraphNodeSelected;
  final ValueChanged<OmniSearchCandidate>? onAudioMemorySelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Search your private Memory Graph',
    child: InkWell(
      key: const Key('omni_search_launcher'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => _open(context),
      child: Container(
        key: const Key('life_os_graph_search_bar'),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.manage_search_rounded),
            SizedBox(width: 12),
            Expanded(child: Text('Search your whole Memory Graph')),
          ],
        ),
      ),
    ),
  );

  Future<void> _open(BuildContext context) async {
    final engine = await engineLoader();
    if (!context.mounted) return;
    final result = await showGeneralDialog<OmniSearchCandidate>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Memory Graph search',
      barrierColor: Colors.black.withValues(alpha: .5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => OmniSearchOverlay(
        engine: engine,
        translator: translator,
        fallbackTranslator: fallbackTranslator,
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, -.12),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
    if (result == null) return;
    switch (result.kind) {
      case OmniSearchResultKind.graphNode:
        onGraphNodeSelected?.call(result);
        return;
      case OmniSearchResultKind.audioMemory:
        onAudioMemorySelected?.call(result);
        return;
      case OmniSearchResultKind.activeTheory:
        return;
    }
  }
}

class OmniSearchOverlay extends StatefulWidget {
  const OmniSearchOverlay({
    super.key,
    required this.engine,
    required this.translator,
    this.fallbackTranslator = const LocalSearchQueryTranslator(),
  });

  final OmniSearchEngine engine;
  final SearchQueryTranslator translator;
  final SearchQueryTranslator fallbackTranslator;

  @override
  State<OmniSearchOverlay> createState() => _OmniSearchOverlayState();
}

class _OmniSearchOverlayState extends State<OmniSearchOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  OmniSearchResults? _results;
  bool _searching = false;
  bool _usedLocalTranslation = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String rawQuery) async {
    if (rawQuery.trim().isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _error = null;
      _usedLocalTranslation = false;
    });
    try {
      late final SearchIntent intent;
      try {
        intent = await widget.translator.translate(rawQuery);
      } catch (_) {
        intent = await widget.fallbackTranslator.translate(rawQuery);
        _usedLocalTranslation = true;
      }
      final results = await widget.engine.search(intent);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          widthFactor: .96,
          heightFactor: .9,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Material(
                key: const Key('omni_search_overlay'),
                color: colors.surface.withValues(alpha: .9),
                child: Column(
                  children: [
                    _SearchHeader(
                      controller: _controller,
                      focusNode: _focusNode,
                      searching: _searching,
                      onSubmitted: _search,
                    ),
                    if (_usedLocalTranslation)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 16),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Offline intent parsing · all search stayed on this device',
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return const Center(
        child: Text(
          'Search is unavailable. Your private data was not changed.',
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const _SearchHint();
    }
    if (results.isEmpty) {
      return const Center(
        child: Text('No private memories matched this search.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _ResultSection(
          title: 'Graph Nodes',
          icon: Icons.hub_outlined,
          results: results.graphNodes,
          onTap: _select,
        ),
        _ResultSection(
          title: 'Audio Memories',
          icon: Icons.graphic_eq_rounded,
          results: results.audioMemories,
          onTap: _select,
          useHero: true,
        ),
        _ResultSection(
          title: 'Active Theories',
          icon: Icons.timeline_rounded,
          results: results.activeTheories,
          onTap: _select,
        ),
      ],
    );
  }

  void _select(OmniSearchCandidate candidate) =>
      Navigator.of(context).pop(candidate);
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Close search',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        Expanded(
          child: TextField(
            key: const Key('omni_search_field'),
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            decoration: const InputDecoration(
              hintText: 'When was I happiest around work?',
              labelText: 'Ask your archive',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(
          key: const Key('omni_search_submit'),
          tooltip: 'Search',
          onPressed: searching ? null : () => onSubmitted(controller.text),
          icon: const Icon(Icons.search),
        ),
      ],
    ),
  );
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.icon,
    required this.results,
    required this.onTap,
    this.useHero = false,
  });

  final String title;
  final IconData icon;
  final List<OmniSearchResult> results;
  final ValueChanged<OmniSearchCandidate> onTap;
  final bool useHero;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
          child: Row(
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        for (final result in results)
          _SearchResultTile(
            result: result,
            onTap: () => onTap(result.candidate),
            useHero: useHero,
          ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.onTap,
    required this.useHero,
  });

  final OmniSearchResult result;
  final VoidCallback onTap;
  final bool useHero;

  @override
  Widget build(BuildContext context) {
    final candidate = result.candidate;
    final tile = Card(
      child: ListTile(
        key: Key('omni_result_${candidate.kind.name}_${candidate.id}'),
        onTap: onTap,
        title: _HighlightedText(
          text: candidate.title,
          terms: candidate.matchedTerms,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _HighlightedText(
              text: candidate.snippet,
              terms: candidate.matchedTerms,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 5),
            Text(
              result.matchReasons.join(' + '),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        trailing: Icon(
          candidate.kind == OmniSearchResultKind.audioMemory
              ? Icons.play_circle_outline
              : Icons.arrow_forward_rounded,
        ),
      ),
    );
    if (!useHero) return tile;
    final citation = candidate.citation;
    return Hero(
      tag: citation == null
          ? 'omni-search-audio-${candidate.id}'
          : citationHeroTag(citation),
      child: tile,
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.terms,
    required this.style,
  });

  final String text;
  final List<String> terms;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final matches = <({int start, int end})>[];
    final lower = text.toLowerCase();
    for (final term in terms.where((term) => term.isNotEmpty)) {
      var start = lower.indexOf(term.toLowerCase());
      while (start >= 0) {
        matches.add((start: start, end: start + term.length));
        start = lower.indexOf(term.toLowerCase(), start + term.length);
      }
    }
    matches.sort((a, b) => a.start.compareTo(b.start));
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) continue;
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onTertiaryContainer,
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(
      TextSpan(
        style: style,
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Text(
        'Search people, emotions, habits, audio memories, and evolving theories. '
        'Your archive is ranked locally on this device.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
