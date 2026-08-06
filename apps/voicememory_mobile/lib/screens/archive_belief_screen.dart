import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive/v1/archive_belief_load_state.dart';
import '../features/archive/v1/archive_belief_repository.dart';
import '../features/archive/v1/archive_belief_view_model.dart';
import '../services/app_services.dart';
import '../storage/journal_store.dart';
import '../theme/app_colors.dart';
import '../widgets/archive/archive_empty_state.dart';
import '../widgets/archive/archive_entry_card.dart';
import '../widgets/archive/archive_search_field.dart';
import '../widgets/archive/archive_status_banner.dart';
import '../widgets/archive/archive_verified_changes_section.dart';

/// Archive: the user's original saved moments, plus verified changes when the
/// canonical proof pipeline admits one. See `docs/ARCHIVE_SCREEN_SPEC_V1.md`.
class ArchiveBeliefScreen extends StatefulWidget {
  const ArchiveBeliefScreen({super.key, this.journalStore});

  final JournalStore? journalStore;

  @override
  State<ArchiveBeliefScreen> createState() => _ArchiveBeliefScreenState();
}

class _ArchiveBeliefScreenState extends State<ArchiveBeliefScreen> {
  late final ArchiveBeliefViewModel _viewModel = ArchiveBeliefViewModel(
    repository: ArchiveBeliefRepository(
      journalStore: widget.journalStore ?? AppServices.instance.journalStore,
    ),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    await _viewModel.reload();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openEntry(String entryId) async {
    await context.push('/entry/$entryId');
    await _reload();
  }

  void _onQueryChanged(String value) {
    setState(() => _viewModel.search.updateQuery(value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _viewModel.entries;
    final visibleEntries = _viewModel.visibleEntries;
    final loadState = _viewModel.loadState;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(title: const Text('Archive')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Your original recordings, typed moments and transcripts.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (loadState == ArchiveBeliefLoadState.offline) ...[
                      const SizedBox(height: 12),
                      const ArchiveStatusBanner(
                        key: Key('archive_offline_banner'),
                        icon: Icons.cloud_off_outlined,
                        message:
                            "You're offline. Your saved moments are stored on this "
                            'device, so they are still shown below.',
                      ),
                    ] else if (loadState == ArchiveBeliefLoadState.error) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Your archive could not be opened right now.',
                          key: const Key('archive_error_text'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              if (loadState == ArchiveBeliefLoadState.loading && entries == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    key: Key('archive_loading_indicator'),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (entries != null && entries.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverToBoxAdapter(
                    child: ArchiveEmptyState(
                      onCapture: () => context.go('/record'),
                    ),
                  ),
                )
              else ...[
                if (_viewModel.showSearchField)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          ArchiveSearchField(onQueryChanged: _onQueryChanged),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: ArchiveVerifiedChangesSection(entries: entries!),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Original moments',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                if (_viewModel.showsNoSearchResults)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'No saved moments match "${_viewModel.search.query}".',
                        key: const Key('archive_search_no_results'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = visibleEntries[index];
                          return ArchiveEntryCard(
                            entry: entry,
                            onTap: () => unawaited(_openEntry(entry.id)),
                          );
                        },
                        childCount: visibleEntries.length,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
