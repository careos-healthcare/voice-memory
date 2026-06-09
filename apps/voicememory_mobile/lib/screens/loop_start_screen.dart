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
import '../router/onboarding_gate.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Sharp loop-specific acquisition start — cohort / deep-link entry.
class LoopStartScreen extends StatefulWidget {
  const LoopStartScreen({
    super.key,
    required this.cohortId,
  });

  final AcquisitionCohortId cohortId;

  @visibleForTesting
  static LoopStartScreen capacity() => const LoopStartScreen(
        cohortId: AcquisitionCohortId.capacityYesDirect,
      );

  @visibleForTesting
  static LoopStartScreen proveEnough() => const LoopStartScreen(
        cohortId: AcquisitionCohortId.proveEnoughDirect,
      );

  @visibleForTesting
  static LoopStartScreen generic() => const LoopStartScreen(
        cohortId: AcquisitionCohortId.genericArchive,
      );

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
    await AcquisitionCohortCoordinator.markStartScreenViewed(
      widget.cohortId,
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final showSecondary = widget.cohortId.usesFastPath;

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
                style: ArchiveMobileTypography.responsivePageTitle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _body,
                style: ArchiveMobileTypography.explanationBody(context),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: _busy ? null : _startLoop,
                child: Text(_primaryCta),
              ),
              if (showSecondary) ...[
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
