import 'dart:async';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/config/beta_surfaces_feature_flags.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/features/archive/ui/trust_status_footer.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/features/archive_changes/archive_changes_adapter.dart';
import 'package:archiveme_mobile/features/archive/views/history_hub_view.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_entry_card.dart';
import 'package:archiveme_mobile/features/insights/trend_pattern_summary_card.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_palette.dart';
import 'package:archiveme_mobile/widgets/archive/archive_changes_section.dart';
import 'package:archiveme_mobile/widgets/archive/archive_changes_unavailable_notice.dart';
import 'package:archiveme_mobile/widgets/archive/archive_empty_state.dart';
import 'package:archiveme_mobile/features/insights/views/weekly_recap_view.dart';
import 'package:archiveme_mobile/features/settings/services/notification_service.dart';
import 'package:archiveme_mobile/widgets/archive/archive_weekly_recap_banner.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:archiveme_mobile/widgets/archive/archive_search_field.dart';
import 'package:archiveme_mobile/widgets/archive/archive_status_banner.dart';
import 'package:archiveme_mobile/widgets/archive/archive_verified_changes_section.dart';
import 'package:archiveme_mobile/widgets/insight_share/insight_share_exporter.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Responsive [CustomScrollView] slivers for the Archive Home dashboard.
class ArchiveDashboardScrollView extends StatefulWidget {
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
    this.previewChangesSnapshot,
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

  /// Skips [ArchiveChangesAdapter.load] so widget tests can pump the feed
  /// without initializing AppServices.
  @visibleForTesting
  final ArchiveChangesSnapshot? previewChangesSnapshot;

  @override
  State<ArchiveDashboardScrollView> createState() =>
      _ArchiveDashboardScrollViewState();
}

class _ArchiveDashboardScrollViewState
    extends State<ArchiveDashboardScrollView> {
  DateTime? _selectedDay;
  _CaptureKindFilter _kind = _CaptureKindFilter.all;
  String? _tagId;

  @override
  void initState() {
    super.initState();
    if (!WeeklyRecapNotificationService.takePending()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WeeklyRecapView(entries: widget.visibleEntries),
        ),
      );
    });
  }

  ArchiveFeedState get feed => widget.feed;
  List<JournalEntry> get visibleEntries => widget.visibleEntries;

  List<JournalEntry> get _filtered {
    return visibleEntries.where((entry) {
      if (_selectedDay != null && !_sameDay(entry.createdAt, _selectedDay!)) {
        return false;
      }
      final hasAudio = (entry.localAudioPath?.trim().isNotEmpty ?? false);
      if (_kind == _CaptureKindFilter.voice && !hasAudio) return false;
      if (_kind == _CaptureKindFilter.typed && hasAudio) return false;
      if (_tagId != null && entry.captureContextTag != _tagId) return false;
      return true;
    }).toList();
  }

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
          onRefresh: widget.onRefresh,
          child: CustomScrollView(
            controller: widget.controller,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (feed.showSearchField)
                SliverAppBar(
                  pinned: true,
                  primary: false,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 64,
                  titleSpacing: sliverPadding.left,
                  title: _SearchBar(
                    onQueryChanged: widget.onQueryChanged,
                  ),
                ),
              if (widget.loadState == ArchiveBeliefLoadState.offline ||
                  widget.loadState == ArchiveBeliefLoadState.error ||
                  widget.showChangesUnavailable)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    sliverPadding.left,
                    8,
                    sliverPadding.right,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _StatusBanners(
                      loadState: widget.loadState,
                      showChangesUnavailable: widget.showChangesUnavailable,
                    ),
                  ),
                ),
              if (widget.loadState == ArchiveBeliefLoadState.loading &&
                  visibleEntries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    key: Key('archive_loading_indicator'),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (widget.loadState == ArchiveBeliefLoadState.loaded &&
                  feed.archiveTotalCount == 0)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    sliverPadding.left,
                    MediaQuery.paddingOf(context).top + 24,
                    sliverPadding.right,
                    sliverPadding.bottom + 80,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: ArchiveEmptyState(onCapture: widget.onCapture),
                  ),
                )
              else ...[
                if (V1CapabilityRegistry.enableHistoryViews)
                  SliverToBoxAdapter(
                    child: HistoryHubStrip(
                      entries: visibleEntries,
                      onOpenEntry: widget.onEntryTap,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _MonthStrip(
                    entries: visibleEntries,
                    selectedDay: _selectedDay,
                    onSelect: (day) => setState(() => _selectedDay = day),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ArchiveWeeklyRecapBanner(entries: visibleEntries),
                ),
                if (V1CapabilityRegistry.weeklyRecapBanner)
                  SliverToBoxAdapter(
                    child: PastWeeklyRecaps(entries: visibleEntries),
                  ),
                if (V1CapabilityRegistry.trendPatternSummary)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: sliverPadding.left,
                      ),
                      child: TrendPatternSummaryCard(
                        citedEntryIds: [
                          for (final entry in visibleEntries)
                            if (DateTime.now()
                                    .difference(entry.createdAt)
                                    .inDays <=
                                7)
                              entry.id,
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _FilterChips(
                    entries: visibleEntries,
                    kind: _kind,
                    tagId: _tagId,
                    onKind: (kind) => setState(() => _kind = kind),
                    onTag: (tagId) => setState(() => _tagId = tagId),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _NoticedCarousel(
                    feed: feed,
                    previewChangesSnapshot: widget.previewChangesSnapshot,
                    onEntryTap: widget.onEntryTap,
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
                          color: context.palette.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  ..._dayGroupSlivers(context, sliverPadding),
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

  List<Widget> _dayGroupSlivers(
    BuildContext context,
    EdgeInsets sliverPadding,
  ) {
    final shown = _filtered;
    final groups = <DateTime, List<JournalEntry>>{};
    for (final entry in shown) {
      final day = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      groups.putIfAbsent(day, () => []).add(entry);
    }
    final slivers = <Widget>[];
    var first = true;
    for (final group in groups.entries) {
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _DayHeaderDelegate(
            label: _dayLabel(group.key),
            horizontal: sliverPadding.left,
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            sliverPadding.left,
            0,
            sliverPadding.right,
            first ? 0 : 0,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _entryTile(
                context,
                group.value,
                feed,
                index,
                widget.onEntryTap,
              ),
              childCount: group.value.length,
            ),
          ),
        ),
      );
      first = false;
    }
    if (feed.isLoadingMore) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    return slivers;
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

enum _CaptureKindFilter { all, voice, typed }

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayLabel(DateTime day) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${day.day} ${months[day.month - 1]}';
}

String _dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onQueryChanged});

  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: ArchiveSearchField(onQueryChanged: onQueryChanged)),
        if (BetaSurfacesFeatureFlags.askArchive)
          TextButton(
            key: const Key('ask_archive_entry_bar'),
            onPressed: () => context.push(RouteCatalog.askArchive),
            child: const Text('Ask'),
          ),
      ],
    );
  }
}

