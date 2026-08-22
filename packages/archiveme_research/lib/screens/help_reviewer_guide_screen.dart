import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_invite/beta_invite_copy.dart';
import 'package:archiveme_mobile/features/beta_outcomes/beta_outcomes_copy.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/help/help_reviewer_guide_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';

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
            if (ArchiveBetaMissionGate.isEnabled) ...[
              Text(
                HelpReviewerGuideCopy.helpBetaTesterTitle,
                key: const Key('help_reviewer_guide_beta_tester_title'),
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                HelpReviewerGuideCopy.helpBetaTesterMission,
                key: const Key('help_reviewer_guide_beta_tester_mission'),
                style: ArchiveMobileTypography.explanationBody(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (
                var index = 0;
                index < HelpReviewerGuideCopy.helpBetaTesterBullets.length;
                index++
              ) ...[
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
                          HelpReviewerGuideCopy.helpBetaTesterBullets[index],
                          key: Key(
                            'help_reviewer_guide_beta_tester_bullet_$index',
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
                child: const Text(
                  HelpReviewerGuideCopy.openSampleArchiveButton,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                HelpReviewerGuideCopy.helpBetaOutcomesTitle,
                key: const Key('help_reviewer_guide_beta_outcomes_title'),
                style: ArchiveMobileTypography.cardLabel(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              HelpReviewerGuideCopy.helpBetaOutcomesBody,
              key: const Key('help_reviewer_guide_beta_outcomes_body'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('help_reviewer_guide_open_beta_outcomes'),
                onPressed: () => context.push('/beta-outcomes'),
                child: const Text(BetaOutcomesCopy.openBetaOutcomesButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                HelpReviewerGuideCopy.helpBetaInviteTitle,
                key: const Key('help_reviewer_guide_beta_invite_title'),
                style: ArchiveMobileTypography.cardLabel(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              HelpReviewerGuideCopy.helpBetaInviteBody,
              key: const Key('help_reviewer_guide_beta_invite_body'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('help_reviewer_guide_open_beta_invite_pack'),
                onPressed: () => context.push('/beta-invite-pack'),
                child: const Text(BetaInviteCopy.openBetaInviteButton),
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
