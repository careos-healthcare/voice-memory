import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_depth/archive_depth_copy.dart';
import '../features/pro/pro_value_preview_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Honest Pro value overview — purchases unavailable until store setup completes.
class ProValuePreviewScreen extends StatelessWidget {
  const ProValuePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: ProValuePreviewCopy.screenTitle,
      fallbackRoute: '/settings',
      body: SingleChildScrollView(
        key: const Key('pro_value_preview_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              key: const Key('pro_value_preview_free_section'),
              title: ProValuePreviewCopy.freeNowTitle,
              bullets: ProValuePreviewCopy.freeNowBullets,
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              key: const Key('pro_value_preview_pro_section'),
              title: ProValuePreviewCopy.proForTitle,
              bullets: ProValuePreviewCopy.proForBullets,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              ProValuePreviewCopy.whyTitle,
              key: const Key('pro_value_preview_why_title'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProValuePreviewCopy.whyBodyOne,
              key: const Key('pro_value_preview_why_body_one'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProValuePreviewCopy.whyBodyTwo,
              key: const Key('pro_value_preview_why_body_two'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              ArchiveDepthCopy.whyDepthTitle,
              key: const Key('pro_value_preview_depth_title'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ArchiveDepthCopy.whyDepthBodyOne,
              key: const Key('pro_value_preview_depth_body_one'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ArchiveDepthCopy.whyDepthBodyTwo,
              key: const Key('pro_value_preview_depth_body_two'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              ProValuePreviewCopy.purchaseTitle,
              key: const Key('pro_value_preview_purchase_title'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProValuePreviewCopy.purchaseUnavailable,
              key: const Key('pro_value_preview_purchase_unavailable'),
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProValuePreviewCopy.purchaseKeepFree,
              key: const Key('pro_value_preview_purchase_keep_free'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProValuePreviewCopy.purchaseAfterSetup,
              key: const Key('pro_value_preview_purchase_after_setup'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('pro_value_preview_keep_building_cta'),
                onPressed: () => context.go('/record'),
                child: const Text(ProValuePreviewCopy.keepBuildingCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('pro_value_preview_sample_archive_cta'),
                onPressed: () => context.push('/sample-archive'),
                child: const Text(ProValuePreviewCopy.trySampleArchiveCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var index = 0; index < bullets.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u2022 ',
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    bullets[index],
                    key: Key('pro_value_preview_bullet_${title}_$index'),
                    style: ArchiveMobileTypography.explanationBody(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
