import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/journal_entry.dart';
import '../features/discover/discover_local.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../features/search/voice_memory_search.dart';
import '../features/theme_tracking/theme_tracker_service.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../features/timeline/timeline_models.dart';
import '../services/app_services.dart';
import '../design/empty_archive_experience.dart';
import '../widgets/empty_states/search_empty_state.dart';
import '../design/user_facing_date.dart';
import '../theme/app_theme.dart';
import '../widgets/search_highlight_text.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _SearchSortOrder { newest, oldest }

class _SearchScreenState extends State<SearchScreen> {
  static const Duration _debounce = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  VoiceMemorySearchIndex? _index;
  List<SearchResult> _results = const [];
  bool _indexLoading = true;
  bool _searchLoading = false;
  String _query = '';
  Timer? _debounceTimer;
  int _searchGeneration = 0;
  _SearchSortOrder _sortOrder = _SearchSortOrder.newest;
  String? _monthFilter;

  @override
  void initState() {
    super.initState();
    _loadIndex();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadIndex() async {
    final peek = peekJournalEntriesSync(AppServices.instance.journalStore);
    if (isIntentionalEmptyArchive(peek)) {
      if (!mounted) return;
      setState(() {
        _index = VoiceMemorySearchIndex(
          entries: peek,
          archiveState: buildArchiveStateObjectV3(entries: peek),
          discoverFeed: DiscoverLocalEngine.build(
            entries: peek,
            baselineThemes: null,
          ),
        );
        _indexLoading = false;
      });
      return;
    }

    setState(() => _indexLoading = true);
    try {
      final s = AppServices.instance;
      final index = await buildVoiceMemorySearchIndex(
        loadEntries: s.journal.loadAll,
        prefs: s.prefs,
      );
      if (!mounted) return;
      setState(() {
        _index = index;
        _indexLoading = false;
      });
      if (_query.trim().isNotEmpty) {
        _runSearch(_query);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _indexLoading = false);
    }
  }

  void _onQueryChanged() {
    final next = _controller.text;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() => _query = next);
      _runSearch(next);
    });
  }

  void _runSearch(String rawQuery) {
    final generation = ++_searchGeneration;
    final index = _index;
    if (index == null) return;

    setState(() => _searchLoading = true);

    final results = searchArchiveMe(index, rawQuery);

    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _results = results;
      _searchLoading = false;
    });
  }

  void _openResult(SearchResult result) {
    context.push(result.route);
  }

  DateTime? _resultDate(SearchResult result) {
    if (result.type != SearchResultType.recording) return null;
    final entries = _index?.entries ?? const [];
    for (final e in entries) {
      if (e.id == result.id) return e.createdAt;
    }
    return null;
  }

  List<SearchResult> _filteredSortedResults() {
    var list = [..._results];
    if (_monthFilter != null) {
      list = list.where((r) {
        final d = _resultDate(r);
        if (d == null) return true;
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        return key == _monthFilter;
      }).toList();
    }
    list.sort((a, b) {
      final da = _resultDate(a);
      final db = _resultDate(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return _sortOrder == _SearchSortOrder.newest
          ? db.compareTo(da)
          : da.compareTo(db);
    });
    return list;
  }

  List<String> _availableMonthFilters() {
    final keys = <String>{};
    for (final r in _results) {
      final d = _resultDate(r);
      if (d == null) continue;
      keys.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    final sorted = keys.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  String _monthFilterLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return key;
    return '${timelineMonthLabel(month)} $year';
  }

  List<({String? monthKey, SearchResult? result})> _groupedResults(
    List<SearchResult> sorted,
  ) {
    final out = <({String? monthKey, SearchResult? result})>[];
    String? lastMonth;
    for (final r in sorted) {
      final d = _resultDate(r);
      final monthKey = d == null
          ? null
          : '${d.year}-${d.month.toString().padLeft(2, '0')}';
      if (monthKey != null && monthKey != lastMonth) {
        out.add((monthKey: monthKey, result: null));
        lastMonth = monthKey;
      }
      out.add((monthKey: null, result: r));
    }
    return out;
  }

  Widget _searchControls() {
    final months = _availableMonthFilters();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_SearchSortOrder>(
            segments: const [
              ButtonSegment(
                value: _SearchSortOrder.newest,
                label: Text('Newest'),
              ),
              ButtonSegment(
                value: _SearchSortOrder.oldest,
                label: Text('Oldest'),
              ),
            ],
            selected: {_sortOrder},
            onSelectionChanged: (s) {
              setState(() => _sortOrder = s.first);
            },
          ),
          if (months.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _monthFilter,
              decoration: const InputDecoration(
                labelText: 'Date',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All dates'),
                ),
                for (final m in months)
                  DropdownMenuItem<String?>(
                    value: m,
                    child: Text(_monthFilterLabel(m)),
                  ),
              ],
              onChanged: (v) => setState(() => _monthFilter = v),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(SearchResultType type) => switch (type) {
    SearchResultType.recording => Icons.mic,
    SearchResultType.archiveBelief => Icons.inventory_2_outlined,
    SearchResultType.discovery => Icons.explore_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final showLoading = _indexLoading || (_searchLoading && query.isNotEmpty);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Search'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Transcripts, beliefs, discoveries, titles, tags…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _query = '';
                            _results = const [];
                            _searchLoading = false;
                          });
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (showLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (query.isEmpty)
            Expanded(
              child: buildSearchEmptyQueryChild(
                entries: _index?.entries ?? const [],
                idleWhenSearchable: const _SearchIdleState(),
              ),
            )
          else if (_results.isEmpty)
            Expanded(
              child: _SearchNoResultsState(
                index: _index,
                onTapRoute: (route) => context.push(route),
              ),
            )
          else ...[
            _searchControls(),
            Expanded(
              child: Builder(
                builder: (context) {
                  final sorted = _filteredSortedResults();
                  final grouped = _groupedResults(sorted);
                  if (sorted.isEmpty) {
                    return const _SearchNoMatchesState();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final row = grouped[index];
                      if (row.monthKey != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            _monthFilterLabel(row.monthKey!),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        );
                      }
                      final result = row.result!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          label: 'Search result, ${result.typeLabel}',
                          child: Material(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () => _openResult(result),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (result.subtitle.isNotEmpty) ...[
                                      Text(
                                        result.subtitle,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.foreground,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    Row(
                                      children: [
                                        Icon(
                                          _iconFor(result.type),
                                          size: 18,
                                          color: AppTheme.muted,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          result.typeLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.muted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SearchHighlightText(
                                      text: result.title,
                                      query: query,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 6),
                                    SearchHighlightText(
                                      text: result.snippet,
                                      query: query,
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchIdleState extends StatelessWidget {
  const _SearchIdleState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: AppTheme.muted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              EmptyArchiveCopy.searchIdleTitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              EmptyArchiveCopy.searchIdleBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchNoMatchesState extends StatelessWidget {
  const _SearchNoMatchesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppTheme.muted),
            SizedBox(height: 16),
            Text(
              'No matches found',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, height: 1.45),
            ),
            SizedBox(height: 8),
            Text(
              'Try different words or clear the date filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchNoResultsState extends StatelessWidget {
  const _SearchNoResultsState({required this.index, required this.onTapRoute});

  final VoiceMemorySearchIndex? index;
  final void Function(String route) onTapRoute;

  @override
  Widget build(BuildContext context) {
    final entries = index?.entries ?? const [];
    final recent = [...entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentSlice = recent.take(4).toList();

    final themes = index == null
        ? const <String>[]
        : const ThemeTrackerService()
              .track(entries: entries)
              .topThemes
              .map((t) => t.name)
              .take(4)
              .toList();

    final archive = index?.archiveState;
    final beliefLine = archive?.belief?.trim();
    final beliefPreview = (beliefLine != null && beliefLine.isNotEmpty)
        ? beliefLine
        : archive?.changeSummary.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Icon(Icons.search_off, size: 40, color: AppTheme.muted),
        const SizedBox(height: 12),
        Text(
          'No matches found',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Try different words or clear the date filter.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted, height: 1.45),
        ),
        const SizedBox(height: 8),
        const Text(
          'Try different words, or open something from your archive below.',
          style: TextStyle(color: AppTheme.muted, height: 1.45),
        ),
        const SizedBox(height: 24),
        const Text(
          'SUGGESTIONS',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _SuggestionGroup(
          title: 'Recent recordings',
          emptyMessage: 'Record a reflection to see it here.',
          children: recentSlice.isEmpty
              ? []
              : recentSlice
                    .map(
                      (e) => _SuggestionTile(
                        icon: Icons.mic,
                        label: timelineEntryTitle(e),
                        subtitle: _formatRecordingDate(e),
                        onTap: () => onTapRoute('/entry/${e.id}'),
                      ),
                    )
                    .toList(),
        ),
        const SizedBox(height: 16),
        _SuggestionGroup(
          title: 'Top themes',
          emptyMessage:
              'Themes appear after your reflections mention patterns.',
          children: themes.isEmpty
              ? []
              : themes
                    .map(
                      (String name) => _SuggestionTile(
                        icon: Icons.label_outline,
                        label: name,
                        onTap: () => onTapRoute('/archive-belief'),
                      ),
                    )
                    .toList(),
        ),
        const SizedBox(height: 16),
        _SuggestionGroup(
          title: 'Archive belief',
          emptyMessage:
              'Your working belief will appear after enough reflections.',
          children: beliefPreview == null || beliefPreview.isEmpty
              ? []
              : [
                  _SuggestionTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Archive belief',
                    subtitle: beliefPreview.length > 100
                        ? '${beliefPreview.substring(0, 100)}…'
                        : beliefPreview,
                    onTap: () => onTapRoute('/archive-belief'),
                  ),
                ],
        ),
      ],
    );
  }

  String _formatRecordingDate(JournalEntry entry) =>
      formatUserFacingDate(entry.createdAt);
}

class _SuggestionGroup extends StatelessWidget {
  const _SuggestionGroup({
    required this.title,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Text(
            emptyMessage,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.4,
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: AppTheme.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppTheme.foreground,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
