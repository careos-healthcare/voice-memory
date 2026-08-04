import 'package:flutter/material.dart';

import '../../design/archive_mobile_spacing.dart';
import '../../theme/app_spacing.dart';
import '../changes/change_date_format.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import 'weekly_review.dart';

/// One week, read-only, with nothing in it that Changes cannot prove.
///
/// Every item names the thread it came from and shows the exact words behind
/// it. There is no advice, no score, and no encouragement: the review reports
/// and stops.
class WeeklyReviewScreen extends StatelessWidget {
  const WeeklyReviewScreen({
    super.key,
    required this.review,
    required this.onOpenThread,
    required this.onOpenMoment,
  });

  final WeeklyReview review;

  /// Opens the thread this item belongs to. Changes stays the source of truth.
  final void Function(String threadId) onOpenThread;

  final void Function(TranscriptEvidenceCitation citation) onOpenMoment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(WeeklyReviewCopy.screenTitle)),
      body: SafeArea(
        child: ListView(
          padding: ArchiveMobileSpacing.pagePadding,
          children: [
            Semantics(
              header: true,
              child: Text(
                review.headline,
                key: const Key('weekly_review_screen_headline'),
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatDateRange(review.windowStart, review.windowEnd)} · '
              '${review.evidenceSummary}',
              key: const Key('weekly_review_screen_window'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final item in review.items) ...[
              _WeeklyReviewItemCard(
                key: ValueKey('weekly_review_item_${item.kind.name}'),
                item: item,
                onOpenThread: () => onOpenThread(item.threadId),
                onOpenMoment: onOpenMoment,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (review.absentSectionExplanations.isNotEmpty) ...[
              Text('Not selected this week', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              for (final explanation in review.absentSectionExplanations)
                Text(
                  explanation,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyReviewItemCard extends StatelessWidget {
  const _WeeklyReviewItemCard({
    super.key,
    required this.item,
    required this.onOpenThread,
    required this.onOpenMoment,
  });

  final WeeklyReviewItem item;
  final VoidCallback onOpenThread;
  final void Function(TranscriptEvidenceCitation citation) onOpenMoment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.kind.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (item.kind.secondaryExplanation != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.kind.secondaryExplanation!,
                key: ValueKey('weekly_review_item_detail_${item.kind.name}'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(item.threadLabel, style: theme.textTheme.titleMedium),
            if (item.statement.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(item.statement, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              WeeklyReviewCopy.evidenceHeading,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final citation in item.evidence) ...[
              const SizedBox(height: AppSpacing.xs),
              if (citation.role == TranscriptEvidenceRole.contradicting)
                Text(
                  'Contradicting evidence',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Text('“${citation.quote}”', style: theme.textTheme.bodyMedium),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => onOpenMoment(citation),
                  child: Text(
                    citation.sourceCapturedAt == null
                        ? WeeklyReviewCopy.openMomentCta
                        : '${WeeklyReviewCopy.openMomentCta} · '
                              '${formatFullDate(citation.sourceCapturedAt!)}',
                  ),
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ValueKey('weekly_review_open_thread_${item.kind.name}'),
                onPressed: onOpenThread,
                child: const Text(WeeklyReviewCopy.openThreadCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
