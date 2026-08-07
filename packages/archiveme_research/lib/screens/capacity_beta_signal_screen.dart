import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_store.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_response_copy.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_response_engine.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_response_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_mission_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_signal_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_signal_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_signal_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_store.dart';
import 'package:voicememory_mobile/features/acquisition/acquisition_cohort_coordinator.dart';
import 'package:voicememory_mobile/features/acquisition/acquisition_cohort_model.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/quick_capture_friction_store.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_copy.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_engine.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_models.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_store.dart';
import 'package:voicememory_mobile/features/pro_interest/pro_interest_store.dart';
import 'package:voicememory_mobile/features/share/archive_share_actions.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/journal_service.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/widgets/paid_intent_confirmation_card.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

/// Local capacity beta signal dashboard — counts only, no uploads.
class CapacityBetaSignalScreen extends StatefulWidget {
  const CapacityBetaSignalScreen({
    super.key,
    this.journalService,
    this.engine = const CapacityBetaSignalEngine(),
  });

  final JournalService? journalService;
  final CapacityBetaSignalEngine engine;

  @override
  State<CapacityBetaSignalScreen> createState() =>
      _CapacityBetaSignalScreenState();
}

class _CapacityBetaSignalScreenState extends State<CapacityBetaSignalScreen> {
  CapacityBetaSignalSnapshot? _snapshot;
  BetaFeedbackResponseResult? _feedbackResponse;
  PaidIntentConfirmationResult? _paidIntentResult;
  PaidIntentValueSignalsAtResponse? _paidIntentValueSignals;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final journal = widget.journalService ?? AppServices.instance.journal;
    await CapacityPullReasonStore.ensureLoaded();
    await CapacityDecisionOutcomeStore.ensureLoaded();
    await CapacityCostStore.ensureLoaded();
    await CapacityActivationFitStore.ensureLoaded();
    await CapacityBoundaryResponseStore.ensureLoaded();
    await ProInterestStore.ensureLoaded();
    await PaidIntentConfirmationStore.ensureLoaded();
    await QuickCaptureFrictionStore.ensureLoaded();
    await ArchiveDailyChangeStore.ensureLoaded();

    final entries = await journal.loadAll();
    final loop = await LoopModeCoordinator.loadActive();
    final cohort = await AcquisitionCohortCoordinator.load();
    final capacityLoopActive = loop?.isCapacityYes ?? false;
    final capacityCohortActive =
        cohort?.cohortId == AcquisitionCohortId.capacityYesDirect;
    final capacityWedgeActive = capacityLoopActive || capacityCohortActive;
    final fitRecord = CapacityActivationFitStore.cached;
    final fitIsPositive = _fitIsPositive(fitRecord);
    final dailyChangeShown = ArchiveDailyChangeStore.cached.lastSeenAt != null;

