import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../features/archive_semantic_search/archive_semantic_search_engine.dart';
import '../features/archive_semantic_search/archive_semantic_search_models.dart';
import '../services/app_services.dart';
import '../theme/app_spacing.dart';
import '../theme/archive_semantic_colors.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/accessibility/accessible_primary_surface.dart';

class ArchiveSemanticSearchScreen extends StatefulWidget {
  const ArchiveSemanticSearchScreen({super.key, this.engine, this.searcher});

  final ArchiveSemanticSearchEngine? engine;
  final Future<ArchiveSemanticSearchPage> Function(String query)? searcher;

  @override
  State<ArchiveSemanticSearchScreen> createState() =>
      _ArchiveSemanticSearchScreenState();
}

class _ArchiveSemanticSearchScreenState
    extends State<ArchiveSemanticSearchScreen> {
  static const examples = [
    'Show me every time I mentioned work burnout',
    'When was I happiest?',
  ];

  final TextEditingController _controller = TextEditingController();
  late final Future<ArchiveSemanticSearchPage> Function(String query) _runQuery;
  ArchiveSemanticSearchPage? _page;
  Object? _error;
  bool _searching = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _runQuery =
        widget.searcher ??
        (widget.engine ?? AppServices.instance.archiveSemanticSearch).search;
  }

  @override
  void dispose() {
    _request++;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? example]) async {
    if (example != null) _controller.text = example;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final request = ++_request;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final page = await _runQuery(text);
      if (!mounted || request != _request) return;
      setState(() {
        _page = page;
        _searching = false;
      });
    } on Object catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ArchiveSemanticColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text('Search your Archive'),
        ),
        backgroundColor: colors.background,
      ),
      body: AccessiblePrimarySurface(
        label: 'Semantic archive search',
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Semantics(
                label: 'Private local search',
                child: Text(
                  'Searched on this device. Queries are not saved or sent.',
                  style: VoiceMemoryTypography.bodyStyle(
                    color: colors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('archive-semantic-search-field'),
                controller: _controller,
                maxLength: 500,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Private on-device journal search',
                  hintText:
                      'Ask about your journal, for example entries about work',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    key: const Key('archive-semantic-search-submit'),
                    tooltip: 'Search archive',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _searching ? null : _search,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              Semantics(
                container: true,
                label: 'Example search questions',
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final example in examples)
                      Semantics(
                        button: true,
                        enabled: !_searching,
                        label: 'Search example: $example',
                        child: ExcludeSemantics(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: ActionChip(
                              label: Text(example),
                              tooltip: 'Search: $example',
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              onPressed: _searching
                                  ? null
                                  : () => _search(example),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _status(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status() {
    if (_searching) {
      return _liveStatus(
        'Searching and updating the private local index',
        const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.sm),
            Text('Searching and updating the private local index…'),
          ],
        ),
      );
    }
    if (_error != null) {
      const message =
          'Local search could not be completed. Your journal was not changed.';
      return Column(
        children: [
          _liveStatus(message, const Text(message)),
          TextButton(
            key: const Key('archive-semantic-search-retry'),
            onPressed: _searching ? null : _search,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Try again'),
          ),
        ],
      );
    }
    final page = _page;
    if (page == null) {
      return _liveStatus(
        'Search is ready',
        const Text('Try a question above to search every journal entry.'),
      );
    }
    if (page.results.isEmpty) {
      final message = page.insufficientReason ?? 'No matching entries found.';
      return _liveStatus(message, Text(message));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _liveStatus(
          '${page.totalResults} '
          '${page.totalResults == 1 ? 'result' : 'results'} found',
          Text(
            '${page.totalResults} '
            '${page.totalResults == 1 ? 'result' : 'results'}',
            style: VoiceMemoryTypography.cardTitleStyle(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          page.query.explanation,
          style: VoiceMemoryTypography.bodyStyle(
            color: ArchiveSemanticColors.of(context).secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final result in page.results) _resultCard(result),
      ],
    );
  }

  Widget _resultCard(ArchiveSemanticSearchResult result) {
    final date = DateFormat.yMMMd().format(result.date);
    final mood = result.mood == null ? '' : ', mood ${result.mood}';
    final label =
        'Journal result from $date$mood. '
        'Match reason: ${result.reason}. '
        'Snippet: ${result.snippet}';
    final openAction = const CustomSemanticsAction(label: 'Open result');
    final explainAction = const CustomSemanticsAction(
      label: 'Repeat match explanation',
    );
    return Card(
      key: Key('archive-semantic-result-${result.entryId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        label: label,
        hint: 'Opens the journal entry',
        customSemanticsActions: {
          openAction: () => context.push('/entry/${result.entryId}'),
          explainAction: () => _announce('Match reason: ${result.reason}'),
        },
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => context.push('/entry/${result.entryId}'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(date)),
                        if (result.mood != null)
                          Chip(label: Text(result.mood!)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _highlightedSnippet(result),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      result.reason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ArchiveSemanticColors.of(context).secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _highlightedSnippet(ArchiveSemanticSearchResult result) {
    final start = result.highlightStartUtf16.clamp(0, result.snippet.length);
    final end = result.highlightEndUtf16.clamp(start, result.snippet.length);
    final normal = DefaultTextStyle.of(context).style;
    final scheme = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: result.snippet.substring(0, start), style: normal),
          TextSpan(
            text: result.snippet.substring(start, end),
            style: normal.copyWith(
              fontWeight: FontWeight.w700,
              color: highContrast
                  ? scheme.onPrimary
                  : scheme.onTertiaryContainer,
              backgroundColor: highContrast
                  ? scheme.primary
                  : scheme.tertiaryContainer,
            ),
          ),
          TextSpan(text: result.snippet.substring(end), style: normal),
        ],
      ),
    );
  }

  Widget _liveStatus(String label, Widget visual) => Semantics(
    container: true,
    liveRegion: true,
    label: label,
    child: ExcludeSemantics(child: visual),
  );

  void _announce(String message) {
    if (!MediaQuery.supportsAnnounceOf(context)) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }
}
