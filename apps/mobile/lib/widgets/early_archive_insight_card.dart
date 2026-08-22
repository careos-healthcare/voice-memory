import 'package:archiveme_mobile/features/early_insights/early_archive_insight_analytics.dart';
import 'package:archiveme_mobile/features/early_insights/early_archive_wins.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Surfaces a single early archive win — tentative copy, no AI claims.
class EarlyArchiveInsightCard extends StatefulWidget {
  const EarlyArchiveInsightCard({
    required this.insight, super.key,
    this.surface = 'archive_home',
    this.compact = false,
  });

  final EarlyArchiveInsight insight;
  final String surface;
  final bool compact;

  @override
  State<EarlyArchiveInsightCard> createState() =>
      _EarlyArchiveInsightCardState();
}

class _EarlyArchiveInsightCardState extends State<EarlyArchiveInsightCard> {
  var _expanded = false;
  var _loggedShown = false;
  var _loggedOpened = false;

  String get _kindParam => switch (widget.insight.kind) {
    EarlyArchiveInsightKind.topicInRecentWindow => 'topic_mention',
    EarlyArchiveInsightKind.patternMayBeForming => 'pattern_forming',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loggedShown) return;
    _loggedShown = true;
    unawaited(EarlyArchiveInsightAnalytics.shown(
      surface: widget.surface,
      kind: _kindParam,
      topicLabel: widget.insight.topicLabel,
    ));
  }

  void _onTap() {
    if (!_loggedOpened) {
      _loggedOpened = true;
      unawaited(EarlyArchiveInsightAnalytics.opened(
        surface: widget.surface,
        kind: _kindParam,
        topicLabel: widget.insight.topicLabel,
      ));
    }
    setState(() => _expanded = !_expanded);
  }

  String get _supportingLine => switch (widget.insight.kind) {
    EarlyArchiveInsightKind.topicInRecentWindow =>
      '$topic appears often in your recent reflections — the archive is still gathering evidence.',
    EarlyArchiveInsightKind.patternMayBeForming =>
      '$topic shows up often across your archive. This may be worth watching as you add more reflections.',
  };

  String get topic => widget.insight.topicLabel;

  @override
  Widget build(BuildContext context) {
    final padding = widget.compact ? 12.0 : 14.0;

    return Semantics(
      button: true,
      label: 'Early archive insight. ${widget.insight.message}',
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'EARLY ARCHIVE WIN',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.insight.message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                    height: 1.4,
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Text(
                    _supportingLine,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tap for context',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loads [buildEarlyArchiveWins] and renders [EarlyArchiveInsightCard] when eligible.
class EarlyArchiveInsightSection extends StatelessWidget {
  const EarlyArchiveInsightSection({
    required this.entries, super.key,
    this.surface = 'archive_home',
    this.compact = false,
  });

  final List<JournalEntry> entries;
  final String surface;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final insight = buildEarlyArchiveWins(entries).insight;
    if (insight == null) return const SizedBox.shrink();

    return EarlyArchiveInsightCard(
      insight: insight,
      surface: surface,
      compact: compact,
    );
  }
}