import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_spacing.dart';
import '../../models/journal_entry.dart';
import '../../services/evidence_receipt_analytics.dart';
import '../explainable_conclusion/explainable_conclusion_validator.dart';

enum ArchiveMomentFilter { all, voice, text, withInsights }

class ArchiveJournalHome extends StatefulWidget {
  const ArchiveJournalHome({
    super.key,
    required this.entries,
    required this.onRefresh,
    required this.onOpenMoment,
    required this.onSearch,
    required this.onRecord,
    @Deprecated('Archive intelligence is not a V1 customer surface')
    VoidCallback? onOpenInsights,
  });

  final List<JournalEntry> entries;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onOpenMoment;
  final VoidCallback onSearch;
  final VoidCallback onRecord;

  @override
  State<ArchiveJournalHome> createState() => _ArchiveJournalHomeState();
}

class _ArchiveJournalHomeState extends State<ArchiveJournalHome> {
  ArchiveMomentFilter _filter = ArchiveMomentFilter.all;

  List<JournalEntry> get _visibleEntries {
    final entries = widget.entries.where((entry) {
      final isVoice = entry.localAudioReference != null;
      return switch (_filter) {
        ArchiveMomentFilter.all => true,
        ArchiveMomentFilter.voice => isVoice,
        ArchiveMomentFilter.text => !isVoice,
        ArchiveMomentFilter.withInsights => _hasValidatedInsight(entry),
      };
    }).toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  bool _hasValidatedInsight(JournalEntry entry) {
    final conclusion = entry.reflection.explainableConclusion;
    return conclusion != null &&
        ExplainableConclusionRenderGate.visible(
              conclusion,
              canonicalTranscripts: {entry.id: entry.transcript},
            ) !=
            null;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _visibleEntries;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        key: const Key('archive_journal_home'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          Semantics(
            button: true,
            label: 'Search your archive',
            child: OutlinedButton.icon(
              key: const Key('archive_journal_search'),
              onPressed: () {
                unawaited(EvidenceReceiptAnalytics.archiveSearchUsed());
                widget.onSearch();
              },
              icon: const Icon(Icons.search),
              label: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Search moments'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<ArchiveMomentFilter>(
              key: const Key('archive_journal_filter'),
              tooltip: 'Filter archive moments',
              initialValue: _filter,
              onSelected: (value) => setState(() => _filter = value),
              itemBuilder: (context) => [
                for (final value in ArchiveMomentFilter.values)
                  PopupMenuItem(value: value, child: Text(_filterLabel(value))),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_list),
                      const SizedBox(width: 8),
                      Flexible(child: Text(_filterLabel(_filter))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showWeeklyProgress) ...[
            const SizedBox(height: 4),
            Semantics(
              label: '$_meaningfulMomentsThisWeek meaningful moments this week',
              child: Text(
                '$_meaningfulMomentsThisWeek meaningful '
                '${_meaningfulMomentsThisWeek == 1 ? 'moment' : 'moments'} '
                'this week',
                key: const Key('archive_weekly_capture_progress'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (entries.isEmpty)
            _ArchiveJournalEmptyState(
              filtered: widget.entries.isNotEmpty,
              onRecord: widget.onRecord,
            )
          else
            for (var index = 0; index < entries.length; index++) ...[
              if (index == 0 ||
                  !_sameDay(
                    entries[index - 1].createdAt,
                    entries[index].createdAt,
                  ))
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(
                    _dateLabel(entries[index].createdAt),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              _ArchiveMomentCard(
                entry: entries[index],
                hasInsight: _hasValidatedInsight(entries[index]),
                onTap: () => widget.onOpenMoment(entries[index].id),
              ),
            ],
        ],
      ),
    );
  }

  static String _filterLabel(ArchiveMomentFilter value) => switch (value) {
    ArchiveMomentFilter.all => 'All moments',
    ArchiveMomentFilter.voice => 'Voice',
    ArchiveMomentFilter.text => 'Text',
    ArchiveMomentFilter.withInsights => 'With insights',
  };

  bool get _showWeeklyProgress {
    if (widget.entries.isEmpty) return false;
    final earliest = widget.entries
        .map((entry) => entry.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime.now().difference(earliest).inDays >= 7 &&
        _meaningfulMomentsThisWeek > 0;
  }

  int get _meaningfulMomentsThisWeek {
    final threshold = DateTime.now().subtract(const Duration(days: 7));
    return widget.entries
        .where((entry) => !entry.createdAt.isBefore(threshold))
        .length;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _ArchiveMomentCard extends StatelessWidget {
  const _ArchiveMomentCard({
    required this.entry,
    required this.hasInsight,
    required this.onTap,
  });

  final JournalEntry entry;
  final bool hasInsight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVoice = entry.localAudioReference != null;
    final preview = entry.transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    return Card(
      child: ListTile(
        key: ValueKey('archive_moment_${entry.id}'),
        onTap: onTap,
        minVerticalPadding: 12,
        leading: Icon(isVoice ? Icons.mic_none : Icons.notes),
        title: Text(
          preview.isEmpty ? 'Saved moment' : preview,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            isVoice ? 'Voice' : 'Text',
            if (isVoice && entry.durationSeconds > 0)
              '${entry.durationSeconds}s',
            if (hasInsight) 'Evidence-backed insight',
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ArchiveJournalEmptyState extends StatelessWidget {
  const _ArchiveJournalEmptyState({
    required this.filtered,
    required this.onRecord,
  });

  final bool filtered;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('archive_journal_empty'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              filtered
                  ? 'No moments match this filter'
                  : 'Your archive is empty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Choose another filter to see your saved moments.'
                  : 'Record or type one real moment to begin.',
            ),
            if (!filtered) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRecord,
                icon: const Icon(Icons.mic_none),
                label: const Text('Record a moment'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
