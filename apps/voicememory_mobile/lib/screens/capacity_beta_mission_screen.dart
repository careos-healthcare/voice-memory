import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/capacity_loop/capacity_activation_fit_store.dart';
import '../features/capacity_loop/capacity_beta_mission_copy.dart';
import '../features/capacity_loop/capacity_beta_mission_engine.dart';
import '../features/capacity_loop/capacity_beta_mission_models.dart';
import '../features/capacity_loop/capacity_beta_mission_store.dart';
import '../features/capacity_loop/capacity_boundary_response_store.dart';
import '../features/capacity_loop/capacity_cost_store.dart';
import '../features/capacity_loop/capacity_decision_outcome_store.dart';
import '../features/capacity_loop/capacity_pull_reason_store.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/pro_interest/pro_interest_store.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Guided 7-day capacity beta mission — task list only, no private text.
class CapacityBetaMissionScreen extends StatefulWidget {
  const CapacityBetaMissionScreen({
    super.key,
    this.journalService,
    this.engine = const CapacityBetaMissionEngine(),
    this.store,
  });

  final JournalService? journalService;
  final CapacityBetaMissionEngine engine;
  final CapacityBetaMissionStore? store;

  @override
  State<CapacityBetaMissionScreen> createState() =>
      _CapacityBetaMissionScreenState();
}

class _CapacityBetaMissionScreenState extends State<CapacityBetaMissionScreen> {
  CapacityBetaMissionResult? _result;
  bool _loading = true;

  CapacityBetaMissionStore get _store =>
      widget.store ?? CapacityBetaMissionStore.instance();

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
    await CapacityBetaMissionStore.ensureLoaded();

    await _store.markStarted();

    final entries = await journal.loadAll();
    final loop = await LoopModeCoordinator.loadActive();
    final cohort = await AcquisitionCohortCoordinator.load();
    final capacityLoopActive = loop?.isCapacityYes ?? false;
    final capacityCohortActive =
        cohort?.cohortId == AcquisitionCohortId.capacityYesDirect;

    final result = widget.engine.buildFromJournal(
      entries: entries,
      capacityLoopActive: capacityLoopActive,
      capacityCohortActive: capacityCohortActive,
      fitRecord: CapacityActivationFitStore.cached,
      boundarySelection: CapacityBoundaryResponseStore.cached,
      proInterestState: ProInterestStore.cached,
      missionRecord: CapacityBetaMissionStore.cached,
    );

    if (CapacityBetaMissionEngine.shouldMarkCompleted(result)) {
      await _store.markCompleted();
    }

    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _dismiss() async {
    await _store.dismiss();
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PushedScreenShell(
        title: CapacityBetaMissionCopy.title,
        fallbackRoute: '/support-feedback',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final result = _result!;
    if (!result.hasMission) {
      return PushedScreenShell(
        title: CapacityBetaMissionCopy.title,
        fallbackRoute: '/support-feedback',
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            CapacityBetaMissionCopy.calmNote,
            key: const Key('capacity_beta_mission_empty'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
        ),
      );
    }

    return PushedScreenShell(
      title: CapacityBetaMissionCopy.title,
      fallbackRoute: '/support-feedback',
      body: SingleChildScrollView(
        key: const Key('capacity_beta_mission_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.subtitle,
              key: const Key('capacity_beta_mission_subtitle'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.calmNote,
              key: const Key('capacity_beta_mission_calm_note'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.skipNote,
              key: const Key('capacity_beta_mission_skip_note'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              result.progressLabel,
              key: const Key('capacity_beta_mission_progress'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final task in result.tasks)
              _taskRow(context, task),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('capacity_beta_mission_open_beta_signals'),
                onPressed: () => context.push(result.betaSignalsRoute),
                child: Text(result.viewBetaSignalsCta),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('capacity_beta_mission_dismiss'),
                onPressed: _dismiss,
                child: Text(result.dismissCta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskRow(BuildContext context, CapacityBetaMissionTask task) {
    return Padding(
      key: Key('capacity_beta_mission_task_${task.id}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.label,
                  key: Key('capacity_beta_mission_task_label_${task.id}'),
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
              ),
              Text(
                task.statusLabel,
                key: Key('capacity_beta_mission_task_status_${task.id}'),
                style: ArchiveMobileTypography.explanationBody(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (task.status != CapacityBetaMissionTaskStatus.done &&
              task.status != CapacityBetaMissionTaskStatus.notStarted) ...[
            if (task.hintLabel.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                task.hintLabel,
                key: Key('capacity_beta_mission_task_hint_${task.id}'),
                style: ArchiveMobileTypography.explanationBody(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: Key('capacity_beta_mission_task_cta_${task.id}'),
                onPressed: () => context.push(task.route),
                child: Text(task.ctaLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
