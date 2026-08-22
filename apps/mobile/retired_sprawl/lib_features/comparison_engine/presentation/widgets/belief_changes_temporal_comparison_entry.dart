import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/comparison_explorer_lens_support.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Prominent Changes-tab entry for New Parent / Grief-Loss temporal comparison.
class BeliefChangesTemporalComparisonEntry extends StatelessWidget {
  const BeliefChangesTemporalComparisonEntry({
    required this.activeLens, super.key,
  });

  final LifeStageLens activeLens;

  @override
  Widget build(BuildContext context) {
    final title =
        ComparisonExplorerLensSupport.beliefChangesEntryTitleFor(activeLens);
    final body =
        ComparisonExplorerLensSupport.beliefChangesEntryBodyFor(activeLens);
    if (title == null || body == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timeline_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: ArchiveMobileTypography.responsiveBody(context)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => context.push(
                ComparisonExplorerLensSupport.routeForWindow(
                  ComparisonTemporalWindow.fortnight,
                ),
              ),
              icon: const Icon(Icons.compare_arrows_outlined),
              label: Text(
                ComparisonExplorerLensSupport.beliefChangesFortnightCtaFor(
                  activeLens,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => context.push(
                ComparisonExplorerLensSupport.routeForWindow(
                  ComparisonTemporalWindow.recent,
                ),
              ),
              child: Text(
                ComparisonExplorerLensSupport.beliefChangesMonthCtaFor(
                  activeLens,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}