    final snapshot = widget.engine.buildFromJournal(
      entries: entries,
      capacityLoopActive: capacityLoopActive,
      capacityCohortActive: capacityCohortActive,
      fitRecord: fitRecord,
      boundarySelection: CapacityBoundaryResponseStore.cached,
      proInterestState: ProInterestStore.cached,
      paidIntentRecord: PaidIntentConfirmationStore.cached,
      quickCaptureFrictionRecord: QuickCaptureFrictionStore.cached,
      dailyChangeAvailable: dailyChangeShown,
    );
    final paidIntentResult = const PaidIntentConfirmationEngine()
        .buildFromJournal(
          entries: entries,
          capacityLoopActive: capacityLoopActive,
          capacityCohortActive: capacityCohortActive,
          fitIsPositive: fitIsPositive,
          fitResponseLabel: snapshot.fitResponseLabel,
          dailyChangeShown: dailyChangeShown,
          weeklyReviewAvailable: snapshot.weeklyReviewAvailable,
          boundaryResponseSelected: snapshot.boundaryResponseSelected,
          screenshotMode: false,
          record: PaidIntentConfirmationStore.cached,
        );
    final valueSignals = PaidIntentConfirmationEngine.valueSignalsFrom(
      capacityMomentCount: snapshot.capacityMomentCount,
      fitResponseLabel: snapshot.fitResponseLabel,
      dailyChangeAvailable: dailyChangeShown,
      weeklyReviewAvailable: snapshot.weeklyReviewAvailable,
      boundaryResponseSelected: snapshot.boundaryResponseSelected,
    );

    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _paidIntentResult = paidIntentResult;
      _paidIntentValueSignals = valueSignals;
      _feedbackResponse = const BetaFeedbackResponseEngine()
          .buildFromBetaSnapshot(
            snapshot: snapshot,
            capacityWedgeActive: capacityWedgeActive,
            fitIsPositive: fitIsPositive,
            fitIsUnclear: _fitIsUnclear(fitRecord),
            fitNotAnswered: BetaFeedbackResponseEngine.fitNotAnsweredFromRecord(
              fitRecord,
            ),
            dailyChangeDismissed:
                ArchiveDailyChangeStore.cached.dismissedAt != null,
            dailyChangeAvailable: dailyChangeShown,
            paidIntentStrongWtp: snapshot.paidIntentStrongWtp,
            paidIntentSoftWtp: snapshot.paidIntentSoftWtp,
            quickCaptureFrictionStillWork:
                QuickCaptureFrictionStore.cached?.isStillWork ?? false,
          );
      _loading = false;
    });
  }

  Future<void> _copySummary(CapacityBetaSignalSnapshot snapshot) async {
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: snapshot.exportSummary,
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      ArchiveShareActions.showFeedback(
        context,
        CapacityBetaSignalCopy.summaryCopied,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PushedScreenShell(
        title: CapacityBetaSignalCopy.screenTitle,
        fallbackRoute: '/support-feedback',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final snapshot = _snapshot!;
    return PushedScreenShell(
      title: CapacityBetaSignalCopy.screenTitle,
      fallbackRoute: '/support-feedback',
      body: SingleChildScrollView(
        key: const Key('capacity_beta_signal_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              CapacityBetaSignalCopy.subtitle,
              key: const Key('capacity_beta_signal_subtitle'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            if (!snapshot.hasCapacityEvidence) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                CapacityBetaSignalCopy.emptyBody,
                key: const Key('capacity_beta_signal_empty'),
                style: ArchiveMobileTypography.explanationBody(context),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.lg),
              _sectionTitle(
                context,
                CapacityBetaSignalCopy.activationSectionTitle,
                key: const Key('capacity_beta_signal_activation_section'),
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_saved_yes_moments'),
                label: CapacityBetaSignalCopy.savedYesMomentsLabel,
                value: CapacityBetaSignalCopy.savedYesMomentsValue(
                  snapshot.capacityMomentCount,
                  snapshot.activationTarget,
                ),
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_activation_reached'),
                label: CapacityBetaSignalCopy.activationReachedLabel,
                value: CapacityBetaSignalCopy.activationReachedValue(
                  snapshot.activationReached,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _sectionTitle(
                context,
                CapacityBetaSignalCopy.fitSectionTitle,
                key: const Key('capacity_beta_signal_fit_section'),
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_fit_response'),
                label: CapacityBetaSignalCopy.loopFitResponseLabel,
                value: snapshot.fitResponseLabel,
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_quick_capture_friction'),
                label: CapacityBetaSignalCopy.quickCaptureFrictionLabel,
                value: snapshot.quickCaptureFrictionLabel,
              ),
              const SizedBox(height: AppSpacing.md),
              _sectionTitle(
                context,
                CapacityBetaSignalCopy.evidenceSectionTitle,
                key: const Key('capacity_beta_signal_evidence_section'),
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_pull_reason_count'),
                label: CapacityBetaSignalCopy.pullReasonRecordsLabel,
                value: '${snapshot.pullReasonRecordCount}',
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_outcome_count'),
                label: CapacityBetaSignalCopy.outcomeRecordsLabel,
                value: '${snapshot.outcomeRecordCount}',
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_later_cost_count'),
                label: CapacityBetaSignalCopy.laterCostRecordsLabel,
                value: '${snapshot.laterCostRecordCount}',
              ),
              const SizedBox(height: AppSpacing.md),
              _sectionTitle(
                context,
                CapacityBetaSignalCopy.returnSectionTitle,
                key: const Key('capacity_beta_signal_return_section'),
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_weekly_review'),
                label: CapacityBetaSignalCopy.weeklyReviewAvailableLabel,
                value: CapacityBetaSignalCopy.yesNo(
                  snapshot.weeklyReviewAvailable,
                ),
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_boundary_selected'),
                label: CapacityBetaSignalCopy.boundarySelectedLabel,
                value: CapacityBetaSignalCopy.yesNo(
                  snapshot.boundaryResponseSelected,
                ),
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_boundary_copied'),
                label: CapacityBetaSignalCopy.boundaryCopiedLabel,
                value: CapacityBetaSignalCopy.yesNo(
                  snapshot.boundaryResponseCopied,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _sectionTitle(
                context,
                CapacityBetaSignalCopy.paymentSectionTitle,
                key: const Key('capacity_beta_signal_payment_section'),
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_pro_interest'),
                label: CapacityBetaSignalCopy.proInterestSeenLabel,
                value: CapacityBetaSignalCopy.yesNo(
                  snapshot.proInterestCaptured,
                ),
              ),
              _metricRow(
                context,
                key: const Key('capacity_beta_signal_payment_signal'),
                label: CapacityBetaSignalCopy.paymentSignalLabel,
                value: snapshot.paymentSignalLabel,
              ),
              const SizedBox(height: AppSpacing.md),
              _sectionTitle(
                context,
                PaidIntentConfirmationCopy.dashboardSectionTitle,
                key: const Key('capacity_beta_signal_paid_intent_section'),
              ),
              if (snapshot.paidIntentAnswered) ...[
                _metricRow(
                  context,
                  key: const Key('capacity_beta_signal_paid_intent_answer'),
                  label: CapacityBetaSignalCopy.paidIntentAnswerLabel,
                  value: snapshot.paymentSignalLabel,
                ),
              ] else if (_paidIntentResult != null &&
                  _paidIntentValueSignals != null &&
                  _paidIntentResult!.showCard) ...[
                PaidIntentConfirmationCard(
                  result: _paidIntentResult!,
                  valueSignals: _paidIntentValueSignals!,
                  onSaved: _load,
                ),
              ] else ...[
                Text(
                  PaidIntentConfirmationCopy.dashboardNotEnoughSignal,
                  key: const Key('capacity_beta_signal_paid_intent_not_ready'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _sectionTitle(
                context,
                CapacityBetaSignalCopy.verdictSectionTitle,
                key: const Key('capacity_beta_signal_verdict_section'),
              ),
              Text(
                snapshot.verdictLabel,
                key: const Key('capacity_beta_signal_verdict_label'),
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                CapacityBetaSignalCopy.verdictDisclaimer,
                key: const Key('capacity_beta_signal_verdict_disclaimer'),
                style: ArchiveMobileTypography.explanationBody(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (_feedbackResponse != null) ...[
              const SizedBox(height: AppSpacing.md),
              _sectionTitle(
                context,
                BetaFeedbackResponseCopy.sectionTitle,
                key: const Key('capacity_beta_feedback_response_section'),
              ),
              if (_feedbackResponse!.hasRecommendation) ...[
                Text(
                  _feedbackResponse!.suggestedNextFixLabel,
                  key: const Key('capacity_beta_feedback_suggested_fix'),
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _feedbackResponse!.localBetaSignalLabel,
                  key: const Key('capacity_beta_feedback_local_signal'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                Text(
                  BetaFeedbackResponseCopy.notEnoughEvidence,
                  key: const Key('capacity_beta_feedback_not_enough_evidence'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('capacity_beta_signal_copy_summary'),
                onPressed: snapshot.hasCapacityEvidence
                    ? () => _copySummary(snapshot)
                    : null,
                child: const Text(CapacityBetaSignalCopy.copySummaryButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('capacity_beta_signal_open_mission'),
                onPressed: () => context.push(CapacityBetaMissionCopy.route),
                child: const Text(
                  CapacityBetaMissionCopy.betaSignalsMissionLink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('capacity_beta_signal_open_capacity_loop'),
                onPressed: () => context.push('/capacity-loop'),
                child: const Text(
                  CapacityBetaSignalCopy.openCapacityLoopButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _fitIsPositive(CapacityActivationFitRecord? record) {
    if (record == null || record.isSkipped || !record.isAnswered) {
      return false;
    }
    return record.responseId == CapacityActivationFitResponseIds.fits ||
        record.responseId == CapacityActivationFitResponseIds.partly;
  }

  static bool _fitIsUnclear(CapacityActivationFitRecord? record) {
    if (record == null || record.isSkipped || !record.isAnswered) {
      return true;
    }
    return record.responseId == CapacityActivationFitResponseIds.notYet ||
        record.responseId == CapacityActivationFitResponseIds.tooEarly;
  }

  static Widget _sectionTitle(
    BuildContext context,
    String title, {
    required Key key,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(title, style: ArchiveMobileTypography.cardLabel(context)),
    );
  }

  static Widget _metricRow(
    BuildContext context, {
    required Key key,
    required String label,
    required String value,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ),
        ],
      ),
    );
  }
}
