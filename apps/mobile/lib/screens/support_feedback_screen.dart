import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_calendar/archive_calendar_copy.dart';
import 'package:archiveme_mobile/features/archive_clarity/archive_clarity_copy.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_copy.dart';
import 'package:archiveme_mobile/features/beta_invite/beta_invite_copy.dart';
import 'package:archiveme_mobile/features/beta_outcomes/beta_outcomes_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_mission_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_signal_copy.dart';
import 'package:archiveme_mobile/features/first_week_path/first_week_path_copy.dart';
import 'package:archiveme_mobile/features/insight_feedback/insight_feedback_copy.dart';
import 'package:archiveme_mobile/features/milestone_share/milestone_share_copy.dart';
import 'package:archiveme_mobile/features/paid_intent/paid_intent_confirmation_copy.dart';
import 'package:archiveme_mobile/features/pro_interest/pro_interest_copy.dart';
import 'package:archiveme_mobile/features/review_ritual/view_ritual_copy.dart';
import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:archiveme_mobile/features/support/support_feedback_copy.dart';
import 'package:archiveme_mobile/features/then_now/then_now_copy.dart';
import 'package:archiveme_mobile/features/todays_question/todays_question_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Support & Feedback — help, issue reporting guidance, and safe testing paths.
class SupportFeedbackScreen extends StatelessWidget {
  const SupportFeedbackScreen({super.key});

