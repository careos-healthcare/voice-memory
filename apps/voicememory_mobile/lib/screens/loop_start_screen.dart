import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../design/archive_mobile_typography.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/loop_mode/loop_mode_model.dart';
import '../product/acquisition_start_copy.dart';
import '../product/archive_positioning_copy.dart';
import '../router/onboarding_gate.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Sharp loop-specific acquisition start — cohort / deep-link entry.
class LoopStartScreen extends StatefulWidget {
  const LoopStartScreen({super.key, required this.cohortId});

  final AcquisitionCohortId cohortId;

  @visibleForTesting
  static LoopStartScreen capacity() =>
      const LoopStartScreen(cohortId: AcquisitionCohortId.capacityYesDirect);

  @visibleForTesting
  static LoopStartScreen proveEnough() =>
      const LoopStartScreen(cohortId: AcquisitionCohortId.proveEnoughDirect);

  @visibleForTesting
  static LoopStartScreen generic() =>
      const LoopStartScreen(cohortId: AcquisitionCohortId.genericArchive);

  @override
  State<LoopStartScreen> createState() => _LoopStartScreenState();
}

class _LoopStartScreenState extends State<LoopStartScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await AcquisitionCohortCoordinator.assignFromRoutePath(
      widget.cohortId.startRoutePath,
    );
    await AcquisitionCohortCoordinator.markStartScreenViewed(widget.cohortId);
  }

  bool get _isCapacityStart =>
      widget.cohortId == AcquisitionCohortId.capacityYesDirect;

  String get _title {
    switch (widget.cohortId) {
      case AcquisitionCohortId.capacityYesDirect:
        return AcquisitionStartCopy.capacityTitle;
      case AcquisitionCohortId.proveEnoughDirect:
        return AcquisitionStartCopy.proveTitle;
      case AcquisitionCohortId.genericArchive:
      case AcquisitionCohortId.unknown:
        return AcquisitionStartCopy.genericTitle;
    }
  }

  String get _body {
    switch (widget.cohortId) {
      case AcquisitionCohortId.capacityYesDirect:
        return AcquisitionStartCopy.capacityBody;
      case AcquisitionCohortId.proveEnoughDirect:
        return AcquisitionStartCopy.proveBody;
      case AcquisitionCohortId.genericArchive:
      case AcquisitionCohortId.unknown:
        return AcquisitionStartCopy.genericBody;
    }
  }

  String get _primaryCta {
    if (widget.cohortId == AcquisitionCohortId.capacityYesDirect) {
      return AcquisitionStartCopy.capacityStartCta;
    }
    return widget.cohortId == AcquisitionCohortId.genericArchive ||
            widget.cohortId == AcquisitionCohortId.unknown
        ? AcquisitionStartCopy.startGenericCta
        : AcquisitionStartCopy.startLoopCta;
  }

  Future<void> _startLoop() async {
    if (_busy) return;
    setState(() => _busy = true);

    final loopId = widget.cohortId.defaultLoopId ?? LoopModeIds.notSure;
    await LoopModeCoordinator.activate(loopId);
    await AcquisitionCohortCoordinator.markLoopSelected(loopId);
    await AcquisitionCohortCoordinator.markStartCtaTapped();
    await AppServices.instance.prefs.setOnboardingCompleted(true);
    onboardingGate.markComplete();

    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/record');
  }

  void _chooseAnotherLoop() {
    context.go('/onboarding-loop');
  }

  void _showHowItWorks() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AcquisitionStartCopy.capacityHowItWorksCta),
        content: Text(
          AcquisitionStartCopy.capacityHowItWorksBody,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showChooseAnother = widget.cohortId.usesFastPath && !_isCapacityStart;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: ArchiveMobileSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              Text(
                _title,
                key: const Key('loop_start_title'),
                style: ArchiveMobileTypography.responsivePageTitle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _body,
                key: const Key('loop_start_body'),
                style: ArchiveMobileTypography.explanationBody(context),
              ),
              if (!_isCapacityStart &&
                  (widget.cohortId == AcquisitionCohortId.genericArchive ||
                      widget.cohortId == AcquisitionCohortId.unknown)) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AcquisitionStartCopy.genericFirstPathLine,
                  key: const Key('loop_start_generic_first_path_line'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (_isCapacityStart) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AcquisitionStartCopy.capacityPathContext,
                  key: const Key('loop_start_capacity_path_context'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AcquisitionStartCopy.capacityTimingFlex,
                  key: const Key('loop_start_capacity_timing_flex'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AcquisitionStartCopy.capacityFirstPathLine,
                  key: const Key('loop_start_capacity_first_path_line'),
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < AcquisitionStartCopy.capacitySteps.length; i++)
                  Padding(
                    key: Key('loop_start_capacity_step_$i'),
                    padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}.',
                          style: ArchiveMobileTypography.body(context).copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            AcquisitionStartCopy.capacitySteps[i],
                            style: ArchiveMobileTypography.body(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AcquisitionStartCopy.capacityProductLine,
                  key: const Key('loop_start_capacity_product_line'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const Spacer(flex: 2),
              FilledButton(
                key: const Key('loop_start_primary_button'),
                onPressed: _busy ? null : _startLoop,
                child: Text(_primaryCta),
              ),
              if (_isCapacityStart) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('loop_start_how_it_works_button'),
                  onPressed: _busy ? null : _showHowItWorks,
                  child: const Text(AcquisitionStartCopy.capacityHowItWorksCta),
                ),
              ] else if (showChooseAnother) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: _busy ? null : _chooseAnotherLoop,
                  child: const Text(AcquisitionStartCopy.chooseAnotherLoop),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
