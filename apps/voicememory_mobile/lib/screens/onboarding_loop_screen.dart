import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/activation/activation_tracker.dart';
import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/loop_mode/loop_mode_model.dart';
import '../product/loop_mode_copy.dart';
import '../router/onboarding_gate.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Focused loop selection after acquisition intent — prove_enough is default.
class OnboardingLoopScreen extends StatefulWidget {
  const OnboardingLoopScreen({super.key});

  @override
  State<OnboardingLoopScreen> createState() => _OnboardingLoopScreenState();
}

class _OnboardingLoopScreenState extends State<OnboardingLoopScreen> {
  String? _selectedId = LoopModeIds.proveEnough;
  bool _busy = false;

  static const _options = [
    (
      id: LoopModeIds.proveEnough,
      title: LoopModeCopy.proveEnoughTitle,
      body: LoopModeCopy.proveEnoughPromise,
      primary: true,
    ),
    (
      id: LoopModeIds.capacityYes,
      title: 'Saying yes when I have no capacity',
      body: 'Catch the moment you agree before checking whether you have room.',
      primary: false,
    ),
    (
      id: LoopModeIds.notSure,
      title: LoopModeCopy.notSureTitle,
      body: LoopModeCopy.notSurePromise,
      primary: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackProveDefaultShown();
    unawaited(_loadPreselection());
  }

  Future<void> _loadPreselection() async {
    final active = await LoopModeCoordinator.loadActive();
    if (active == null || !mounted) return;
    setState(() => _selectedId = active.id);
  }

  Future<void> _finish(String loopId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await LoopModeCoordinator.activate(loopId);
      if (loopId == LoopModeIds.proveEnough) {
        ActivationTracker.trackProveDefaultStarted();
      }
      await AppServices.instance.prefs.setOnboardingCompleted(true);
      onboardingGate.markComplete();
      if (!mounted) return;
      context.go('/record');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    await _finish(LoopModeIds.proveEnough);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('onboarding_loop_skip'),
                  onPressed: _busy ? null : _skip,
                  child: const Text(LoopModeCopy.onboardingSkip),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                LoopModeCopy.onboardingTitle,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontSize: 26, height: 1.3),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    for (final opt in _options) ...[
                      _LoopOptionCard(
                        title: opt.title,
                        body: opt.body,
                        primary: opt.primary,
                        selected: _selectedId == opt.id,
                        onTap: _busy
                            ? null
                            : () => setState(() => _selectedId = opt.id),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              FilledButton(
                key: const Key('onboarding_loop_start_cta'),
                onPressed: _busy || _selectedId == null
                    ? null
                    : () => _finish(_selectedId!),
                child: const Text(LoopModeCopy.onboardingStartCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoopOptionCard extends StatelessWidget {
  const _LoopOptionCard({
    required this.title,
    required this.body,
    required this.primary,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String body;
  final bool primary;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(color: AppColors.accentPrimary, width: 2)
        : Border.all(color: AppColors.borderSubtle);
    final bg = primary
        ? AppColors.accentPrimary.withValues(alpha: 0.06)
        : AppColors.backgroundPrimary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: border,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
