import 'package:archiveme_mobile/features/live_audio/presentation/live_voice_session_presentation.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

class LiveVoiceConnectionPill extends StatelessWidget {
  const LiveVoiceConnectionPill({required this.visualState, super.key});

  final LiveVoiceVisualState visualState;

  @override
  Widget build(BuildContext context) {
    final label = LiveVoiceSessionPresentation.connectionPillLabel(visualState);
    final isLive =
        visualState == LiveVoiceVisualState.listening ||
        visualState == LiveVoiceVisualState.speaking;
    final color = switch (visualState) {
      LiveVoiceVisualState.error => AppColors.textSecondary,
      LiveVoiceVisualState.reconnecting => AppColors.accentPrimary,
      LiveVoiceVisualState.connecting => AppColors.textSecondary,
      _ => AppColors.accentPrimary,
    };

    return Container(
      key: const Key('live_voice_connection_pill'),
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isLive ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}