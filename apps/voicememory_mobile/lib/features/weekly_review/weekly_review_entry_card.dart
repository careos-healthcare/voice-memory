import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'weekly_review.dart';

/// The weekly review's only presence in Changes: one compact card.
///
/// It is an entry point, not a second product. It shows the one restrained
/// summary line and opens the review; every claim inside still resolves to a
/// thread in Changes, which remains the source of truth.
class WeeklyReviewEntryCard extends StatelessWidget {
  const WeeklyReviewEntryCard({
    super.key,
    required this.review,
    required this.onOpen,
  });

  final WeeklyReview review;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label:
          '${WeeklyReviewCopy.entryPointTitle}. ${review.headline} '
          '${review.evidenceSummary}.',
      onTap: onOpen,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('weekly_review_entry_card'),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  WeeklyReviewCopy.entryPointTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  review.headline,
                  key: const Key('weekly_review_headline'),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  review.evidenceSummary,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
