import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/empty_archive_experience.dart';
import '../design/user_facing_date.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../features/timeline/timeline_index.dart';
import '../features/timeline/timeline_models.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/timeline_sync_badge.dart';

/// Chronological journal timeline grouped by year and month.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _scrollController = ScrollController();
  List<TimelineRow> _rows = const [];
  bool _loading = true;
  final Map<String, GlobalKey> _monthKeys = {};

  @override
  void initState() {
    super.initState();
    final entries =
        peekJournalEntriesSync(AppServices.instance.journalStore);
    if (isIntentionalEmptyArchive(entries)) {
      _rows = const [];
      _loading = false;
    }
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;

    if (isIntentionalEmptyArchive(entries)) {
      setState(() {
        _rows = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final rows = buildTimelineRows(entries);
    _monthKeys.clear();
    for (final row in rows) {
      if (row is TimelineMonthRow) {
        final key = '${row.year}-${row.month}';
        _monthKeys[key] = GlobalKey();
      }
    }
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  List<({int year, int month, String label})> _monthJumpTargets() {
    final out = <({int year, int month, String label})>[];
    for (final row in _rows) {
      if (row is TimelineMonthRow) {
        out.add((
          year: row.year,
          month: row.month,
          label:
              '${timelineMonthLabel(row.month)} ${row.year} (${timelineRecordingCountLabel(row.recordingCount)})',
        ));
      }
    }
    return out;
  }

  void _showJumpPicker() {
    final targets = _monthJumpTargets();
    if (targets.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Jump to date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            for (final t in targets)
              ListTile(
                title: Text(t.label),
                onTap: () {
                  Navigator.pop(ctx);
                  final key = _monthKeys['${t.year}-${t.month}'];
                  final targetContext = key?.currentContext;
                  if (targetContext != null) {
                    Scrollable.ensureVisible(
                      targetContext,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Timeline'),
        actions: [
          if (_rows.isNotEmpty)
            IconButton(
              onPressed: _showJumpPicker,
              icon: const Icon(Icons.date_range_outlined),
              tooltip: 'Jump to date',
            ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh timeline',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: IntentionalEmptyArchiveView(fillViewport: false),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      for (final row in _rows) _sliverForRow(context, row),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                    ],
                  ),
                ),
    );
  }

  Widget _sliverForRow(BuildContext context, TimelineRow row) {
    return switch (row) {
      TimelineYearRow(:final year) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              '$year',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      TimelineMonthRow(:final year, :final month, :final recordingCount) =>
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyMonthHeaderDelegate(
            headerKey: _monthKeys['$year-$month'],
            label:
                '${timelineMonthLabel(month)} · ${timelineRecordingCountLabel(recordingCount)}',
          ),
        ),
      TimelineEntryRow(:final entry) => SliverToBoxAdapter(
          child: _EntryPreviewTile(
            dateLine: formatUserFacingDate(entry.createdAt),
            title: timelineEntryTitle(entry),
            syncBadge: timelineSyncBadgeLabel(entry.syncStatus),
            metaLine: '${entry.durationSeconds}s',
            onTap: () => context.push('/entry/${entry.id}'),
          ),
        ),
    };
  }
}

class _StickyMonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyMonthHeaderDelegate({
    required this.label,
    this.headerKey,
  });

  final String label;
  final GlobalKey? headerKey;

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      key: headerKey,
      color: AppTheme.background.withValues(alpha: 0.96),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyMonthHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

class _EntryPreviewTile extends StatelessWidget {
  const _EntryPreviewTile({
    required this.dateLine,
    required this.title,
    this.syncBadge,
    required this.metaLine,
    required this.onTap,
  });

  final String dateLine;
  final String title;
  final String? syncBadge;
  final String metaLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Semantics(
        label: 'Timeline entry, $dateLine',
        button: true,
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLine,
                    style: const TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.foreground,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (syncBadge != null) ...[
                        const SizedBox(width: 8),
                        TimelineSyncBadge(label: syncBadge!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metaLine,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
