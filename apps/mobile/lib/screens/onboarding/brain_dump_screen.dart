import 'dart:async';
import 'dart:math' as math;

import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/evidence_method/record_entry_providers.dart';
import 'package:archiveme_mobile/features/onboarding/brain_dump_copy.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// First-time onboarding capture — warm brain dump with rotating prompts.
class BrainDumpScreen extends ConsumerStatefulWidget {
  const BrainDumpScreen({super.key});

  @override
  ConsumerState<BrainDumpScreen> createState() => _BrainDumpScreenState();
}

class _BrainDumpScreenState extends ConsumerState<BrainDumpScreen> {
  Timer? _elapsedTimer;
  Timer? _promptTimer;
  DateTime? _recordingStartedAt;
  LifeStageLens _activeLens = LifeStageLens.defaultLens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(recordEntrySessionNotifierProvider).setCaptureScreenAttached(true);
      if (AppServices.isInitialized) {
        final settings = await AppServices.instance.userSettings.load();
        if (mounted) {
          setState(() => _activeLens = settings.resolvedLens);
        }
      }
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _promptTimer?.cancel();
    ref.read(recordEntrySessionNotifierProvider).setCaptureScreenAttached(false);
    super.dispose();
  }

  void _startTimers() {
    _recordingStartedAt = DateTime.now();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _recordingStartedAt == null) return;
      final elapsed = DateTime.now().difference(_recordingStartedAt!).inSeconds;
      final notifier = ref.read(recordEntrySessionNotifierProvider);
      notifier.updateBrainDumpElapsed(elapsed);
      if (elapsed >= RecordEntrySessionState.brainDumpMaxSeconds) {
        unawaited(_finishAndContinue());
      }
    });

    _promptTimer?.cancel();
    var promptIndex = ref.read(recordEntrySessionProvider).promptIndex;
    _promptTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final seeds = BrainDumpCopy.promptSeedsFor(_activeLens);
      promptIndex = (promptIndex + 1) % seeds.length;
      ref.read(recordEntrySessionNotifierProvider).rotateBrainDumpPrompt(promptIndex);
    });
  }

  void _stopTimers() {
    _elapsedTimer?.cancel();
    _promptTimer?.cancel();
    _elapsedTimer = null;
    _promptTimer = null;
    _recordingStartedAt = null;
  }

  Future<void> _startRecording() async {
    await ref.read(recordEntrySessionNotifierProvider).startBrainDump();
    if (!mounted) return;
    if (ref.read(recordEntrySessionProvider).phase == RecordEntryPhase.recording) {
      _startTimers();
    }
  }

  Future<void> _finishAndContinue() async {
    _stopTimers();
    if (!mounted) return;
    context.go('/onboarding/generating-insight');
    unawaited(ref.read(recordEntrySessionNotifierProvider).finishBrainDump());
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave your brain dump?'),
        content: const Text(
          'Your recording is still in progress. Stay here to finish, or leave '
          'and we will keep your encrypted audio safe in the background.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordEntrySessionProvider, (previous, next) {
      if (previous?.phase != RecordEntryPhase.recording &&
          next.phase == RecordEntryPhase.recording) {
        _startTimers();
      }
      if (next.phase == RecordEntryPhase.backgroundPaused) {
        _stopTimers();
      }
      if (next.phase == RecordEntryPhase.recording &&
          previous?.phase == RecordEntryPhase.backgroundPaused) {
        _startTimers();
      }
    });

    final session = ref.watch(recordEntrySessionProvider);
    final phase = session.phase;
    final isRecording =
        phase == RecordEntryPhase.recording ||
        phase == RecordEntryPhase.backgroundPaused;
    final isBusy =
        phase == RecordEntryPhase.connecting ||
        phase == RecordEntryPhase.generatingInsight ||
        phase == RecordEntryPhase.processing;

    return PopScope(
      canPop: !session.blocksBackNavigation,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !session.blocksBackNavigation) return;
        unawaited(_confirmLeave());
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: OnboardingAmbientGlow()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      BrainDumpCopy.titleFor(_activeLens),
                      style: OnboardingTypography.title(context),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      BrainDumpCopy.subtitleFor(_activeLens),
                      style: OnboardingTypography.body(context),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: Center(
                        child: _BrainDumpProgressRing(
                          progress: session.brainDumpProgress,
                          elapsedLabel: BrainDumpCopy.formatElapsed(
                            session.elapsedSeconds,
                          ),
                          remainingLabel: BrainDumpCopy.formatRemaining(
                            session.elapsedSeconds,
                            RecordEntrySessionState.brainDumpMaxSeconds,
                          ),
                          isRecording: isRecording,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: Text(
                        BrainDumpCopy.promptAt(
                          session.promptIndex,
                          lens: _activeLens,
                        ),
                        key: ValueKey(session.promptIndex),
                        textAlign: TextAlign.center,
                        style: OnboardingTypography.title(context).copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      BrainDumpCopy.reassurance,
                      textAlign: TextAlign.center,
                      style: OnboardingTypography.label(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (session.errorMessage case final error?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          error,
                          textAlign: TextAlign.center,
                          style: OnboardingTypography.label(color: AppColors.error),
                        ),
                      ),
                    if (phase == RecordEntryPhase.connecting)
                      const Center(child: CircularProgressIndicator())
                    else if (isRecording)
                      FilledButton(
                        key: const Key('brain_dump_finish_button'),
                        onPressed: isBusy ? null : _finishAndContinue,
                        child: const Text(BrainDumpCopy.finishCta),
                      )
                    else
                      FilledButton(
                        key: const Key('brain_dump_start_button'),
                        onPressed: isBusy ? null : _startRecording,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          foregroundColor: AppColors.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(BrainDumpCopy.startCta),
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrainDumpProgressRing extends StatelessWidget {
  const _BrainDumpProgressRing({
    required this.progress,
    required this.elapsedLabel,
    required this.remainingLabel,
    required this.isRecording,
  });

  final double progress;
  final String elapsedLabel;
  final String remainingLabel;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    const size = 220.0;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrainDumpRingPainter(
          progress: progress,
          active: isRecording,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                elapsedLabel,
                style: OnboardingTypography.title(context).copyWith(
                  fontSize: 36,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                BrainDumpCopy.timerLabel,
                style: OnboardingTypography.label(),
              ),
              const SizedBox(height: 4),
              Text(
                remainingLabel,
                style: OnboardingTypography.label(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrainDumpRingPainter extends CustomPainter {
  _BrainDumpRingPainter({required this.progress, required this.active});

  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const stroke = 12.0;

    final trackPaint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = active
          ? AppColors.accentPrimary
          : AppColors.accentPrimary.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BrainDumpRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.active != active;
  }
}