  Future<void> _openSupportPage(BuildContext context) async {
    final uri = Uri.parse(SupportFeedbackCopy.supportUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${SupportFeedbackCopy.supportUrl}'),
        ),
      );
    }
  }

  Future<void> _copyChecklist(BuildContext context) async {
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: SupportFeedbackCopy.buildChecklist(),
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      ArchiveShareActions.showFeedback(
        context,
        SupportFeedbackCopy.checklistCopied,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: SupportFeedbackCopy.screenTitle,
      fallbackRoute: '/settings',
      body: SingleChildScrollView(
        key: const Key('support_feedback_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              context,
              key: const Key('support_feedback_need_help'),
              title: SupportFeedbackCopy.sectionNeedHelpTitle,
              body: SupportFeedbackCopy.sectionNeedHelpBody,
            ),
            _section(
              context,
              key: const Key('support_feedback_report_problem'),
              title: SupportFeedbackCopy.sectionReportTitle,
              body: SupportFeedbackCopy.sectionReportBody,
            ),
            _bulletsSection(
              context,
              key: const Key('support_feedback_privacy'),
              title: SupportFeedbackCopy.sectionPrivacyTitle,
              bullets: const [
                SupportFeedbackCopy.sectionPrivacyBulletOne,
                SupportFeedbackCopy.sectionPrivacyBulletTwo,
              ],
            ),
            _section(
              context,
              key: const Key('support_feedback_beta_feedback'),
              title: BetaFeedbackCopy.supportSectionTitle,
              body: BetaFeedbackCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_beta_feedback'),
                onPressed: () => context.push('/beta-feedback'),
                child: const Text(BetaFeedbackCopy.openBetaFeedbackButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_first_week_path'),
              title: FirstWeekPathCopy.supportSectionTitle,
              body: FirstWeekPathCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_first_week_path'),
                onPressed: () => context.push(FirstWeekPathCopy.route),
                child: const Text(FirstWeekPathCopy.openPathCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_archive_clarity'),
              title: ArchiveClarityCopy.supportSectionTitle,
              body: ArchiveClarityCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_archive_clarity'),
                onPressed: () => context.push(ArchiveClarityCopy.route),
                child: const Text(ArchiveClarityCopy.viewClarityCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_todays_one_question'),
              title: TodaysQuestionCopy.supportSectionTitle,
              body: TodaysQuestionCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_todays_one_question'),
                onPressed: () => context.push(TodaysQuestionCopy.route),
                child: const Text(TodaysQuestionCopy.eyebrow),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_then_vs_now'),
              title: ThenNowCopy.supportSectionTitle,
              body: ThenNowCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_then_vs_now'),
                onPressed: () => context.push(ThenNowCopy.route),
                child: const Text(ThenNowCopy.viewThenVsNowCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_archive_calendar'),
              title: ArchiveCalendarCopy.supportSectionTitle,
              body: ArchiveCalendarCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_archive_calendar'),
                onPressed: () => context.push(ArchiveCalendarCopy.route),
                child: const Text(ArchiveCalendarCopy.openCalendarCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_review_ritual'),
              title: ReviewRitualCopy.supportSectionTitle,
              body: ReviewRitualCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_review_ritual'),
                onPressed: () => context.push(ReviewRitualCopy.route),
                child: const Text(ReviewRitualCopy.openReviewRitualCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_milestone_share'),
              title: MilestoneShareCopy.supportSectionTitle,
              body: MilestoneShareCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_milestone_share'),
                onPressed: () => context.push(MilestoneShareCopy.route),
                child: const Text(MilestoneShareCopy.openMilestoneCardsCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_insight_feedback'),
              title: InsightFeedbackCopy.supportSectionTitle,
              body: InsightFeedbackCopy.supportSectionBody,
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_beta_outcomes'),
              title: BetaOutcomesCopy.supportSectionTitle,
              body: BetaOutcomesCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_beta_outcomes'),
                onPressed: () => context.push('/beta-outcomes'),
                child: const Text(BetaOutcomesCopy.openBetaOutcomesButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_capacity_beta_mission'),
              title: CapacityBetaMissionCopy.supportTitle,
              body: CapacityBetaMissionCopy.supportSubtitle,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_capacity_beta_mission'),
                onPressed: () => context.push(CapacityBetaMissionCopy.route),
                child: const Text(CapacityBetaMissionCopy.startMissionCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_capacity_beta_signals'),
              title: CapacityBetaSignalCopy.supportTitle,
              body: CapacityBetaSignalCopy.supportSubtitle,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_capacity_beta_signals'),
                onPressed: () => context.push(CapacityBetaSignalCopy.route),
                child: const Text(CapacityBetaSignalCopy.openFromSupportButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_paid_intent'),
              title: PaidIntentConfirmationCopy.supportSectionTitle,
              body: PaidIntentConfirmationCopy.supportSectionBody,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_paid_intent'),
                onPressed: () => context.push(CapacityBetaSignalCopy.route),
                child: const Text(
                  PaidIntentConfirmationCopy.supportOpenDashboardCta,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _section(
              context,
              key: const Key('support_feedback_beta_invite'),
              title: BetaInviteCopy.supportTitle,
              body: BetaInviteCopy.supportSubtitle,
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_beta_invite_pack'),
                onPressed: () => context.push('/beta-invite-pack'),
                child: const Text(BetaInviteCopy.openBetaInviteButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              key: const Key('support_feedback_pro_interest_row'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                ProInterestCopy.supportTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                ProInterestCopy.supportSubtitle,
                style: ArchiveMobileTypography.explanationBody(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/pro-interest'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _bulletsSection(
              context,
              key: const Key('support_feedback_testing_paths'),
              title: SupportFeedbackCopy.sectionTestingTitle,
              bullets: [
                SupportFeedbackCopy.sectionTestingBulletOne,
                SupportFeedbackCopy.sectionTestingBulletTwo,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('support_feedback_open_support_page'),
                onPressed: () => _openSupportPage(context),
                child: const Text(SupportFeedbackCopy.openSupportPageButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_copy_checklist'),
                onPressed: () => _copyChecklist(context),
                child: const Text(SupportFeedbackCopy.copyChecklistButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_help_guide'),
                onPressed: () => context.push('/help-reviewer-guide'),
                child: const Text(SupportFeedbackCopy.openHelpGuideButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('support_feedback_open_sample_archive'),
                onPressed: () => context.push('/sample-archive'),
                child: const Text(SupportFeedbackCopy.openSampleArchiveButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _section(
    BuildContext context, {
    required Key key,
    required String title,
    required String body,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ArchiveMobileTypography.cardLabel(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bulletsSection(
    BuildContext context, {
    required Key key,
    required String title,
    required List<String> bullets,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ArchiveMobileTypography.cardLabel(context)),
          const SizedBox(height: AppSpacing.xs),
          for (final bullet in bullets)
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
                      bullet,
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
      ),
    );
  }
}