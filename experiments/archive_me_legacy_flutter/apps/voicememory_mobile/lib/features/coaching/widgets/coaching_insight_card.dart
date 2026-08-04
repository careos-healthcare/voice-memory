import 'package:flutter/material.dart';

import '../../../l10n/localization_lookup.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../controllers/coaching_state_controller.dart';

class CoachingInsightCard extends StatelessWidget {
  const CoachingInsightCard({super.key, required this.state});

  final CoachingState state;

  @override
  Widget build(BuildContext context) {
    final insight = state.insight;
    if (insight == null) return const SizedBox.shrink();

    final l10n = appLocalizationsOf(context);
    final percentage = (insight.confidenceScore * 100).round();
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.coachingInsightSemantics(
        insight.category,
        percentage,
        insight.content,
      ),
      hint: l10n.coachingInsightHint,
      child: Card(
        key: const Key('archive_coaching_insight_card'),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.accentPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      insight.category,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Semantics(
                    label: l10n.coachingConfidenceSemantics(percentage),
                    child: Chip(
                      key: const Key('archive_coaching_confidence'),
                      label: Text(l10n.coachingConfidence(percentage)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                insight.content,
                key: const Key('archive_coaching_content'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (state.isAnalyzing) ...[
                const SizedBox(height: AppSpacing.sm),
                const LinearProgressIndicator(
                  key: Key('archive_coaching_refreshing'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
