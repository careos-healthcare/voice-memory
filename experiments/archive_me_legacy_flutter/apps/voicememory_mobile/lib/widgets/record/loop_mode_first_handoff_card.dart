import 'package:flutter/material.dart';

import '../../features/loop_mode/loop_mode_model.dart';
import '../../features/retention/retention_metrics_tracker.dart';
import '../../product/loop_mode_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Loop-specific first recording handoff — no fake examples.
class LoopModeFirstHandoffCard extends StatelessWidget {
  const LoopModeFirstHandoffCard({
    super.key,
    required this.loop,
    required this.onStartRecording,
    this.showRecordCta = true,
  });

  final LoopMode loop;
  final VoidCallback onStartRecording;
  final bool showRecordCta;

  @override
  Widget build(BuildContext context) {
    final title = _handoffTitle(loop);
    final body = _handoffBody(loop);
    final prompt = _handoffPrompt(loop);
    final cta = loop.isProveEnough
        ? LoopModeCopy.proveEnoughHandoffCta
        : loop.isCapacityYes
        ? LoopModeCopy.capacityHandoffCta
        : 'Record this moment';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            prompt,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
              height: 1.4,
            ),
          ),
          if (showRecordCta) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () {
                  RetentionMetricsTracker.track(
                    RetentionMetricsTracker.firstRecordCtaTapped,
                  );
                  onStartRecording();
                },
                child: Text(cta),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _handoffTitle(LoopMode loop) {
    if (loop.isCapacityYes) return LoopModeCopy.capacityHandoffTitle;
    if (loop.isProveEnough) return LoopModeCopy.proveEnoughHandoffTitle;
    return loop.title;
  }

  String _handoffBody(LoopMode loop) {
    if (loop.isCapacityYes) return LoopModeCopy.capacityHandoffBody;
    if (loop.isProveEnough) return LoopModeCopy.proveEnoughHandoffBody;
    return loop.shortPromise;
  }

  String _handoffPrompt(LoopMode loop) {
    if (loop.isCapacityYes) return LoopModeCopy.capacityHandoffPrompt;
    if (loop.isProveEnough) return LoopModeCopy.proveEnoughHandoffPrompt;
    return loop.activePrompt;
  }
}
