import 'package:archiveme_mobile/features/sync/mesh_offload_optimistic.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/mesh_offload_save_row.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive/archive_change_feed_timeline.dart';
import 'package:flutter/material.dart';

/// Timeline of saved moments, grouped like Apple Notes and marked like Otter.
///
/// Months collapse independently. Voice memories keep a duration and a
/// waveform; text logs stay quieter, with the words themselves in front.
class ArchiveChangeFeed extends StatefulWidget {
  const ArchiveChangeFeed({
    required this.entries,
    this.itemBuilder,
    this.onEntryTap,
    this.trailing,
    this.showTitle = true,
    this.asSliver = false,
    super.key,
  });

  final List<JournalEntry> entries;
  final Widget Function(BuildContext context, JournalEntry entry)? itemBuilder;
  final ValueChanged<JournalEntry>? onEntryTap;
  final Widget? trailing;
  final bool showTitle;
  final bool asSliver;

  @override
  State<ArchiveChangeFeed> createState() => _ArchiveChangeFeedState();
}

class _ArchiveChangeFeedState extends State<ArchiveChangeFeed> {
  int? _year;
  int? _month;
  final Set<String> _collapsed = <String>{};

  @override
  void initState() {
    super.initState();
    MeshOffloadOptimisticCoordinator.instance.addListener(_onMeshSave);
  }

  @override
  void dispose() {
    MeshOffloadOptimisticCoordinator.instance.removeListener(_onMeshSave);
    super.dispose();
  }

  void _onMeshSave() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final children = _children(context);
    if (widget.asSliver) {
      return SliverList(delegate: SliverChildListDelegate(children));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<Widget> _children(BuildContext context) {
    final theme = Theme.of(context);
    final sections = ArchiveChangeFeedTimeline.sections(
      entries: widget.entries,
      year: _year,
      month: _month,
    );
    final years = ArchiveChangeFeedTimeline.years(widget.entries);
    final months = _year == null
        ? const <int>[]
        : ArchiveChangeFeedTimeline.months(
            entries: widget.entries,
            year: _year!,
          );

    final coordinator = MeshOffloadOptimisticCoordinator.instance;
    final openSaves = coordinator.saves
        .where(
          (save) =>
              save.phase != MeshOffloadSavePhase.settled ||
              !widget.entries.any((entry) => entry.id == save.id),
        )
        .toList();
    final coveredIds = coordinator.saves
        .where((save) => save.phase != MeshOffloadSavePhase.settled)
        .map((save) => save.id)
        .toSet();

    return [
      _filters(theme, years, months),
      if (openSaves.isNotEmpty) MeshOffloadOptimisticList(saves: openSaves),
      if (sections.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            'No moments in this timeframe.',
            key: Key('archive_change_feed_empty'),
          ),
        ),
      for (final section in sections) ...[
        _header(theme, section),
        if (!_collapsed.contains(section.storageKey))
          for (final entry in section.entries)
            if (!coveredIds.contains(entry.id)) _row(context, entry),
      ],
      ?widget.trailing,
    ];
  }

  Widget _filters(ThemeData theme, List<int> years, List<int> months) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Text(
              'Change feed',
              key: const Key('archive_change_feed_title'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Newest months first. Voice memories stay marked apart from text logs.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const Key('archive_change_feed_all'),
                label: const Text('All'),
                selected: _year == null,
                onSelected: (_) => setState(() {
                  _year = null;
                  _month = null;
                }),
              ),
              for (final year in years)
                ChoiceChip(
                  key: Key('archive_change_feed_year_$year'),
                  label: Text('$year'),
                  selected: _year == year,
                  onSelected: (_) => setState(() {
                    _year = year;
                    _month = null;
                  }),
                ),
            ],
          ),
          if (months.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('archive_change_feed_all_months'),
                  label: const Text('All months'),
                  selected: _month == null,
                  onSelected: (_) => setState(() => _month = null),
                ),
                for (final month in months)
                  ChoiceChip(
                    key: Key('archive_change_feed_month_${_year}_$month'),
                    label: Text(ArchiveChangeFeedSection.monthNames[month - 1]),
                    selected: _month == month,
                    onSelected: (_) => setState(() => _month = month),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(ThemeData theme, ArchiveChangeFeedSection section) {
    final collapsed = _collapsed.contains(section.storageKey);
    final mix = switch ((section.voiceCount, section.textCount)) {
      (final voice, 0) => '$voice voice',
      (0, final text) => '$text text',
      (final voice, final text) => '$voice voice · $text text',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: InkWell(
        key: Key('archive_change_feed_section_${section.storageKey}'),
        onTap: () => setState(() {
          if (collapsed) {
            _collapsed.remove(section.storageKey);
          } else {
            _collapsed.add(section.storageKey);
          }
        }),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                section.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              mix,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, JournalEntry entry) {
    final theme = Theme.of(context);
    final voice = ArchiveChangeFeedTimeline.isVoiceMemory(entry);
    final accent = voice
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final child =
        widget.itemBuilder?.call(context, entry) ??
        _preview(theme, entry, voice);

    return Padding(
      key: Key(
        voice
            ? 'archive_change_feed_voice_${entry.id}'
            : 'archive_change_feed_text_${entry.id}',
      ),
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: accent, width: voice ? 4 : 2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    voice ? Icons.mic_none_rounded : Icons.notes_outlined,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      voice ? 'Voice memory' : 'Text log',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: voice ? FontWeight.w700 : FontWeight.w500,
                        color: voice
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (voice)
                    Text(
                      ArchiveChangeFeedTimeline.formatDuration(
                        entry.durationSeconds,
                      ),
                      key: Key('archive_change_feed_duration_${entry.id}'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              if (voice) ...[
                const SizedBox(height: 6),
                _Waveform(seed: entry.id),
              ],
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(ThemeData theme, JournalEntry entry, bool voice) {
    final text = entry.transcript.trim();
    return InkWell(
      onTap: widget.onEntryTap == null ? null : () => widget.onEntryTap!(entry),
      child: Text(
        text,
        maxLines: voice ? 2 : 4,
        overflow: TextOverflow.ellipsis,
        style: voice
            ? theme.textTheme.bodyMedium
            : theme.textTheme.bodyLarge?.copyWith(height: 1.45),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.seed});

  final String seed;

  int _barHeight(int index) {
    if (seed.isEmpty) return 8;
    return (seed.codeUnitAt(index % seed.length) + index) % 12;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Container(
            width: 3,
            height: 6 + _barHeight(i).toDouble(),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}
