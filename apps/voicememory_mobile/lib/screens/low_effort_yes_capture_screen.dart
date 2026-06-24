import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/capacity_loop/capacity_decision_outcome_models.dart';
import '../features/capacity_loop/capacity_pull_reason_models.dart';
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
  bool _loading = true;
  bool _capacityWedgeActive = false;
  String? _selectedPullReasonId;
  String? _selectedOutcomeId;
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
    if (pullReasonId == null || pullReasonId.isEmpty) return;
    setState(() => _saving = true);
    final saveResult = await widget.engine.saveQuickCapture(
      journal: AppServices.instance.journalStore,
      request: LowEffortYesCaptureSaveRequest(
        pullReasonId: pullReasonId,
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

  void _dismissAfterFriction() {
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
            onSaved: _dismissAfterFriction,
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
              result.pullSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final id in result.pullReasonIds)
              RadioListTile<String>(
                key: Key('low_effort_yes_capture_pull_$id'),
                title: Text(LowEffortYesCaptureCopy.labelForPullReason(id)),
                value: id,
                groupValue: _selectedPullReasonId,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selectedPullReasonId = value),
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              result.decisionSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final id in result.decisionOutcomeIds)
              RadioListTile<String>(
                key: Key('low_effort_yes_capture_outcome_$id'),
                title: Text(LowEffortYesCaptureCopy.labelForOutcome(id)),
                value: id,
                groupValue: _selectedOutcomeId,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selectedOutcomeId = value),
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('low_effort_yes_capture_save_button'),
              onPressed: _saving || _selectedPullReasonId == null ? null : _save,
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
