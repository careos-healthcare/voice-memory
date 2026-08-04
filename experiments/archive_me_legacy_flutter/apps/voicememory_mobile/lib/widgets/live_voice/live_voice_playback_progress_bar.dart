import 'package:flutter/material.dart';

import '../../../features/live_audio/presentation/controllers/live_voice_playback_player.dart';
import '../../../features/live_audio/presentation/live_voice_session_presentation.dart';
import '../../../theme/voicememory_colors.dart';

/// Synchronized model-reply playback progress for the live voice session.
class LiveVoicePlaybackProgressBar extends StatelessWidget {
  const LiveVoicePlaybackProgressBar({super.key, required this.player});

  final LiveVoicePlaybackPlayer player;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        if (player.totalDuration <= Duration.zero) {
          return const SizedBox.shrink(
            key: Key('live_voice_playback_progress_empty'),
          );
        }

        final progress = player.totalDuration.inMilliseconds == 0
            ? 0.0
            : player.position.inMilliseconds /
                  player.totalDuration.inMilliseconds;

        return Semantics(
          label:
              'Model reply playback ${LiveVoiceSessionPresentation.formatPlaybackClock(player.position)} '
              'of ${LiveVoiceSessionPresentation.formatPlaybackClock(player.totalDuration)}',
          child: Column(
            key: const Key('live_voice_playback_progress'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  color: VoiceMemoryColors.captureSuccess,
                  backgroundColor: VoiceMemoryColors.captureSuccess.withValues(
                    alpha: 0.18,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LiveVoiceSessionPresentation.formatPlaybackClock(
                      player.position,
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: VoiceMemoryColors.textSecondary,
                    ),
                  ),
                  Text(
                    LiveVoiceSessionPresentation.formatPlaybackClock(
                      player.totalDuration,
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: VoiceMemoryColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
