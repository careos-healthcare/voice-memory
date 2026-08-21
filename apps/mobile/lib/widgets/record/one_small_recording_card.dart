import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pressure_retention/one_small_recording_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact "One small recording" card at the top of the Record
/// screen: one prompt, one button — not a task list. Renders nothing
/// without real plan/suggestion evidence.
class OneSmallRecordingCard extends StatelessWidget {
  const OneSmallRecordingCard({
    required this.recording, required this.onRecordThis, super.key,
    this.showRecordCta = true,
    this.ctaLabel = OneSmallRecording.recordCtaLabel,
  });

  final OneSmallRecording recording;

  /// Called with [OneSmallRecording.prompt] — the Record screen selects it
  /// the same way daily suggestion prompts are selected.
  final ValueChanged<String> onRecordThis;
  final bool showRecordCta;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    if (!recording.hasRecording || recording.prompt.isEmpty) {
      return const SizedBox.shrink();
    }
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.oneSmallRecordingSeen,
      oncePerSession: true,
    );

    return Container(
      key: const Key('one_small_recording_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      // Accent border marks this as the one primary starter on the screen.
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF2F6FA))
          .copyWith(
            border: Border.all(color: AppColors.accentPrimary, width: 1.5),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mic_none,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  recording.title,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            recording.basedOnLine,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              recording.prompt,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            recording.supportingLine,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (showRecordCta) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                key: const Key('one_small_recording_record_cta'),
                onPressed: () => onRecordThis(recording.prompt),
                child: Text(ctaLabel, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Center(
            child: Text(
              OneSmallRecording.restCanWaitLine,
              key: const Key('one_small_recording_rest_can_wait'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}