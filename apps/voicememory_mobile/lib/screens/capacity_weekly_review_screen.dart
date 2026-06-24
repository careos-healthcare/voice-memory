import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/capacity_loop/capacity_cost_store.dart';
import '../features/capacity_loop/capacity_decision_outcome_store.dart';
import '../features/capacity_loop/capacity_pull_reason_store.dart';
import '../features/capacity_loop/capacity_weekly_review_copy.dart';
import '../features/capacity_loop/capacity_weekly_review_engine.dart';
import '../features/capacity_loop/capacity_weekly_review_models.dart';
import '../features/demo/sample_archive_mode.dart';
import '../features/beta_feedback/beta_feedback_engine.dart';
import '../features/capacity_loop/capacity_boundary_response_engine.dart';
import '../features/capacity_loop/capacity_boundary_response_models.dart';
import '../features/capacity_loop/capacity_boundary_response_store.dart';
import '../features/paid_intent/paid_intent_confirmation_engine.dart';
import '../features/paid_intent/paid_intent_confirmation_models.dart';
import '../features/paid_intent/paid_intent_confirmation_store.dart';
import '../features/capacity_loop/capacity_activation_fit_models.dart';
import '../features/capacity_loop/capacity_activation_fit_store.dart';
import '../features/archive_daily_change/archive_daily_change_engine.dart';
import '../features/archive_daily_change/archive_daily_change_models.dart';
import '../features/archive_daily_change/archive_daily_change_store.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/paid_intent_confirmation_card.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/capacity_boundary_response_card.dart';
import '../widgets/archive_daily_change_card.dart';

/// Full capacity weekly review screen — cautious summaries, no journal text.
class CapacityWeeklyReviewScreen extends StatefulWidget {
  const CapacityWeeklyReviewScreen({
    super.key,
    this.journalService,
    this.engine = const CapacityWeeklyReviewEngine(),
    CapacityWeeklyReviewResult? initialResult,
    this.capacityLoopActive = false,
    this.capacityCohortActive = false,
  }) : _initialResult = initialResult;

  final JournalService? journalService;
  final CapacityWeeklyReviewEngine engine;
  final bool capacityLoopActive;
  final bool capacityCohortActive;
  final CapacityWeeklyReviewResult? _initialResult;

  @override
  State<CapacityWeeklyReviewScreen> createState() =>
      _CapacityWeeklyReviewScreenState();
}

