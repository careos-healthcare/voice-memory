import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/capacity_loop_copy.dart';
import '../features/capacity_loop/capacity_loop_engine.dart';
import '../features/capacity_loop/capacity_loop_models.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/capacity_loop/capacity_cost_store.dart';
import '../features/capacity_loop/capacity_decision_outcome_store.dart';
import '../features/capacity_loop/before_yes_copy.dart';
import '../features/capacity_loop/before_yes_engine.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Full capacity yes loop screen — cautious summaries, no journal text.
class CapacityLoopScreen extends StatefulWidget {
  const CapacityLoopScreen({
    super.key,
    this.journalService,
    this.engine = const CapacityLoopEngine(),
    CapacityLoopResult? initialResult,
    this.capacityLoopActive = false,
    this.capacityCohortActive = false,
  }) : _initialResult = initialResult;

  final JournalService? journalService;
  final CapacityLoopEngine engine;
  final bool capacityLoopActive;
  final bool capacityCohortActive;
  final CapacityLoopResult? _initialResult;

  @override
  State<CapacityLoopScreen> createState() => _CapacityLoopScreenState();
}

class _CapacityLoopScreenState extends State<CapacityLoopScreen> {
  CapacityLoopResult? _result;
  BeforeYesPauseResult? _beforeYesPause;
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
        _result = widget.engine.build(
          CapacityLoopInput(
            realSavedMomentCount: 0,
            capacityEvidenceCount: 0,
            capacityLoopActive: false,
            capacityCohortActive: false,
            sampleMode: true,
          ),
        );
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
      _beforeYesPause = const BeforeYesPauseEngine().buildFromJournal(
        entries: entries,
        capacityLoopActive: loopActive,
        capacityCohortActive: cohortActive,
        capacityLoopHasCard: _result!.hasCard,
        costLaterCheckinVisible: false,
        costRecords: CapacityCostStore.cached,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: CapacityLoopCopy.title,
      fallbackRoute: CapacityLoopCopy.archiveHomeRoute,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('capacity_loop_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(context, _result!),
            ),
    );
  }

  Widget _content(BuildContext context, CapacityLoopResult result) {
    if (!result.hasCard) {
      return _insufficientState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.title,
          key: const Key('capacity_loop_screen_title'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.subtitle,
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        if (result.evidenceCountLabel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            result.evidenceCountLabel,
            key: const Key('capacity_loop_screen_evidence'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (result.costEvidenceLabel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.costEvidenceLabel,
            key: const Key('capacity_loop_screen_cost_evidence'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (result.outcomeEvidenceLabel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.outcomeEvidenceLabel,
            key: const Key('capacity_loop_screen_outcome_evidence'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _section(context, result.repeatedLabel, result.whatRepeated,
            key: const Key('capacity_loop_screen_what_repeated')),
        _section(context, result.costLaterLabel, result.costLater,
            key: const Key('capacity_loop_screen_cost_later')),
        _section(context, result.watchNextLabel, result.watchNext,
            key: const Key('capacity_loop_screen_watch_next')),
        if (_beforeYesPause?.showOnCapacityLoop == true) ...[
          const SizedBox(height: AppSpacing.sm),
          _section(
            context,
            _beforeYesPause!.loopSectionTitle,
            _beforeYesPause!.loopSectionBody,
            key: const Key('capacity_loop_screen_before_next_yes'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('capacity_loop_screen_before_yes_button'),
            onPressed: () => context.push(
              BeforeYesCopy.recordRouteWithPrompt(BeforeYesCopy.recordPrompt),
            ),
            child: Text(_beforeYesPause!.pauseCtaLabel),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('capacity_loop_screen_primary_button'),
          onPressed: () => context.push(result.primaryRoute),
          child: Text(result.primaryCtaLabel),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('capacity_loop_screen_share_hint'),
          onPressed: null,
          child: Text(result.shareCopy),
        ),
      ],
    );
  }

  Widget _insufficientState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          CapacityLoopCopy.title,
          key: const Key('capacity_loop_screen_insufficient_title'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          CapacityLoopCopy.emptyStateBody,
          key: const Key('capacity_loop_screen_insufficient_body'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => context.push(CapacityLoopCopy.recordRoute),
          child: Text(CapacityLoopCopy.saveYesMomentShortCta),
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