class _StatusBanners extends StatelessWidget {
  const _StatusBanners({
    required this.loadState,
    required this.showChangesUnavailable,
  });

  final ArchiveBeliefLoadState loadState;
  final bool showChangesUnavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loadState == ArchiveBeliefLoadState.offline)
          const ArchiveStatusBanner(
            key: Key('archive_offline_banner'),
            icon: Icons.cloud_off_outlined,
            message:
                "You're offline. Your saved moments are stored on this "
                'device, so they are still shown below.',
          )
        else if (loadState == ArchiveBeliefLoadState.error)
          Semantics(
            liveRegion: true,
            child: Text(
              'Your archive could not be opened right now.',
              key: const Key('archive_error_text'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (showChangesUnavailable) const ArchiveChangesUnavailableNotice(),
      ],
    );
  }
}

class _MonthStrip extends StatefulWidget {
  const _MonthStrip({
    required this.entries,
    required this.selectedDay,
    required this.onSelect,
  });

  final List<JournalEntry> entries;
  final DateTime? selectedDay;
  final ValueChanged<DateTime?> onSelect;

  @override
  State<_MonthStrip> createState() => _MonthStripState();
}

class _MonthStripState extends State<_MonthStrip> {
  final ScrollController _scroll = ScrollController();

  var _scrolledToRecent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showRecentDays());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showRecentDays() {
    if (!mounted || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) {
      if (_scrolledToRecent) return;
      _scrolledToRecent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRecentDays());
      return;
    }
    _scroll.jumpTo(max);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var offset = 13; offset >= 0; offset--)
        today.subtract(Duration(days: offset)),
    ];
    final marked = {
      for (final entry in widget.entries)
        DateTime(
          entry.createdAt.year,
          entry.createdAt.month,
          entry.createdAt.day,
        ),
    };
    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('archive_calendar_strip'),
        height: 112,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  key: const Key('archive_calendar_month'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.selectedDay ?? today,
                      firstDate: DateTime(1970),
                      lastDate: today,
                    );
                    if (picked == null) return;
                    widget.onSelect(
                      DateTime(picked.year, picked.month, picked.day),
                    );
                  },
                  child: Text(LocaleDateFormat.month(context, today)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  key: const Key('archive_calendar_today'),
                  label: const Text('Today'),
                  onPressed: () => widget.onSelect(null),
                ),
              ),
              for (final day in days)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    key: Key('archive_day_${_dayKey(day)}'),
                    onTap: () => widget.onSelect(day),
                    child: SizedBox(
                      width: 36,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            LocaleDateFormat.weekdayInitial(context, day),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.textMuted,
                            ),
                          ),
                          Text(
                            '${day.day}',
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight:
                                  widget.selectedDay != null &&
                                      _sameDay(widget.selectedDay!, day)
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color:
                                  widget.selectedDay != null &&
                                      _sameDay(widget.selectedDay!, day)
                                  ? context.palette.accentPrimary
                                  : context.palette.textSecondary,
                            ),
                          ),
                          if (marked.contains(day))
                            Container(
                              key: Key('archive_day_dot_${_dayKey(day)}'),
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: context.palette.accentPrimary,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            const SizedBox(height: 9),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.entries,
    required this.kind,
    required this.tagId,
    required this.onKind,
    required this.onTag,
  });

  final List<JournalEntry> entries;
  final _CaptureKindFilter kind;
  final String? tagId;
  final ValueChanged<_CaptureKindFilter> onKind;
  final ValueChanged<String?> onTag;

  @override
  Widget build(BuildContext context) {
    final usedTags = {
      for (final entry in entries)
        if (entry.captureContextTag != null) entry.captureContextTag!,
    };
    return SingleChildScrollView(
      key: const Key('archive_filter_chips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          FilterChip(
            key: const Key('archive_filter_all'),
            label: const Text('All'),
            selected: kind == _CaptureKindFilter.all && tagId == null,
            onSelected: (_) {
              onKind(_CaptureKindFilter.all);
              onTag(null);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const Key('archive_filter_voice'),
            label: const Text('Voice'),
            selected: kind == _CaptureKindFilter.voice,
            onSelected: (_) => onKind(_CaptureKindFilter.voice),
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const Key('archive_filter_typed'),
            label: const Text('Typed'),
            selected: kind == _CaptureKindFilter.typed,
            onSelected: (_) => onKind(_CaptureKindFilter.typed),
          ),
          for (final tag in CaptureContextTags.all)
            if (usedTags.contains(tag.id)) ...[
              const SizedBox(width: 8),
              FilterChip(
                key: Key('archive_filter_tag_${tag.id}'),
                label: Text(tag.label),
                selected: tagId == tag.id,
                onSelected: (_) => onTag(tagId == tag.id ? null : tag.id),
              ),
            ],
        ],
      ),
    );
  }
}

