import 'dart:async';

import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../features/beta/archive_beta_mission_gate.dart';
import '../features/beta/tester_mission_copy.dart';
import '../features/beta_activation/beta_activation_summary_copy.dart';
import '../features/beta_test_script/beta_test_script_copy.dart';
import '../features/beta_test_script/beta_test_script_engine.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_engine.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_model.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import '../features/support/testflight_feedback_analytics.dart';
import '../features/support/testflight_feedback_copy.dart';
import '../features/support/testflight_feedback_launcher.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../widgets/account/beta_activation_summary_sheet.dart';
import '../widgets/account/beta_feedback_sheet.dart';
import '../widgets/account/beta_readiness_check_sheet.dart';
import '../widgets/account/beta_test_script_sheet.dart';
import '../features/beta_readiness/beta_readiness_copy.dart';
import '../widgets/beta/beta_feedback_intelligence_card.dart';
import '../widgets/beta/beta_feedback_summary_card.dart';
import '../widgets/beta/testflight_metrics_dashboard_card.dart';
import '../widgets/beta/beta_conversion_diagnosis_card.dart';
import '../widgets/pushed_screen_shell.dart';

/// Beta-only tester mission guide — steps, feedback question, and email feedback.
class TestingArchiveMeScreen extends StatefulWidget {
  const TestingArchiveMeScreen({super.key});

  @override
  State<TestingArchiveMeScreen> createState() => _TestingArchiveMeScreenState();
}

class _TestingArchiveMeScreenState extends State<TestingArchiveMeScreen> {
  List<JournalEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    unawaited(BetaFeedbackIntelligenceStore.ensureLoaded());
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    if (!AppServices.isInitialized) return;
    final entries = await AppServices.instance.journal.loadAll();
    await BetaFeedbackIntelligenceEngine.syncMilestones(entries: entries);
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _sendFeedback() async {
    TestFlightFeedbackAnalytics.tapped(surface: 'testing_archiveme_screen');
    final opened = await TestFlightFeedbackLauncher.openFeedbackEmail();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TestFlightFeedbackCopy.emailFallbackMessage),
        ),
      );
    }
  }

  void _openBetaTestScript() {
    BetaTestScriptSheet.show(
      context,
      entries: _entries,
      source: 'testing_archiveme_screen',
      onReset: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _openBetaFeedback() {
    BetaFeedbackSheet.show(
      context,
      source: 'testing_archiveme_screen',
      entryCount: _entries.length,
    );
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
    final progress = BetaTestScriptEngine.buildProgressSummary(entries: _entries);
    final feedbackSummary =
        BetaFeedbackIntelligenceEngine.buildSummary(entries: _entries);
    final showBetaFeedbackIntelligenceCard =
        BetaFeedbackIntelligenceEngine.shouldShowCard(
      BetaFeedbackIntelligenceEngine.buildContext(
        surface: BetaFeedbackIntelligenceSurface.testingArchiveMe,
        entryCount: _entries.length,
        entries: _entries,
        isZeroEntryState: _entries.isEmpty,
      ),
    );
    final firstProofReached = progress.firstProofReached ||
        feedbackSummary.state.hasReachedFirstProof;

    return PushedScreenShell(
      title: TesterMissionCopy.title,
      fallbackRoute: '/settings',
      body: SingleChildScrollView(
        key: const Key('testing_archiveme_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: const Key('testing_archiveme_beta_test_tile'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: VoiceMemoryCards.standard(
                background: const Color(0xFFF7F8FA),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    BetaTestScriptCopy.settingsTileTitle,
                    key: const Key('testing_archiveme_beta_test_title'),
                    style: ArchiveMobileTypography.listTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    BetaTestScriptCopy.settingsTileBody,
                    key: const Key('testing_archiveme_beta_test_body'),
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              BetaTestScriptCopy.progressHeading,
              key: const Key('testing_archiveme_beta_test_progress_heading'),
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            _ProgressLine(
              label: BetaTestScriptCopy.day1Label,
              value: progress.day1Label,
              keyName: 'testing_archiveme_beta_test_progress_day1',
            ),
            _ProgressLine(
              label: BetaTestScriptCopy.day2Label,
              value: progress.day2Label,
              keyName: 'testing_archiveme_beta_test_progress_day2',
            ),
            _ProgressLine(
              label: BetaTestScriptCopy.day3Label,
              value: progress.day3Label,
              keyName: 'testing_archiveme_beta_test_progress_day3',
            ),
            _ProgressLine(
              label: BetaTestScriptCopy.firstProofLabel,
              value: progress.firstProofLabel,
              keyName: 'testing_archiveme_beta_test_progress_first_proof',
            ),
            _ProgressLine(
              label: BetaTestScriptCopy.feedbackLabel,
              value: progress.feedbackLabel,
              keyName: 'testing_archiveme_beta_test_progress_feedback',
            ),
            const SizedBox(height: AppSpacing.md),
            BetaFeedbackSummaryCard(
              entries: _entries,
              summary: feedbackSummary,
            ),
            const SizedBox(height: AppSpacing.md),
            const TestFlightMetricsDashboardCard(
              source: 'testing_archiveme',
              surface: 'testing_archiveme_screen',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const BetaConversionDiagnosisCard(
              source: 'testing_archiveme',
              compact: true,
            ),
            if (showBetaFeedbackIntelligenceCard) ...[
              const SizedBox(height: AppSpacing.md),
              BetaFeedbackIntelligenceCard(
                surface: BetaFeedbackIntelligenceSurface.testingArchiveMe,
                entryCount: _entries.length,
                reachedFirstProof: firstProofReached,
                onSubmitted: () {
                  if (mounted) setState(() {});
                },
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('testing_archiveme_view_test_steps'),
                onPressed: _openBetaTestScript,
                child: Text(BetaTestScriptCopy.viewTestStepsCta),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('testing_archiveme_send_beta_feedback'),
                onPressed: _openBetaFeedback,
                child: Text(BetaTestScriptCopy.sendBetaFeedbackCta),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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
                onPressed: () => _sendFeedback(),
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

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.keyName,
  });

  final String label;
  final String value;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final style = ArchiveMobileTypography.explanationBody(
      context,
      color: AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              key: Key(keyName),
              style: style,
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
