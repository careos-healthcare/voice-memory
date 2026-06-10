import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/one_small_recording_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact "Today's one small recording" card at the top of the Record
/// screen: one prompt, one button — not a task list. Renders nothing
/// without real plan/suggestion evidence.
class OneSmallRecordingCard extends StatelessWidget {
  const OneSmallRecordingCard({
    super.key,
    required this.recording,
    required this.onRecordThis,
  });

  final OneSmallRecording recording;

  /// Called with [OneSmallRecording.prompt] — the Record screen selects it
  /// the same way daily suggestion prompts are selected.
  final ValueChanged<String> onRecordThis;

  @override
  Widget build(BuildContext context) {
    if (!recording.hasRecording || recording.prompt.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const Key('one_small_recording_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF2F6FA),
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
                  style:
                      ArchiveMobileTypography.responsiveSectionTitle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            recording.basedOnLine,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
            ),
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
              style: ArchiveMobileTypography.body(context).copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            recording.supportingLine,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              key: const Key('one_small_recording_record_cta'),
              onPressed: () => onRecordThis(recording.prompt),
              child: const Text(
                OneSmallRecording.recordCtaLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
