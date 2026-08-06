import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/design/archive_mobile_spacing.dart';
import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/features/acquisition/acquisition_cohort_coordinator.dart';
import 'package:voicememory_mobile/features/acquisition/acquisition_cohort_model.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:voicememory_mobile/product/acquisition_start_copy.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';

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
    final steps = AcquisitionStartCopy.capacityHowItWorksSteps;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AcquisitionStartCopy.capacityHowItWorksCta),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
                child: Text(
                  '${i + 1}. ${steps[i]}',
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
              ),
          ],
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

  Widget _capacityFirstPathCard(BuildContext context) {
    return Container(
      key: const Key('loop_start_capacity_first_path_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AcquisitionStartCopy.capacityFirstPathLabel,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AcquisitionStartCopy.capacityFirstPathHeadline,
            style: ArchiveMobileTypography.explanationBody(context),
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
                const SizedBox(height: AppSpacing.md),
                _capacityFirstPathCard(context),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AcquisitionStartCopy.capacityTimingFlex,
                  key: const Key('loop_start_capacity_timing_flex'),
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
