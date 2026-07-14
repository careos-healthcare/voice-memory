import 'dart:async';

import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../features/beta/archive_beta_mission_gate.dart';
import '../features/beta_decision/beta_tester_outcome_store.dart';
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
import '../widgets/beta/beta_decision_rule_card.dart';
import '../widgets/beta/beta_improvement_active_branch_card.dart';
import '../widgets/beta/beta_next_build_decision_card.dart';
import '../widgets/beta/beta_tester_outcome_log_card.dart';
import '../widgets/beta/beta_validation_decision_matrix_card.dart';
import '../widgets/beta/beta_fix_playbook_card.dart';
import '../widgets/beta/beta_repair_lab_card.dart';
import '../widgets/beta/pro_placement_trigger_audit_card.dart';
import '../widgets/pro/paywall_value_repair_card.dart';
import '../features/paywall_value_repair/paywall_value_repair_copy.dart';
import '../features/paywall_value_repair/paywall_value_repair_model.dart';
import '../widgets/pro/pricing_value_framing_card.dart';
import '../features/pricing_value_framing/pricing_value_framing_copy.dart';
import '../features/pricing_value_framing/pricing_value_framing_model.dart';
import '../widgets/pro/pricing_validation_card.dart';
import '../features/pricing_validation/pricing_validation_copy.dart';
import '../features/pricing_validation/pricing_validation_model.dart';
import '../widgets/pro/evidence_trail_clarity_card.dart';
import '../features/evidence_trail_clarity/evidence_trail_clarity_copy.dart';
import '../features/evidence_trail_clarity/evidence_trail_clarity_model.dart';
import '../features/beta_repair_lab/beta_repair_lab_engine.dart';
import '../features/beta_repair_lab/beta_repair_lab_store.dart';
import '../widgets/beta/revenue_readiness_dashboard_v2_card.dart';
import '../widgets/beta/purchase_smoke_test_card.dart';
import '../widgets/beta/pro_moment_timing_audit_v2_card.dart';
import '../widgets/record/first_run_positioning_card.dart';
import '../features/first_run_positioning/first_run_positioning_engine.dart';
import '../features/pro_preview/pro_preview_engine.dart';
import '../features/pro_preview/pro_preview_model.dart';
import '../features/beta_invite/beta_invite_copy.dart';
import '../features/beta_invite/beta_invite_engine.dart';
import '../features/beta_invite/beta_invite_model.dart';
import '../features/beta_activation_path/beta_activation_path_engine.dart';
import '../widgets/beta/beta_activation_path_card.dart';
import '../features/beta_feedback_capture/beta_feedback_capture_copy.dart';
import '../features/beta_feedback_capture/beta_feedback_capture_engine.dart';
import '../features/beta_feedback_capture/beta_feedback_capture_model.dart';
import '../features/beta_feedback_capture/beta_feedback_capture_store.dart';
import '../widgets/beta/beta_feedback_capture_card.dart';
import '../features/first_session_proof_repair/first_session_proof_repair_copy.dart';
import '../features/first_session_proof_repair/first_session_proof_repair_engine.dart';
import '../features/first_session_proof_repair/first_session_proof_repair_model.dart';
import '../features/proof_floor_rescue/proof_floor_rescue_copy.dart';
import '../features/proof_floor_rescue/proof_floor_rescue_engine.dart';
import '../features/proof_floor_rescue/proof_floor_rescue_model.dart';
import '../features/first_session_lift/first_session_lift_engine.dart';
import '../features/first_save_lift/first_save_lift_engine.dart';
import '../features/pro_understanding_lift/pro_understanding_lift_copy.dart';
import '../features/pro_understanding_lift/pro_understanding_lift_engine.dart';
import '../features/pro_understanding_lift/pro_understanding_lift_model.dart';
import '../features/return_after_proof_lift_v2/return_after_proof_lift_v2_engine.dart';
import '../features/pro_visibility_lift/pro_visibility_lift_engine.dart';
import '../features/pro_visibility_lift/pro_visibility_lift_copy.dart';
import '../features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import '../features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../features/proof_quality_response/proof_quality_response_model.dart';
import '../features/paywall_cta_lift/paywall_cta_lift_engine.dart';
import '../billing/paywall_source.dart';
import '../widgets/record/first_session_proof_repair_card.dart';
import '../widgets/proof/proof_floor_rescue_card.dart';
import '../widgets/record/first_session_lift_card.dart';
import '../widgets/record/first_save_lift_card.dart';
import '../widgets/record/return_after_proof_lift_v2_card.dart';
import '../widgets/pro/pro_understanding_lift_card.dart';
import '../widgets/pro/pro_visibility_lift_card.dart';
import '../widgets/pro/paywall_cta_lift_block.dart';
import '../widgets/pro/pro_preview_card.dart';
import '../widgets/beta/beta_invite_card.dart';
import '../widgets/pushed_screen_shell.dart';

