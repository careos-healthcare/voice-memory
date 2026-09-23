import 'package:archiveme_mobile/features/timeline_change_feed/timeline_change_feed_providers.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:archiveme_mobile/widgets/archive/archive_change_feed_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Month-grouped archive timeline. Headers stay pinned while the list scrolls.
class TimelineChangeFeedScreen extends ConsumerWidget {
  const TimelineChangeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(timelineEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Timeline')),
      body: entries.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            key: Key('timeline_change_feed_loading'),
          ),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTokens.spacing4),
          child: Text('Could not open the archive: $error'),
        ),
        data: (list) => _TimelineFeed(entries: list),
      ),
    );
  }
}

class _TimelineFeed extends ConsumerWidget {
  const _TimelineFeed({required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(timelineDateRangeProvider);
    final expansion = ref.watch(timelineSectionExpansionProvider);
    final sections = ArchiveChangeFeedTimeline.sections(
      entries: entries,
      year: range.year,
      month: range.month,
    );
    final years = ArchiveChangeFeedTimeline.years(entries);
    final months = range.year == null
        ? const <int>[]
        : ArchiveChangeFeedTimeline.months(entries: entries, year: range.year!);

    return CustomScrollView(
      key: const Key('timeline_change_feed'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spacing4,
              AppTokens.spacing4,
              AppTokens.spacing4,
              AppTokens.spacing2,
            ),
            child: Wrap(
              spacing: AppTokens.spacing2,
              runSpacing: AppTokens.spacing2,
              children: [
                ChoiceChip(
                  key: const Key('timeline_change_feed_all'),
                  label: const Text('All'),
                  selected: range.year == null,
                  onSelected: (_) => ref
                      .read(timelineDateRangeProvider.notifier)
                      .selectYear(null),
                ),
                for (final year in years)
                  ChoiceChip(
                    key: Key('timeline_change_feed_year_$year'),
                    label: Text('$year'),
                    selected: range.year == year,
                    onSelected: (_) => ref
                        .read(timelineDateRangeProvider.notifier)
                        .selectYear(year),
                  ),
                for (final month in months)
                  ChoiceChip(
                    key: Key('timeline_change_feed_month_${range.year}_$month'),
                    label: Text(ArchiveChangeFeedSection.monthNames[month - 1]),
                    selected: range.month == month,
                    onSelected: (_) => ref
                        .read(timelineDateRangeProvider.notifier)
                        .selectMonth(range.month == month ? null : month),
                  ),
              ],
            ),
          ),
        ),
        if (sections.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppTokens.spacing4),
              child: Text(
                'No moments in this timeframe.',
                key: Key('timeline_change_feed_empty'),
              ),
            ),
          ),
        for (final section in sections)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _MonthHeaderDelegate(
                  section: section,
                  expanded: expansion.isExpanded(section.storageKey),
                  onToggle: () => ref
                      .read(timelineSectionExpansionProvider.notifier)
                      .toggle(section.storageKey),
                ),
              ),
              if (expansion.isExpanded(section.storageKey))
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _TimelineRow(entry: section.entries[index]);
                  }, childCount: section.entries.length),
                ),
            ],
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTokens.spacing8)),
      ],
    );
  }
}

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthHeaderDelegate({
    required this.section,
    required this.expanded,
    required this.onToggle,
  });

  final ArchiveChangeFeedSection section;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final voice = section.voiceCount;
    final text = section.textCount;
    final mix = [
      if (voice > 0) '$voice voice',
      if (text > 0) '$text text',
    ].join(' · ');
    return Material(
      color: overlapsContent ? AppTokens.neutral100 : theme.colorScheme.surface,
      child: InkWell(
        key: Key('timeline_change_feed_header_${section.storageKey}'),
        onTap: onToggle,
        child: SizedBox(
          height: maxExtent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spacing4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.label,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(mix, style: theme.textTheme.bodySmall),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeaderDelegate oldDelegate) {
    return oldDelegate.section.label != section.label ||
        oldDelegate.expanded != expanded ||
        oldDelegate.section.voiceCount != section.voiceCount ||
        oldDelegate.section.textCount != section.textCount;
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voice = ArchiveChangeFeedTimeline.isVoiceMemory(entry);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spacing4,
        AppTokens.spacing2,
        AppTokens.spacing4,
        0,
      ),
      child: DecoratedBox(
        key: Key(
          voice
              ? 'timeline_change_feed_voice_${entry.id}'
              : 'timeline_change_feed_text_${entry.id}',
        ),
        decoration: BoxDecoration(
          color: voice ? AppTokens.primary50 : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: voice ? accent : AppTokens.neutral300,
              width: AppTokens.spacing1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spacing3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                voice ? Icons.mic_none : Icons.notes,
                color: voice ? accent : AppTokens.neutral500,
                size: 20,
              ),
              const SizedBox(width: AppTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (voice)
                      Text(
                        ArchiveChangeFeedTimeline.formatDuration(
                          entry.durationSeconds,
                        ),
                        key: Key('timeline_change_feed_duration_${entry.id}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: accent,
                        ),
                      ),
                    Text(
                      entry.transcript,
                      maxLines: voice ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: voice
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
