import 'package:flutter/material.dart';

import '../../features/retention/retention_metrics_tracker.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Focused first-run card after onboarding — no fake day-by-day examples.
class FirstRecordingHandoffCard extends StatelessWidget {
  const FirstRecordingHandoffCard({
    super.key,
    required this.onStartRecording,
    this.wedgePrompt,
  });

  final VoidCallback onStartRecording;
  final String? wedgePrompt;

  @override
  Widget build(BuildContext context) {
    final prompt =
        wedgePrompt ?? ConsumerUiCopy.firstRecordingHandoffDefaultPrompt;

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
            ConsumerUiCopy.firstRecordingHandoffTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ConsumerUiCopy.firstRecordingHandoffBody,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 16, height: 1.45),
          ),
          if (wedgePrompt != null && wedgePrompt!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              ConsumerUiCopy.firstRecordingHandoffPromptLabel,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              wedgePrompt!,
              style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                fontSize: 17,
                height: 1.4,
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              prompt,
              style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                fontSize: 17,
                height: 1.4,
              ),
            ),
          ],
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
              child: const Text(ConsumerUiCopy.firstRecordingHandoffCta),
            ),
          ),
        ],
      ),
    );
  }
}
