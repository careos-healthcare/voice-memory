import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_calendar/archive_calendar_copy.dart';
import 'package:archiveme_mobile/features/insight_feedback/insight_feedback_copy.dart';
import 'package:archiveme_mobile/features/review_ritual/view_ritual_copy.dart';
import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:archiveme_mobile/features/support/support_feedback_copy.dart';
import 'package:archiveme_mobile/features/then_now/then_now_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
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
              key: const Key('support_feedback_insight_feedback'),
              title: InsightFeedbackCopy.supportSectionTitle,
              body: InsightFeedbackCopy.supportSectionBody,
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              key: const Key('support_feedback_pro_interest_row'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                ArchivePaywallCopy.screenTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                ConsumerUiCopy.paywallSubhead,
                style: ArchiveMobileTypography.explanationBody(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/subscription',
                extra: const PaywallRouteArgs(
                  source: PaywallSource.generalPro,
                  sourceRoute: '/support-feedback',
                ),
              ),
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
