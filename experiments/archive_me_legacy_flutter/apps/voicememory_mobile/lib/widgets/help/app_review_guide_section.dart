import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/app_review/archive_app_review_access_gate.dart';
import '../../features/app_review/archive_app_review_session.dart';
import '../../features/help/help_reviewer_guide_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// App Review Access guidance — visible when review builds include the gate.
class AppReviewGuideSection extends StatelessWidget {
  const AppReviewGuideSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ArchiveAppReviewAccessGate.isEnabled) {
      return const SizedBox.shrink();
    }

    final active = ArchiveAppReviewSession.isActive;

    return Column(
      key: const Key('help_reviewer_guide_app_review_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          HelpReviewerGuideCopy.appReviewAccessTitle,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          active
              ? HelpReviewerGuideCopy.appReviewAccessActiveBody
              : HelpReviewerGuideCopy.appReviewAccessBody,
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        if (!active) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            HelpReviewerGuideCopy.appReviewAccessSettingsHint,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (active) ...[
          FilledButton(
            key: const Key('help_reviewer_guide_open_archive'),
            onPressed: () => context.go('/archive-belief'),
            child: const Text('Open Archive'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('help_reviewer_guide_open_paywall'),
            onPressed: () => context.push('/subscription'),
            child: const Text('Open Pro paywall'),
          ),
        ] else
          OutlinedButton(
            key: const Key('help_reviewer_guide_open_settings'),
            onPressed: () => context.go('/settings'),
            child: const Text('Open Settings'),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
