import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/capacity_loop/capacity_decision_outcome_models.dart';
import '../features/capacity_loop/capacity_pull_reason_models.dart';
import '../features/capacity_loop/capacity_return_trigger_engine.dart';
import '../features/capacity_loop/capacity_return_trigger_models.dart';
import '../features/capacity_loop/low_effort_yes_capture_copy.dart';
import '../features/capacity_loop/low_effort_yes_capture_engine.dart';
import '../features/capacity_loop/low_effort_yes_capture_models.dart';
import '../features/capacity_loop/quick_capture_friction_engine.dart';
import '../features/capacity_loop/quick_capture_friction_models.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/quick_capture_friction_card.dart';
import '../widgets/capacity_return_trigger_card.dart';

/// Quick yes capture screen — fixed pull + decision options only.
class LowEffortYesCaptureScreen extends StatefulWidget {
  const LowEffortYesCaptureScreen({
    super.key,
    this.engine = const LowEffortYesCaptureEngine(),
  });

  final LowEffortYesCaptureEngine engine;

  @override
  State<LowEffortYesCaptureScreen> createState() =>
      _LowEffortYesCaptureScreenState();
}

class _LowEffortYesCaptureScreenState extends State<LowEffortYesCaptureScreen> {
  LowEffortYesCaptureResult? _result;
  QuickCaptureFrictionResult? _frictionResult;
  CapacityReturnTriggerResult? _returnTriggerResult;
  bool _loading = true;
  bool _capacityWedgeActive = false;
  String? _selectedPullReasonId;
  String? _selectedOutcomeId;
  String? _selectedTimingId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _result = LowEffortYesCaptureResult.hidden;
        _loading = false;
      });
      return;
    }

    final loop = await LoopModeCoordinator.loadActive();
    final cohort = await AcquisitionCohortCoordinator.load();
    final capacityWedgeActive =
        (loop?.isCapacityYes ?? false) ||
            cohort?.cohortId == AcquisitionCohortId.capacityYesDirect;

    if (!mounted) return;
    setState(() {
      _capacityWedgeActive = capacityWedgeActive;
      _result = widget.engine.build(
        LowEffortYesCaptureInput(
          capacityWedgeActive: capacityWedgeActive,
          sampleMode: false,
          screenshotMode: false,
        ),
      );
      _loading = false;
    });
  }

  Future<void> _save() async {
    final pullReasonId = _selectedPullReasonId;
    final timingId = _selectedTimingId;
    if (pullReasonId == null ||
        pullReasonId.isEmpty ||
        timingId == null ||
        timingId.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final saveResult = await widget.engine.saveQuickCapture(
      journal: AppServices.instance.journalStore,
      request: LowEffortYesCaptureSaveRequest(
        pullReasonId: pullReasonId,
        timingId: timingId,
        outcomeId: _selectedOutcomeId,
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _frictionResult = const QuickCaptureFrictionEngine().buildAfterQuickSave(
        relatedEntryId: saveResult.entryId,
        capacityWedgeActive: _capacityWedgeActive,
      );
    });
  }

  Future<void> _dismissAfterFriction() async {
    final entries = await AppServices.instance.journalStore.loadAll();
    final returnTrigger = const CapacityReturnTriggerEngine().buildFromJournal(
      entries: entries,
      capacityLoopActive: _capacityWedgeActive,
      capacityCohortActive: false,
      surface: CapacityReturnTriggerSurface.completion,
    );
    if (!mounted) return;
    if (returnTrigger.showCard) {
      setState(() {
        _frictionResult = null;
        _returnTriggerResult = returnTrigger;
      });
      return;
    }
    if (!mounted) return;
    context.pop(true);
  }

  void _dismissAfterReturnTrigger() {
    if (!mounted) return;
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PushedScreenShell(
        title: LowEffortYesCaptureCopy.title,
        fallbackRoute: LowEffortYesCaptureCopy.recordRoute,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final result = _result!;
    if (!result.showCard) {
      return PushedScreenShell(
        title: LowEffortYesCaptureCopy.title,
        fallbackRoute: LowEffortYesCaptureCopy.recordRoute,
        body: Center(
          child: Text(
            LowEffortYesCaptureCopy.recordInsteadCta,
            key: const Key('low_effort_yes_capture_screen_unavailable'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
        ),
      );
    }

    final frictionResult = _frictionResult;
    if (frictionResult != null && frictionResult.showCard) {
      return PushedScreenShell(
        title: frictionResult.title,
        fallbackRoute: LowEffortYesCaptureCopy.recordRoute,
        body: SingleChildScrollView(
          key: const Key('low_effort_yes_capture_friction_completion'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: QuickCaptureFrictionCard(
            result: frictionResult,
            onSaved: () => unawaited(_dismissAfterFriction()),
          ),
        ),
      );
    }

    final returnTriggerResult = _returnTriggerResult;
    if (returnTriggerResult != null && returnTriggerResult.showCard) {
      return PushedScreenShell(
        title: returnTriggerResult.title,
        fallbackRoute: LowEffortYesCaptureCopy.recordRoute,
        body: SingleChildScrollView(
          key: const Key('low_effort_yes_capture_return_trigger_completion'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: CapacityReturnTriggerCard(
            result: returnTriggerResult,
            onPrimaryDismiss: _dismissAfterReturnTrigger,
          ),
        ),
      );
    }

    return PushedScreenShell(
      title: result.title,
      fallbackRoute: LowEffortYesCaptureCopy.recordRoute,
      body: SingleChildScrollView(
        key: const Key('low_effort_yes_capture_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.body,
              key: const Key('low_effort_yes_capture_screen_body'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              result.timingSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final id in result.timingIds)
                  ChoiceChip(
                    key: Key('low_effort_yes_capture_timing_$id'),
                    label: Text(LowEffortYesCaptureCopy.labelForTiming(id)),
                    selected: _selectedTimingId == id,
                    onSelected: _saving
                        ? null
                        : (selected) => setState(
                            () => _selectedTimingId = selected ? id : null,
                          ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              result.pullSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            RadioGroup<String>(
              groupValue: _selectedPullReasonId,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _selectedPullReasonId = value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final id in result.pullReasonIds)
                    RadioListTile<String>(
                      key: Key('low_effort_yes_capture_pull_$id'),
                      title: Text(
                        LowEffortYesCaptureCopy.labelForPullReason(id),
                      ),
                      value: id,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              result.decisionSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            RadioGroup<String>(
              groupValue: _selectedOutcomeId,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _selectedOutcomeId = value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final id in result.decisionOutcomeIds)
                    RadioListTile<String>(
                      key: Key('low_effort_yes_capture_outcome_$id'),
                      title: Text(LowEffortYesCaptureCopy.labelForOutcome(id)),
                      value: id,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('low_effort_yes_capture_save_button'),
              onPressed:
                  _saving ||
                      _selectedPullReasonId == null ||
                      _selectedTimingId == null
                  ? null
                  : _save,
              child: Text(result.primaryCtaLabel),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('low_effort_yes_capture_record_instead_button'),
              onPressed: _saving
                  ? null
                  : () => context.push(LowEffortYesCaptureCopy.recordRoute),
              child: Text(result.secondaryCtaLabel),
            ),
          ],
        ),
      ),
    );
  }
}
