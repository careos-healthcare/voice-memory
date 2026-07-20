import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/live_audio/presentation/live_voice_session_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

class LiveVoiceTranscriptPreview extends StatelessWidget {
  const LiveVoiceTranscriptPreview({
    super.key,
    required this.transcript,
  });

  final String transcript;

  @override
  Widget build(BuildContext context) {
    final trimmed = transcript.trim();
    final hasText = trimmed.isNotEmpty;

    return Semantics(
      label: hasText ? 'Live transcript: $trimmed' : LiveVoiceSessionCopy.transcriptEmpty,
      child: Container(
        key: const Key('live_voice_transcript_preview'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: AppColors.backgroundSecondary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LiveVoiceSessionCopy.transcriptTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasText ? trimmed : LiveVoiceSessionCopy.transcriptEmpty,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: hasText
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