class _CapacityWeeklyReviewScreenState extends State<CapacityWeeklyReviewScreen> {
  CapacityWeeklyReviewResult? _result;
  CapacityBoundaryResponseResult? _boundaryResponse;
  CapacityBoundaryResponseInput? _boundaryInput;
  ArchiveDailyChangeResult? _archiveDailyChange;
  PaidIntentConfirmationResult? _paidIntentResult;
  PaidIntentValueSignalsAtResponse? _paidIntentValueSignals;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget._initialResult != null) {
      _result = widget._initialResult;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _result = CapacityWeeklyReviewResult.hidden;
        _loading = false;
      });
      return;
    }

    await CapacityCostStore.ensureLoaded();
    await CapacityDecisionOutcomeStore.ensureLoaded();
    await CapacityPullReasonStore.ensureLoaded();
    await CapacityBoundaryResponseStore.ensureLoaded();
    await ArchiveDailyChangeStore.ensureLoaded();
    await CapacityActivationFitStore.ensureLoaded();
    await PaidIntentConfirmationStore.ensureLoaded();
    final journal = widget.journalService ?? AppServices.instance.journal;
    final entries = await journal.loadAll();
    final loop = await LoopModeCoordinator.loadActive();
    final cohort = await AcquisitionCohortCoordinator.load();
    final loopActive = loop?.isCapacityYes ?? widget.capacityLoopActive;
    final cohortActive =
        cohort?.cohortId == AcquisitionCohortId.capacityYesDirect ||
            widget.capacityCohortActive;

    if (!mounted) return;
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final boundaryInput = CapacityBoundaryResponseInput(
      sampleMode: false,
      realSavedMomentCount: BetaFeedbackEngine.realEntryCountFor(realEntries),
      capacityWedgeActive: loopActive || cohortActive,
      capacityMomentCount: const CapacityBoundaryResponseEngine()
          .loopEngine
          .eligibleCapacityEntryIds(realEntries)
          .length,
      capacityEvidenceCount: const CapacityBoundaryResponseEngine()
          .loopEngine
          .countCapacityEvidence(realEntries),
      outcomeOrCostRecordCount:
          CapacityDecisionOutcomeStore.countWithOutcome(
                CapacityDecisionOutcomeStore.cached,
              ) +
              CapacityCostStore.countWithLaterCost(CapacityCostStore.cached),
      pendingDecisionOutcome: false,
      pendingCostCheckin: false,
      beforeYesPauseOnHome: false,
      weeklyReviewOnHome: false,
      pendingPullReasonOnHome: false,
      mostCommonPullReasonId:
          CapacityPullReasonStore.mostCommonReasonId(CapacityPullReasonStore.cached),
      selection: CapacityBoundaryResponseStore.cached,
    );
    final reviewResult = widget.engine.buildFromJournal(
      entries: entries,
      capacityLoopActive: loopActive,
      capacityCohortActive: cohortActive,
      costRecords: CapacityCostStore.cached,
      outcomeRecords: CapacityDecisionOutcomeStore.cached,
      pullReasonRecords: CapacityPullReasonStore.cached,
    );
    final fitRecord = CapacityActivationFitStore.cached;
    final fitIsPositive = fitRecord != null &&
        !fitRecord.isSkipped &&
        fitRecord.isAnswered &&
        (fitRecord.responseId == CapacityActivationFitResponseIds.fits ||
            fitRecord.responseId == CapacityActivationFitResponseIds.partly);
    final dailyChangeShown =
        ArchiveDailyChangeStore.cached.lastSeenAt != null;
    final paidIntentResult =
        const PaidIntentConfirmationEngine().buildFromJournal(
      entries: entries,
      capacityLoopActive: loopActive,
      capacityCohortActive: cohortActive,
      fitIsPositive: fitIsPositive,
      fitResponseLabel: reviewResult.hasReview
          ? (fitIsPositive ? 'partly' : 'not answered')
          : 'not answered',
      dailyChangeShown: dailyChangeShown,
      weeklyReviewAvailable: reviewResult.hasReview,
      boundaryResponseSelected:
          CapacityBoundaryResponseStore.cached?.hasSelection ?? false,
      screenshotMode: false,
      record: PaidIntentConfirmationStore.cached,
    );
    final valueSignals = PaidIntentConfirmationEngine.valueSignalsFrom(
      capacityMomentCount: const CapacityBoundaryResponseEngine()
          .loopEngine
          .eligibleCapacityEntryIds(realEntries)
          .length,
      fitResponseLabel: fitIsPositive ? 'partly' : 'not answered',
      dailyChangeAvailable: dailyChangeShown,
      weeklyReviewAvailable: reviewResult.hasReview,
      boundaryResponseSelected:
          CapacityBoundaryResponseStore.cached?.hasSelection ?? false,
    );
    setState(() {
      _boundaryInput = boundaryInput;
      _result = reviewResult;
      _archiveDailyChange =
          const ArchiveDailyChangeEngine().buildFromJournal(
        entries: entries,
        capacityLoopActive: loopActive,
        capacityCohortActive: cohortActive,
        state: ArchiveDailyChangeStore.cached,
        pullReasonRecords: CapacityPullReasonStore.cached,
        costRecords: CapacityCostStore.cached,
        outcomeRecords: CapacityDecisionOutcomeStore.cached,
        boundarySelection: CapacityBoundaryResponseStore.cached,
        activationFitRecord: fitRecord,
        weeklyReviewAvailable: reviewResult.hasReview,
      );
      _paidIntentResult = paidIntentResult;
      _paidIntentValueSignals = valueSignals;
      _boundaryResponse =
          const CapacityBoundaryResponseEngine().build(boundaryInput);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: CapacityWeeklyReviewCopy.title,
      fallbackRoute: CapacityWeeklyReviewCopy.archiveHomeRoute,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('capacity_weekly_review_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(context, _result!),
            ),
    );
  }

  Widget _content(BuildContext context, CapacityWeeklyReviewResult result) {
    if (!result.hasReview) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            CapacityWeeklyReviewCopy.title,
            key: const Key('capacity_weekly_review_screen_insufficient_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            CapacityWeeklyReviewCopy.patternForming,
            key: const Key('capacity_weekly_review_screen_insufficient_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.title,
          key: const Key('capacity_weekly_review_screen_title'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.subtitle,
          key: const Key('capacity_weekly_review_screen_subtitle'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        if (result.evidenceCountLabel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            result.evidenceCountLabel,
            key: const Key('capacity_weekly_review_screen_evidence'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (result.outcomeLine.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.outcomeLine,
            key: const Key('capacity_weekly_review_screen_outcome'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (result.laterCostLine.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.laterCostLine,
            key: const Key('capacity_weekly_review_screen_later_cost_line'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _section(
          context,
          CapacityWeeklyReviewCopy.sectionWhatRepeated,
          result.whatRepeated,
          key: const Key('capacity_weekly_review_screen_what_repeated'),
        ),
        _section(
          context,
          CapacityWeeklyReviewCopy.sectionWhatChanged,
          result.whatChanged,
          key: const Key('capacity_weekly_review_screen_what_changed'),
        ),
        _section(
          context,
          CapacityWeeklyReviewCopy.sectionLaterCost,
          result.laterCostSection,
          key: const Key('capacity_weekly_review_screen_later_cost'),
        ),
        if (result.whatPulledYouIn.isNotEmpty)
          _section(
            context,
            CapacityWeeklyReviewCopy.sectionWhatPulledYouIn,
            result.whatPulledYouIn,
            key: const Key('capacity_weekly_review_screen_what_pulled_you_in'),
          ),
        _section(
          context,
          CapacityWeeklyReviewCopy.sectionWatchNext,
          result.watchNext,
          key: const Key('capacity_weekly_review_screen_watch_next'),
        ),
        if (_archiveDailyChange != null) ...[
          const SizedBox(height: AppSpacing.md),
          ArchiveDailyChangeSection(
            result: _archiveDailyChange!,
            useWeeklyTitle: true,
          ),
        ],
        if (_boundaryResponse?.showOnWeeklyReview == true) ...[
          const SizedBox(height: AppSpacing.md),
          CapacityBoundaryResponsePicker(
            result: _boundaryResponse!,
            compact: true,
            onSelectionChanged: () {
              if (!mounted) return;
              final input = _boundaryInput;
              if (input == null) return;
              setState(() {
                _boundaryResponse =
                    const CapacityBoundaryResponseEngine().build(
                  input.copyWith(
                    selection: CapacityBoundaryResponseStore.cached,
                  ),
                );
              });
            },
          ),
        ],
        if (_paidIntentResult?.showOnWeeklyReview == true &&
            _paidIntentResult!.showCard &&
            _paidIntentValueSignals != null) ...[
          const SizedBox(height: AppSpacing.md),
          PaidIntentConfirmationCard(
            result: _paidIntentResult!,
            valueSignals: _paidIntentValueSignals!,
            compact: true,
            onSaved: _load,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('capacity_weekly_review_screen_primary_button'),
          onPressed: () => context.push(result.secondaryRoute),
          child: Text(result.secondaryCtaLabel),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('capacity_weekly_review_screen_loop_button'),
          onPressed: () =>
              context.push(CapacityWeeklyReviewCopy.capacityLoopRoute),
          child: const Text('Open yes loop'),
        ),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String label,
    String body, {
    Key? key,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            key: key,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
      ),
    );
  }
}