class _NoticedCarousel extends StatelessWidget {
  const _NoticedCarousel({
    required this.feed,
    required this.previewChangesSnapshot,
    required this.onEntryTap,
  });

  final ArchiveFeedState feed;
  final ArchiveChangesSnapshot? previewChangesSnapshot;
  final ValueChanged<String> onEntryTap;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    if (feed.verifiedProofEntries.isNotEmpty) {
      cards.add(
        SizedBox(
          width: 280,
          child: ArchiveVerifiedChangesSection(
            proofCandidates: feed.verifiedProofEntries,
            proofContextEntries: feed.proofContextEntries,
          ),
        ),
      );
    }
    final changes = previewChangesSnapshot;
    if (changes != null && changes.eligible && changes.timeline.isNotEmpty) {
      cards.add(
        SizedBox(
          width: 280,
          child: ArchiveChangesSection(previewSnapshot: changes),
        ),
      );
    }
    if (AppConfig.resurfacingImplemented && feed.resurfacingCards.isNotEmpty) {
      cards.add(
        SizedBox(
          width: 280,
          child: MemoryResurfacingSection(
            cards: feed.resurfacingCards,
            onCardTap: (card) {
              unawaited(
                AppServices.instance.memoryResurfacing.markOpened(
                  card.entry.id,
                ),
              );
              onEntryTap(card.entry.id);
            },
          ),
        ),
      );
    }
    if (V1CapabilityRegistry.gentleReminders &&
        AppConfig.resurfacingImplemented &&
        feed.anniversaryCards.isNotEmpty) {
      cards.add(
        SizedBox(
          width: 280,
          child: OnThisDaySection(
            cards: feed.anniversaryCards,
            onCardTap: (card) {
              unawaited(
                AppServices.instance.memoryResurfacing.markOpened(
                  card.entry.id,
                ),
              );
              onEntryTap(card.entry.id);
            },
          ),
        ),
      );
    }
    if (V1CapabilityRegistry.patternExploration) {
      cards.add(
        SizedBox(
          width: 280,
          child: PatternExplorationEntryCard(entries: feed.entries),
        ),
      );
    }
    if (cards.isEmpty) {
      return const SizedBox.shrink(key: Key('archive_noticed_empty'));
    }
    return Column(
      key: const Key('archive_noticed_row'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Text('Noticed', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              PopupMenuButton<String>(
                key: const Key('archive_noticed_overflow'),
                tooltip: 'More',
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: InsightShareExporter(
                      entries: feed.proofContextEntries,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (_, index) => cards[index],
          ),
        ),
      ],
    );
  }
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({required this.label, required this.horizontal});

  final String label;
  final double horizontal;

  @override
  double get minExtent => 36;

  @override
  double get maxExtent => 36;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: maxExtent,
      child: ColoredBox(
        color: context.palette.backgroundPrimary,
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 0),
          child: Text(
            label,
            key: Key('archive_day_header_$label'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}
