import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../features/beta/archive_beta_mission_gate.dart';
import '../features/beta/tester_mission_copy.dart';
import '../features/beta_activation/beta_activation_summary_copy.dart';
import '../features/support/testflight_feedback_analytics.dart';
import '../features/support/testflight_feedback_copy.dart';
import '../features/support/testflight_feedback_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/account/beta_activation_summary_sheet.dart';
import '../widgets/account/beta_readiness_check_sheet.dart';
import '../features/beta_readiness/beta_readiness_copy.dart';
import '../widgets/pushed_screen_shell.dart';

/// Beta-only tester mission guide — steps, feedback question, and email feedback.
class TestingArchiveMeScreen extends StatelessWidget {
  const TestingArchiveMeScreen({super.key});

  Future<void> _sendFeedback(BuildContext context) async {
    TestFlightFeedbackAnalytics.tapped(surface: 'testing_archiveme_screen');
    final opened = await TestFlightFeedbackLauncher.openFeedbackEmail();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TestFlightFeedbackCopy.emailFallbackMessage),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ArchiveBetaMissionGate.isEnabled) {
      return PushedScreenShell(
        title: TestFlightFeedbackCopy.settingsTitle,
        fallbackRoute: '/settings',
        body: Center(
          child: Text(
            TestFlightFeedbackCopy.unavailableMessage,
            style: ArchiveMobileTypography.listSubtitle(context),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
      color: AppColors.textSecondary,
    );

    return PushedScreenShell(
      title: TesterMissionCopy.title,
      fallbackRoute: '/settings',
      body: SingleChildScrollView(
        key: const Key('testing_archiveme_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TesterMissionCopy.mission,
              key: const Key('testing_archiveme_mission'),
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < TesterMissionCopy.steps.length; i++) ...[
              Text(
                '${i + 1}. ${TesterMissionCopy.steps[i]}',
                key: Key('testing_archiveme_step_${i + 1}'),
                style: bodyStyle,
              ),
              if (i < TesterMissionCopy.steps.length - 1)
                const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              TesterMissionCopy.feedbackQuestion,
              key: const Key('testing_archiveme_feedback_question'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('testing_archiveme_send_feedback'),
                onPressed: () => _sendFeedback(context),
                child: Text(TestFlightFeedbackCopy.settingsCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('testing_archiveme_beta_readiness_check'),
                onPressed: () => BetaReadinessCheckSheet.show(context),
                child: const Text(BetaReadinessCopy.openLink),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('testing_archiveme_beta_progress_summary'),
                onPressed: () => BetaActivationSummarySheet.show(context),
                child: const Text(BetaActivationSummaryCopy.openLink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
