import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/pro/pro_value_preview_copy.dart';
import 'package:voicememory_mobile/features/pro_interest/pro_interest_copy.dart';
import 'package:voicememory_mobile/features/pro_value/pro_value_engine.dart';
import 'package:voicememory_mobile/features/pro_value/pro_value_models.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

/// Honest Pro value overview — purchases unavailable until store setup completes.
class ProValuePreviewScreen extends StatelessWidget {
  const ProValuePreviewScreen({super.key});

  ProValuePlan _plan() {
    return const ProValueEngine().build(
      ProValueInput(
        savedEntryCount: 0,
        depthLevel: ArchiveDepthLevel.notStarted,
        watchlistCount: 0,
        weeklyReviewAvailable: false,
        evidenceMapContextCount: 0,
        beliefHistoryAvailable: false,
        purchasesAvailable: RevenueCatService.instance.isConfigured,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan();
    return PushedScreenShell(
      title: ProValuePreviewCopy.screenTitle,
      fallbackRoute: '/settings',
      body: SingleChildScrollView(
        key: const Key('pro_value_preview_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.headline,
              key: const Key('pro_value_preview_headline'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              plan.subheadline,
              key: const Key('pro_value_preview_subheadline'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              plan.body,
              key: const Key('pro_value_preview_body'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              key: const Key('pro_value_preview_free_section'),
              title: ProValuePreviewCopy.freeNowTitle,
              bullets: plan.freeNowBullets,
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              key: const Key('pro_value_preview_pro_section'),
              title: ProValuePreviewCopy.proForTitle,
              bullets: plan.valueBullets,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              ProValuePreviewCopy.whyTitle,
              key: const Key('pro_value_preview_why_title'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              plan.whyBodyOne,
              key: const Key('pro_value_preview_why_body_one'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              plan.whyBodyTwo,
              key: const Key('pro_value_preview_why_body_two'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              ProInterestCopy.previewSectionTitle,
              key: const Key('pro_value_preview_interest_title'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProInterestCopy.previewSectionBody,
              key: const Key('pro_value_preview_interest_body'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('pro_value_preview_open_pro_interest'),
                onPressed: () => context.push('/pro-interest'),
                child: const Text(ProInterestCopy.openProInterestButton),
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
              plan.purchaseUnavailableNote,
              key: const Key('pro_value_preview_purchase_unavailable'),
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProValuePreviewCopy.accountRestoreNote,
              key: const Key('pro_value_preview_account_restore'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            if (RevenueCatService.instance.isConfigured) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                plan.purchaseAfterSetupNote,
                key: const Key('pro_value_preview_purchase_after_setup'),
                style: ArchiveMobileTypography.explanationBody(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('pro_value_preview_keep_building_cta'),
                onPressed: () => context.go(plan.primaryCta.route),
                child: Text(plan.primaryCta.label),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('pro_value_preview_sample_archive_cta'),
                onPressed: () => context.push(plan.secondaryCta.route),
                child: Text(plan.secondaryCta.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ArchiveMobileTypography.cardLabel(context)),
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
