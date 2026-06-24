import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/capacity_loop/capacity_cost_store.dart';
import '../features/capacity_loop/capacity_decision_outcome_store.dart';
import '../features/capacity_loop/capacity_weekly_review_copy.dart';
import '../features/capacity_loop/capacity_weekly_review_engine.dart';
import '../features/capacity_loop/capacity_weekly_review_models.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

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
    final journal = widget.journalService ?? AppServices.instance.journal;
    final entries = await journal.loadAll();
    final loop = await LoopModeCoordinator.loadActive();
    final cohort = await AcquisitionCohortCoordinator.load();
    final loopActive = loop?.isCapacityYes ?? widget.capacityLoopActive;
    final cohortActive =
        cohort?.cohortId == AcquisitionCohortId.capacityYesDirect ||
            widget.capacityCohortActive;

    if (!mounted) return;
    setState(() {
      _result = widget.engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: loopActive,
        capacityCohortActive: cohortActive,
        costRecords: CapacityCostStore.cached,
        outcomeRecords: CapacityDecisionOutcomeStore.cached,
      );
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
        _section(
          context,
          CapacityWeeklyReviewCopy.sectionWatchNext,
          result.watchNext,
          key: const Key('capacity_weekly_review_screen_watch_next'),
        ),
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
