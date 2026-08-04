import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/insights/post_save_life_os_insights.dart';
import '../../design/archive_mobile_typography.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

typedef PostSaveLifeOsInsightsLoader =
    Future<PostSaveLifeOsInsights> Function();
typedef PostSaveLifeOsInsightsEntryLoader =
    Future<PostSaveLifeOsInsights> Function(String entryId);

class PostSaveLifeOsInsightsCard extends StatefulWidget {
  const PostSaveLifeOsInsightsCard({
    super.key,
    this.entries = const [],
    required this.entryId,
    this.loader,
  }) : assert(entries.length > 0 || loader != null);

  final List<JournalEntry> entries;
  final String entryId;
  final PostSaveLifeOsInsightsLoader? loader;

  @override
  State<PostSaveLifeOsInsightsCard> createState() =>
      _PostSaveLifeOsInsightsCardState();
}

class _PostSaveLifeOsInsightsCardState
    extends State<PostSaveLifeOsInsightsCard> {
  PostSaveLifeOsInsights? _insights;
  bool _loading = true;
  bool _expanded = false;
  bool _failed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant PostSaveLifeOsInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryId == widget.entryId &&
        identical(oldWidget.loader, widget.loader) &&
        identical(oldWidget.entries, widget.entries)) {
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
      _insights = null;
      _expanded = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final result =
          await widget.loader?.call() ??
          await PostSaveLifeOsInsightsService().analyze(
            entries: widget.entries,
            finalizedEntryId: widget.entryId,
          );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _insights = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insights = _insights;
    final completed = !_loading;
    final empty =
        completed && (_failed || insights == null || insights.isEmpty);
    final semanticsState = _expanded ? 'Expanded' : 'Collapsed';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Life OS Insights',
      child: Container(
        key: const Key('post_save_life_os_insights_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: AppColors.backgroundSecondary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              Semantics(
                label: 'Life OS Insights loading',
                child: const Row(
                  key: Key('post_save_life_os_insights_loading'),
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Finding Life OS connections…')),
                  ],
                ),
              )
            else ...[
              Semantics(
                liveRegion: true,
                label: empty
                    ? 'Life OS Insights complete. No connections found.'
                    : 'Life OS Insights complete.',
                child: const SizedBox.shrink(),
              ),
              if (empty)
                Column(
                  key: const Key('post_save_life_os_insights_empty'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Life OS Insights',
                      style: ArchiveMobileTypography.responsiveSectionTitle(
                        context,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'No comparable Life OS connections yet.',
                      style: ArchiveMobileTypography.responsiveHelper(
                        context,
                      ).copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                )
              else ...[
                Semantics(
                  key: const Key('post_save_life_os_insights_toggle'),
                  button: true,
                  expanded: _expanded,
                  label: 'Life OS Insights. $semanticsState.',
                  onTap: _toggle,
                  child: ExcludeSemantics(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: _toggle,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Life OS Insights',
                                  style:
                                      ArchiveMobileTypography.responsiveSectionTitle(
                                        context,
                                      ),
                                ),
                              ),
                              Icon(
                                _expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Non-AI count summary',
                  key: const Key('post_save_life_os_non_ai_label'),
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final summary in _summaries(insights!))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      summary,
                      style: ArchiveMobileTypography.responsiveHelper(context),
                    ),
                  ),
                if (_expanded) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _details(context, insights),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  List<String> _summaries(PostSaveLifeOsInsights insights) {
    final result = <String>[];
    if (insights.entityFrequencies.isNotEmpty) {
      final ranked = [...insights.entityFrequencies]
        ..sort((a, b) {
          final count = b.currentMonthCount.compareTo(a.currentMonthCount);
          return count != 0 ? count : a.entityLabel.compareTo(b.entityLabel);
        });
      final entity = ranked.first;
      result.add(
        "You've mentioned ${entity.entityLabel} "
        '${entity.currentMonthCount} '
        '${entity.currentMonthCount == 1 ? 'time' : 'times'} this month',
      );
    }
    if (insights.relatedMemories.isNotEmpty) {
      final memory = insights.relatedMemories.first;
      result.add(
        'Related past memory: ${_relativeAge(memory.relatedEntryCitation.observedAt, memory.currentEntryCitation.observedAt)}',
      );
    }
    return result;
  }

  Widget _details(BuildContext context, PostSaveLifeOsInsights insights) {
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);
    return Column(
      key: const Key('post_save_life_os_insights_details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entity in insights.entityFrequencies) ...[
          Text(
            '${entity.entityLabel} • ${_typeLabel(entity.entityType)}'
            '${entity.isNewlyDetected ? ' • newly detected' : ''}',
            style: bodyStyle,
          ),
          for (final citation in entity.citations)
            Text(
              '${_date(citation.observedAt)} • Entry ID: ${citation.entryId}',
              style: bodyStyle,
            ),
          const SizedBox(height: AppSpacing.xs),
        ],
        for (final memory in insights.relatedMemories) ...[
          Text(
            'Related ${_typeLabel(memory.entityType)}: ${memory.entityLabel}',
            style: bodyStyle,
          ),
          Text(
            '${_date(memory.relatedEntryCitation.observedAt)} • Entry ID: ${memory.relatedEntryCitation.entryId}',
            style: bodyStyle,
          ),
        ],
      ],
    );
  }

  static String _typeLabel(String value) => value.isEmpty
      ? 'Entity'
      : '${value[0].toUpperCase()}${value.substring(1)}';

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _relativeAge(DateTime earlier, DateTime later) {
    final days = later.toUtc().difference(earlier.toUtc()).inDays;
    if (days < 1) return 'earlier today';
    if (days < 30) return '$days ${days == 1 ? 'day' : 'days'} ago';
    final months = (days / 30).floor();
    if (months < 12) {
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
    final years = (days / 365).floor();
    return '$years ${years == 1 ? 'year' : 'years'} ago';
  }
}
