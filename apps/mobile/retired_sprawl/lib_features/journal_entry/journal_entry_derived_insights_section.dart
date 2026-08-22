import 'package:archiveme_mobile/features/journal_entry/journal_entry_backlink_copy.dart';
import 'package:archiveme_mobile/features/journal_entry/journal_entry_backlink_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive_v1/pattern_match_confidence_badge.dart';
import 'package:flutter/material.dart';

/// Footer cards listing insights derived from a single journal entry.
class JournalEntryDerivedInsightsSection extends StatelessWidget {
  const JournalEntryDerivedInsightsSection({
    required this.insights, super.key,
  });

  final List<JournalEntryDerivedInsight> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          JournalEntryBacklinkCopy.derivedInsightsTitle,
          key: Key('entry_derived_insights_title'),
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        if (insights.isEmpty)
          const Text(
            JournalEntryBacklinkCopy.derivedInsightsEmpty,
            key: Key('entry_derived_insights_empty'),
            style: TextStyle(color: AppTheme.muted, height: 1.45),
          )
        else
          for (final insight in insights) ...[
            _DerivedInsightCard(insight: insight),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _DerivedInsightCard extends StatelessWidget {
  const _DerivedInsightCard({required this.insight});

  final JournalEntryDerivedInsight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('entry_derived_insight_${insight.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  insight.kindLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              PatternMatchConfidenceBadge(
                band: insight.confidenceBand,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            insight.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (insight.subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              insight.subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}