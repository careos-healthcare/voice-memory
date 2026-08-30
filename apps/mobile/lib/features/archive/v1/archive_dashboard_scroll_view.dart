import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/archive/ui/trust_status_footer.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/widgets/archive/archive_changes_section.dart';
import 'package:archiveme_mobile/widgets/archive/archive_changes_unavailable_notice.dart';
import 'package:archiveme_mobile/widgets/archive/archive_empty_state.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:archiveme_mobile/widgets/archive/archive_search_field.dart';
import 'package:archiveme_mobile/widgets/archive/archive_status_banner.dart';
import 'package:archiveme_mobile/widgets/archive/archive_home_choose_what_leaves_tile.dart';
import 'package:archiveme_mobile/widgets/archive/archive_verified_changes_section.dart';
import 'package:archiveme_mobile/widgets/insight_share/insight_share_exporter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Responsive [CustomScrollView] slivers for the Archive Home dashboard.
class ArchiveDashboardScrollView extends StatelessWidget {
  const ArchiveDashboardScrollView({
    required this.controller,
    required this.feed,
    required this.loadState,
    required this.visibleEntries,
    required this.showChangesUnavailable,
    required this.onRefresh,
    required this.onEntryTap,
    required this.onQueryChanged,
    required this.onCapture,
    super.key,
  });

  final ScrollController controller;
  final ArchiveFeedState feed;
  final ArchiveBeliefLoadState loadState;
  final List<JournalEntry> visibleEntries;
  final bool showChangesUnavailable;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onEntryTap;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        final sliverPadding = ArchiveResponsiveLayout.dashboardSliverPadding(
          context: context,
          viewportWidth: viewportConstraints.maxWidth,
        );

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  sliverPadding.left,
                  sliverPadding.top,
                  sliverPadding.right,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _IntroSection(
                    theme: theme,
                    loadState: loadState,
                    showChangesUnavailable: showChangesUnavailable,
                  ),
                ),
              ),
              if (loadState == ArchiveBeliefLoadState.loading &&
                  visibleEntries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    key: Key('archive_loading_indicator'),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (loadState == ArchiveBeliefLoadState.loaded &&
                  feed.archiveTotalCount == 0)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    sliverPadding.left,
                    0,
                    sliverPadding.right,
                    sliverPadding.bottom + 80,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: ArchiveEmptyState(onCapture: onCapture),
                  ),
                )
              else ...[
                if (feed.showSearchField)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      sliverPadding.left,
                      0,
                      sliverPadding.right,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          ArchiveSearchField(onQueryChanged: onQueryChanged),
                          SizedBox(height: ArchiveResponsiveLayout.gap(context)),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: sliverPadding.left),
                  sliver: SliverToBoxAdapter(
                    child: ArchiveVerifiedChangesSection(
                      proofCandidates: feed.verifiedProofEntries,
                      proofContextEntries: feed.proofContextEntries,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: sliverPadding.left),
                  sliver: const SliverToBoxAdapter(child: ArchiveChangesSection()),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: sliverPadding.left),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        InsightShareExporter(entries: feed.proofContextEntries),
                        SizedBox(height: ArchiveResponsiveLayout.gap(context)),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    sliverPadding.left,
                    0,
                    sliverPadding.right,
                    8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Your words',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                if (feed.showsNoSearchResults)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      sliverPadding.left,
                      12,
                      sliverPadding.right,
                      sliverPadding.bottom + 80,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'No saved moments match "${feed.searchQuery}".',
                        key: const Key('archive_search_no_results'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      sliverPadding.left,
                      0,
                      sliverPadding.right,
                      sliverPadding.bottom + 80,
                    ),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            ArchiveResponsiveLayout.entryGridColumnsForWidth(
                          constraints.crossAxisExtent,
                        );
                        final itemCount =
                            visibleEntries.length + (feed.isLoadingMore ? 1 : 0);

                        if (columns <= 1) {
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _entryTile(
                                context,
                                visibleEntries,
                                feed,
                                index,
                                onEntryTap,
                              ),
                              childCount: itemCount,
                            ),
                          );
                        }

                        return SliverGrid(
                          gridDelegate:
                              ArchiveResponsiveLayout.entryGridDelegate(
                            context: context,
                            crossAxisCount: columns,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _entryTile(
                              context,
                              visibleEntries,
                              feed,
                              index,
                              onEntryTap,
                            ),
                            childCount: itemCount,
                          ),
                        );
                      },
                    ),
                  ),
              ],
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  sliverPadding.left,
                  20,
                  sliverPadding.right,
                  sliverPadding.bottom + 80,
                ),
                sliver: const SliverToBoxAdapter(
                  child: TrustStatusFooter(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IntroSection extends StatelessWidget {
  const _IntroSection({
    required this.theme,
    required this.loadState,
    required this.showChangesUnavailable,
  });

  final ThemeData theme;
  final ArchiveBeliefLoadState loadState;
  final bool showChangesUnavailable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your recordings, typed moments, and transcripts — exactly as you '
          'captured them. Archive interpretations above stay separate from your '
          'own wording.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Not therapy or medical advice.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ArchiveHomeChooseWhatLeavesTile(
          onTap: () {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              router.push('/privacy-trust-centre');
            }
          },
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
        if (showChangesUnavailable) const ArchiveChangesUnavailableNotice(),
      ],
    );
  }
}

Widget _entryTile(
  BuildContext context,
  List<JournalEntry> entries,
  ArchiveFeedState feed,
  int index,
  ValueChanged<String> onEntryTap,
) {
  if (index >= entries.length) {
    return feed.isLoadingMore
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        : const SizedBox.shrink();
  }

  final entry = entries[index];
  return ArchiveEntryCard(
    entry: entry,
    onTap: () => onEntryTap(entry.id),
  );
}