/// Beta-only tester mission guide — steps, feedback question, and email feedback.
class TestingArchiveMeScreen extends StatefulWidget {
  const TestingArchiveMeScreen({super.key});

  @override
  State<TestingArchiveMeScreen> createState() => _TestingArchiveMeScreenState();
}

class _TestingArchiveMeScreenState extends State<TestingArchiveMeScreen> {
  List<JournalEntry> _entries = const [];
  var _betaDecisionRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    unawaited(BetaFeedbackIntelligenceStore.ensureLoaded());
    unawaited(BetaRepairLabStore.ensureLoaded());
    unawaited(
      BetaFeedbackCaptureStore.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(BetaTesterOutcomeStore.ensureLoaded());
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
            FirstRunPositioningCard.test(
              result: FirstRunPositioningEngine.build(
                entryCount: _entries.length.clamp(0, 1),
                source: 'testing_archiveme',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const BetaDecisionRuleCard(
              source: 'testing_archiveme',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            BetaTesterOutcomeLogCard(
              source: 'testing_archiveme',
              compact: true,
              onChanged: () => setState(() => _betaDecisionRefreshToken++),
            ),
            const SizedBox(height: AppSpacing.md),
            BetaNextBuildDecisionCard(
              source: 'testing_archiveme',
              compact: true,
              refreshToken: _betaDecisionRefreshToken,
            ),
            const SizedBox(height: AppSpacing.md),
            BetaImprovementActiveBranchCard(
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const BetaValidationDecisionMatrixCard(
              source: 'testing_archiveme',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const BetaFixPlaybookCard(
              source: 'testing_archiveme',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const BetaRepairLabCard(
              source: 'testing_archiveme',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const _BetaRepairLabTestingPanel(),
            const SizedBox(height: AppSpacing.md),
            PaywallValueRepairCard.test(
              result: const PaywallValueRepairResult(
                shouldShow: true,
                title: PaywallValueRepairCopy.title,
                body: PaywallValueRepairCopy.body,
                bullets: PaywallValueRepairCopy.bullets,
                supportLine: PaywallValueRepairCopy.support,
                primaryCta: PaywallValueRepairCopy.primaryCta,
                secondaryCta: PaywallValueRepairCopy.secondaryCta,
                source: 'testing_archiveme',
                entryCount: 4,
              ),
              onSeePro: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            PricingValueFramingCard.test(
              result: const PricingValueFramingResult(
                shouldShow: true,
                title: PricingValueFramingCopy.title,
                body: PricingValueFramingCopy.body,
                valueExplanation: PricingValueFramingCopy.valueExplanation,
                bullets: PricingValueFramingCopy.bullets,
                reassurance: PricingValueFramingCopy.reassurance,
                primaryCta: PricingValueFramingCopy.primaryCta,
                secondaryCta: PricingValueFramingCopy.secondaryCta,
                feedbackPrompt: PricingValueFramingCopy.feedbackPrompt,
                source: 'testing_archiveme',
                entryCount: 4,
                hasUsefulProof: true,
                activeRepairMode: 'pricing_value_framing',
              ),
              onSeePro: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            PricingValidationCard.test(
              result: const PricingValidationResult(
                shouldShow: true,
                title: PricingValidationCopy.title,
                body: PricingValidationCopy.body,
                pricePrompt: PricingValidationCopy.pricePrompt,
                reasonPrompt: PricingValidationCopy.reasonPrompt,
                primaryCta: PricingValidationCopy.primaryCta,
                secondaryCta: PricingValidationCopy.secondaryCta,
                source: 'testing_archiveme',
                entryCount: 4,
                hasUsefulProof: true,
                activeRepairMode: 'pricing_validation',
              ),
              onSeePro: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            EvidenceTrailClarityCard.test(
              result: EvidenceTrailClarityResult(
                shouldShow: true,
                title: EvidenceTrailClarityCopy.title,
                body: EvidenceTrailClarityCopy.body,
                timelineRows: EvidenceTrailClarityCopy.timelineRows,
                supportLine: EvidenceTrailClarityCopy.supportLine,
                primaryCta: EvidenceTrailClarityCopy.primaryCta,
                secondaryCta: EvidenceTrailClarityCopy.secondaryCta,
                feedbackPrompt: EvidenceTrailClarityCopy.feedbackPrompt,
                source: 'testing_archiveme',
                entryCount: 4,
                hasUsefulProof: true,
                confidenceLevel: ProofConfidenceLevel.strong,
                activeRepairMode: 'evidence_trail_timeline_clarity',
              ),
              onSeePro: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            const ProPlacementTriggerAuditCard(
              source: 'testing_archiveme',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const RevenueReadinessDashboardV2Card(
              source: 'testing_archiveme',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const PurchaseSmokeTestCard(
              source: 'testing_archiveme',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const ProMomentTimingAuditV2Card(
              source: 'testing_archiveme',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            ProPreviewCard.test(
              result: ProPreviewEngine.build(
                context: ProPreviewEngine.buildContext(
                  surface: ProPreviewSurface.testing,
                  source: 'testing_archiveme',
                  entryCount: _entries.isEmpty ? 1 : _entries.length,
                  isPro: false,
                  dismissed: ProPreviewEngine.isDismissed(),
                  entries: _entries,
                  hasTimelineProofVisible: true,
                  firstProofPayoffVisible: firstProofReached,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            BetaInviteCard.test(
              result: const BetaInviteLoopResult(
                shouldShow: true,
                title: BetaInviteCopy.loopCardTitle,
                body: BetaInviteCopy.loopCardBody,
                cta: BetaInviteCopy.loopCta,
                secondary: BetaInviteCopy.loopSecondary,
                inviteText: BetaInviteCopy.loopInviteText,
                source: 'testing_archiveme',
                surface: BetaInviteLoopSurface.testing,
                entryCount: 1,
                trigger: BetaInviteLoopTrigger.usefulFeedback,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            BetaActivationPathCard.test(
              result: BetaActivationPathEngine.build(
                context: BetaActivationPathEngine.buildContext(
                  source: 'testing_archiveme',
                  entryCount: _entries.length,
                  betaMissionEnabled: true,
                ),
              ),
              showDiagnosis: true,
            ),
            const SizedBox(height: AppSpacing.md),
            _FirstSessionProofRepairTestingPanel(
              entryCount: _entries.length,
            ),
            const SizedBox(height: AppSpacing.md),
            _ProofFloorRescueTestingPanel(
              entryCount: _entries.length,
            ),
            const SizedBox(height: AppSpacing.md),
            ProofFloorRescueCard.test(
              result: ProofFloorRescueEngine.build(
                input: ProofFloorRescueInput(
                  entryCount: _entries.isEmpty ? 3 : _entries.length,
                  source: 'testing_archiveme',
                  isPro: false,
                  hasTimelineProofVisible: true,
                  hasConfirmedRepeat: _entries.length >= 3,
                  confidenceLevel: ProofConfidenceLevel.watchOnly,
                  hasSafeAnchor: false,
                  hasLowMatchQuality: true,
                  usefulFeedbackCount: 0,
                  isRecording: false,
                  isDegradedTranscriptState: false,
                  whatChangedQuestionActive: false,
                  patternReviewInboxHasActiveItems: false,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FirstSessionCaptureRepairCard.test(
              result: FirstSessionProofRepairEngine.buildCapture(
                entryCount: 0,
                source: 'testing_archiveme',
              ),
              onTypeOneSentence: () {},
              onUseVoice: () {},
              onChipSelected: (_) {},
            ),
            const SizedBox(height: AppSpacing.md),
            ProofQualityRepairCard.test(
              result: FirstSessionProofRepairEngine.buildProof(
                input: ProofQualityRepairVisibilityInput(
                  entryCount: _entries.isEmpty ? 3 : _entries.length,
                  source: 'testing_archiveme',
                  hasTimelineProofVisible: true,
                  hasConfirmedRepeat: _entries.length >= 3,
                  confidenceLevel: ProofConfidenceLevel.watchOnly,
                  usefulFeedbackCount: 0,
                  negativeFeedbackCount: 0,
                  betaProofFeedbackRowVisible: false,
                  isRecording: false,
                  isDegradedTranscriptState: false,
                  whatChangedQuestionActive: false,
                  patternReviewInboxHasActiveItems: false,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _FirstSessionProUnderstandingLiftTestingPanel(
              entryCount: _entries.length,
            ),
            const SizedBox(height: AppSpacing.md),
            FirstSessionLiftCard.test(
              result: FirstSessionLiftEngine.build(
                entryCount: 0,
                source: 'testing_archiveme',
              ),
              onTypeOneSentence: () {},
              onUseVoiceInstead: () {},
              onChipSelected: (_) {},
            ),
            const SizedBox(height: AppSpacing.md),
            FirstSaveLiftCard.test(
              result: FirstSaveLiftEngine.build(
                entryCount: 0,
                source: 'testing_archiveme',
              ),
              onTypeOneSentence: () {},
              onRecordInstead: () {},
              onExampleSelected: (_) {},
            ),
            const SizedBox(height: AppSpacing.md),
            ReturnAfterProofLiftV2Card.test(
              result: ReturnAfterProofLiftV2Engine.build(
                entries: _entries,
                source: 'testing_archiveme',
                firstProofSeen: true,
                timelineProofVisible: true,
              ),
              onPrimaryCta: () {},
              onPromptSelected: (_) {},
            ),
            const SizedBox(height: AppSpacing.md),
            ProUnderstandingLiftCard.test(
              result: ProUnderstandingLiftEngine.build(
                input: ProUnderstandingLiftVisibilityInput(
                  surface: ProUnderstandingLiftSurface.recordReady,
                  source: 'testing_archiveme',
                  entryCount: _entries.isEmpty ? 3 : _entries.length,
                  isPro: false,
                  hasUsefulProof: true,
                  confidenceLevel: ProofConfidenceLevel.useful,
                  feedbackState: ProofQualityFeedbackState.useful,
                  hasProEngagement: false,
                  hasFreshReturnAfterCorrection: false,
                  hasChangeAnchor: false,
                  isRecording: false,
                  isDegradedTranscriptState: false,
                  isPostSaveDegradedState: false,
                  whatChangedQuestionActive: false,
                  patternReviewInboxHasActiveItems: false,
                ),
              ),
              onSeePro: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            ProVisibilityLiftCard.test(
              result: ProVisibilityLiftEngine.build(
                surface: ProVisibilityLiftSurface.recordReady,
                source: 'testing_archiveme',
                entryCount: _entries.isEmpty ? 3 : _entries.length,
                isPro: false,
                hasUsefulProof: true,
                confidenceLevel: ProofConfidenceLevel.useful,
                feedbackState: ProofQualityFeedbackState.useful,
                hasPaywallSeen: false,
                hasFreshReturnAfterCorrection: false,
                hasChangeAnchor: false,
                isRecording: false,
                isDegradedTranscriptState: false,
                isPostSaveDegradedState: false,
                whatChangedQuestionActive: false,
                patternReviewInboxHasActiveItems: false,
              ),
              onSeePro: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            PaywallCtaLiftBlock.test(
              result: PaywallCtaLiftEngine.build(
                source: PaywallSource.valueMoment,
                analyticsSource: 'testing_archiveme',
                isPro: false,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _BetaFeedbackCaptureTestingPanel(entries: _entries),
            const SizedBox(height: AppSpacing.md),
            BetaFeedbackCaptureCard.test(
              result: BetaFeedbackCaptureEngine.build(
                context: BetaFeedbackCaptureEngine.buildContext(
                  surface: BetaFeedbackCaptureSurface.recordPostSave,
                  source: 'testing_archiveme',
                  entryCount: _entries.isEmpty ? 1 : _entries.length,
                  betaMissionEnabled: true,
                  isPostSave: true,
                ),
              ),
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

class _FirstSessionProofRepairTestingPanel extends StatelessWidget {
  const _FirstSessionProofRepairTestingPanel({required this.entryCount});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final captureVisible = FirstSessionProofRepairEngine.shouldShowCapture(
      result: FirstSessionProofRepairEngine.buildCapture(
        entryCount: entryCount,
        source: 'testing_archiveme',
      ),
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      isReady: true,
      isRecording: false,
      isPostSave: false,
      isDegradedTranscriptState: false,
      isPermissionBlocked: false,
      entryCount: entryCount,
    );
    final proofVisible = FirstSessionProofRepairEngine.shouldShowProof(
      input: ProofQualityRepairVisibilityInput(
        entryCount: entryCount >= 3 ? entryCount : 3,
        source: 'testing_archiveme',
        hasTimelineProofVisible: entryCount >= 3,
        hasConfirmedRepeat: entryCount >= 3,
        confidenceLevel: ProofConfidenceLevel.watchOnly,
        usefulFeedbackCount: 0,
        negativeFeedbackCount: 0,
        betaProofFeedbackRowVisible: false,
        isRecording: false,
        isDegradedTranscriptState: false,
        whatChangedQuestionActive: false,
        patternReviewInboxHasActiveItems: false,
      ),
    );
    final repairFocus = FirstSessionProofRepairEngine.resolveRepairFocus(
      const RevenueReadinessDashboardV2Input(
        testerCount: 10,
        firstSessionSaveCount: 1,
        usefulCount: 1,
      ),
    );
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
      color: AppColors.textSecondary,
    );

    return Container(
      key: const Key('first_session_proof_repair_testing_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'First session + proof quality repair',
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'First-session capture repair: '
            '${FirstSessionProofRepairEngine.captureStatusLabel(visible: captureVisible)}',
            key: const Key('first_session_capture_repair_status'),
            style: bodyStyle,
          ),
          Text(
            'Proof quality repair: '
            '${FirstSessionProofRepairEngine.proofStatusLabel(visible: proofVisible)}',
            key: const Key('proof_quality_repair_status'),
            style: bodyStyle,
          ),
          Text(
            'Current next fix: ${repairFocus.label}',
            key: const Key('first_session_proof_repair_next_fix'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}

class _BetaRepairLabTestingPanel extends StatelessWidget {
  const _BetaRepairLabTestingPanel();

  @override
  Widget build(BuildContext context) {
    final state = BetaRepairLabEngine.currentState();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
      color: AppColors.textSecondary,
    );

    return Container(
      key: const Key('beta_repair_lab_testing_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beta repair lab status',
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (state.buildOverrideActive &&
              state.buildOverrideLabel != null) ...[
            Text(
              state.buildOverrideLabel!,
              key: const Key('beta_repair_lab_testing_build_override'),
              style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
          ] else if (state.defaultBaselineActive &&
              state.defaultBaselineStatusLabel != null) ...[
            Text(
              state.defaultBaselineStatusLabel!,
              key: const Key('beta_repair_lab_testing_default_baseline'),
              style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            BetaRepairLabEngine.activeModeStatusLabel(),
            key: const Key('beta_repair_lab_testing_active_mode'),
            style: bodyStyle,
          ),
          Text(
            state.warning,
            key: const Key('beta_repair_lab_testing_warning'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}

class _ProofFloorRescueTestingPanel extends StatelessWidget {
  const _ProofFloorRescueTestingPanel({required this.entryCount});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final input = ProofFloorRescueInput(
      entryCount: entryCount >= 3 ? entryCount : 3,
      source: 'testing_archiveme',
      isPro: false,
      hasTimelineProofVisible: entryCount >= 3,
      hasConfirmedRepeat: entryCount >= 3,
      confidenceLevel: ProofConfidenceLevel.watchOnly,
      hasSafeAnchor: false,
      hasLowMatchQuality: true,
      usefulFeedbackCount: 0,
      isRecording: false,
      isDegradedTranscriptState: false,
      whatChangedQuestionActive: false,
      patternReviewInboxHasActiveItems: false,
    );
    final state = ProofFloorRescueEngine.resolveState(input);
    final blocksPro = ProofFloorRescueEngine.blocksProMonetization(input);
    final proofSafe = ProofFloorRescueEngine.isProofSafeForMonetization(input);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
      color: AppColors.textSecondary,
    );

    return Container(
      key: const Key('proof_floor_rescue_testing_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proof floor rescue',
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'State: ${ProofFloorRescueEngine.stateStatusLabel(state)}',
            key: const Key('proof_floor_rescue_state_status'),
            style: bodyStyle,
          ),
          Text(
            ProofFloorRescueEngine.proBlockStatusLabel(blocked: blocksPro),
            key: const Key('proof_floor_rescue_pro_block_status'),
            style: bodyStyle,
          ),
          Text(
            ProofFloorRescueEngine.proofSafeStatusLabel(safe: proofSafe),
            key: const Key('proof_floor_rescue_monetize_status'),
            style: bodyStyle,
          ),
          Text(
            'Repair focus: ${ProofFloorRescueEngine.resolveRepairFocus(
              const RevenueReadinessDashboardV2Input(
                testerCount: 10,
                usefulCount: 1,
              ),
            )?.title ?? ProofFloorRescueCopy.dashboardFocusTitle}',
            key: const Key('proof_floor_rescue_repair_focus'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}

class _FirstSessionProUnderstandingLiftTestingPanel extends StatelessWidget {
  const _FirstSessionProUnderstandingLiftTestingPanel({
    required this.entryCount,
  });

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final firstSessionVisible = FirstSessionLiftEngine.shouldShow(
      result: FirstSessionLiftEngine.build(
        entryCount: entryCount,
        source: 'testing_archiveme',
      ),
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      isReady: true,
      isRecording: false,
      isPostSave: false,
      isDegradedTranscriptState: false,
      isPermissionBlocked: false,
      entryCount: entryCount,
    );
    final proUnderstandingVisible = ProUnderstandingLiftEngine.shouldShowCard(
      input: ProUnderstandingLiftVisibilityInput(
        surface: ProUnderstandingLiftSurface.recordReady,
        source: 'testing_archiveme',
        entryCount: entryCount >= 3 ? entryCount : 3,
        isPro: false,
        hasUsefulProof: true,
        confidenceLevel: ProofConfidenceLevel.useful,
        feedbackState: ProofQualityFeedbackState.useful,
        hasProEngagement: false,
        hasFreshReturnAfterCorrection: false,
        hasChangeAnchor: false,
        isRecording: false,
        isDegradedTranscriptState: false,
        isPostSaveDegradedState: false,
        whatChangedQuestionActive: false,
        patternReviewInboxHasActiveItems: false,
      ),
    );
    final firstSessionWeak = FirstSessionLiftEngine.isFirstSessionCaptureWeak(
      firstSaveInFirstSession: 1,
      firstSessionOpportunities: 10,
    );
    final proUnderstandingWeak = ProUnderstandingLiftEngine.isProUnderstandingWeak(
      understandsProYesMaybe: 1,
      understandsProSurveyResponses: 10,
    );
    final diagnosis = ProUnderstandingLiftEngine.resolveCurrentDiagnosis(
      firstSessionCaptureWeak: firstSessionWeak,
      proUnderstandingWeak: proUnderstandingWeak,
    );
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
      color: AppColors.textSecondary,
    );

    return Container(
      key: const Key('first_session_pro_understanding_lift_testing_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'First session + Pro understanding lift',
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'First Session Lift: ${FirstSessionLiftEngine.statusLabel(visible: firstSessionVisible)}',
            key: const Key('first_session_lift_status'),
            style: bodyStyle,
          ),
          Text(
            'Pro Understanding Lift: ${ProUnderstandingLiftEngine.statusLabel(visible: proUnderstandingVisible)}',
            key: const Key('pro_understanding_lift_status'),
            style: bodyStyle,
          ),
          Text(
            'Current diagnosis: $diagnosis',
            key: const Key('first_session_pro_understanding_lift_diagnosis'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}

class _BetaFeedbackCaptureTestingPanel extends StatelessWidget {
  const _BetaFeedbackCaptureTestingPanel({required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final latest = BetaFeedbackCaptureStore.latestAnsweredRecord;
    final previewContext = BetaFeedbackCaptureEngine.buildContext(
      surface: BetaFeedbackCaptureSurface.recordPostSave,
      source: 'testing_archiveme',
      entryCount: entries.isEmpty ? 1 : entries.length,
      betaMissionEnabled: true,
      isPostSave: true,
    );
    final unresolved = BetaFeedbackCaptureEngine.unresolvedRevenueQuestion(
      context: previewContext,
    );
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
      color: AppColors.textSecondary,
    );

    return Container(
      key: const Key('testing_archiveme_beta_feedback_capture_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beta feedback capture',
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Latest moment: ${BetaFeedbackCaptureCopy.panelLatestMomentLabel(latest?.moment)}',
            key: const Key('testing_archiveme_beta_feedback_capture_moment'),
            style: bodyStyle,
          ),
          Text(
            'Latest answer: ${BetaFeedbackCaptureCopy.panelLatestAnswerLabel(moment: latest?.moment, answerId: latest?.answerId)}',
            key: const Key('testing_archiveme_beta_feedback_capture_answer'),
            style: bodyStyle,
          ),
          Text(
            'Unresolved revenue question: $unresolved',
            key: const Key('testing_archiveme_beta_feedback_capture_unresolved'),
            style: bodyStyle,
          ),
        ],
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
