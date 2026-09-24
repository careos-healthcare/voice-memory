import 'dart:async';

import 'package:archiveme_mobile/features/insights/insight_synthesis_service.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Passive weekly cards. Opening this screen reads the SQLite cache only.
class InsightsDashboardWidget extends ConsumerStatefulWidget {
  const InsightsDashboardWidget({
    super.key,
    this.loadEntries,
    this.periodicInterval,
  });

  /// Supplies moments for a manual or periodic refresh. Not used on open.
  final Future<List<JournalSnippet>> Function()? loadEntries;

  /// When set, refreshes in the background on this interval. Never on typing.
  final Duration? periodicInterval;

  @override
  ConsumerState<InsightsDashboardWidget> createState() =>
      _InsightsDashboardWidgetState();
}

class _InsightsDashboardWidgetState
    extends ConsumerState<InsightsDashboardWidget> {
  WeeklyInsightSnapshot? _snapshot;
  var _refreshing = false;
  final _scheduler = PassiveInsightScheduler();

  @override
  void initState() {
    super.initState();
    final interval = widget.periodicInterval;
    if (interval != null) {
      _scheduler.start(interval: interval, onTick: _refresh);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadCache());
    });
  }

  @override
  void dispose() {
    _scheduler.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return ListView(
      key: const Key('insights_dashboard'),
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('insights_refresh_button'),
            onPressed: _refreshing ? null : () => unawaited(_refresh()),
            child: Text(_refreshing ? 'Refreshing' : 'Refresh'),
          ),
        ),
        _InsightCard(
          cardKey: const Key('weekly_synthesis_card'),
          title: 'Weekly Synthesis',
          body:
              snapshot?.weeklySynthesis ??
              'Refresh to read this week from your saved moments.',
          entryIds: snapshot?.weeklyEntryIds ?? const [],
          surface: 'weekly_synthesis',
        ),
        const SizedBox(height: 12),
        _InsightCard(
          cardKey: const Key('surprise_insights_card'),
          title: 'Surprise Insights',
          body:
              snapshot?.surpriseInsight ??
              'A quiet pattern or a warmer week will show up here.',
          entryIds: snapshot?.surpriseEntryIds ?? const [],
          surface: 'surprise_insights',
        ),
      ],
    );
  }

  Future<void> _loadCache() async {
    final cached = await ref.read(insightSynthesisServiceProvider).readCache();
    if (!mounted) return;
    setState(() => _snapshot = cached);
  }

  Future<void> _refresh() async {
    final loader = widget.loadEntries;
    if (loader == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      final entries = await loader();
      final snapshot = await ref
          .read(insightSynthesisServiceProvider)
          .refresh(entries);
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.cardKey,
    required this.title,
    required this.body,
    required this.entryIds,
    required this.surface,
  });

  final Key cardKey;
  final String title;
  final String body;
  final List<String> entryIds;
  final String surface;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: cardKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
            ViewEvidenceInlineLink(
              entryIds: entryIds,
              surface: surface,
              claimContext: title,
            ),
          ],
        ),
      ),
    );
  }
}
