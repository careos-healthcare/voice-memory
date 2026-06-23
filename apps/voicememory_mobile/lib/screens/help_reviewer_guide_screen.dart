import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/help/help_reviewer_guide_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Static Help & reviewer guide — safe testing paths and privacy basics.
class HelpReviewerGuideScreen extends StatelessWidget {
  const HelpReviewerGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: HelpReviewerGuideCopy.screenTitle,
      fallbackRoute: '/settings',
      body: SingleChildScrollView(
        key: const Key('help_reviewer_guide_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in HelpReviewerGuideCopy.sections) ...[
              Text(
                section.title,
                key: Key('help_reviewer_guide_section_${section.title}'),
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (var index = 0; index < section.bullets.length; index++) ...[
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
                          section.bullets[index],
                          key: Key(
                            'help_reviewer_guide_bullet_${section.title}_$index',
                          ),
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
              const SizedBox(height: AppSpacing.lg),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('help_reviewer_guide_open_sample_archive'),
                onPressed: () => context.push('/sample-archive'),
                child: const Text(HelpReviewerGuideCopy.openSampleArchiveButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('help_reviewer_guide_support_feedback_link'),
                onPressed: () => context.push('/support-feedback'),
                child: const Text(HelpReviewerGuideCopy.supportFeedbackLink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
