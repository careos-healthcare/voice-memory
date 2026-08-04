import 'package:flutter/material.dart';

import '../controllers/live_voice_playback_player.dart';
import '../live_voice_session_presentation.dart';
import 'pitch_contour_overlay_widget.dart';

/// Unified model-reply playback controls with scrubbable F₀ pitch contour.
class LiveVoiceInteractivePlayerCard extends StatelessWidget {
  const LiveVoiceInteractivePlayerCard({
    super.key,
    required this.player,
    required this.pitchContour,
  });

  final LiveVoicePlaybackPlayer player;
  final List<double> pitchContour;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        if (player.totalDuration <= Duration.zero) {
          return const SizedBox.shrink(
            key: Key('live_voice_interactive_player_empty'),
          );
        }

        final theme = Theme.of(context);
        final positionLabel = LiveVoiceSessionPresentation.formatPlaybackClock(
          player.position,
        );
        final durationLabel = LiveVoiceSessionPresentation.formatPlaybackClock(
          player.totalDuration,
        );

        return Semantics(
          label: 'Model reply playback $positionLabel of $durationLabel',
          child: Card(
            key: const Key('live_voice_interactive_player_card'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Voice pitch (F₀ contour)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '$positionLabel / $durationLabel',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PitchContourOverlayWidget(
                    pitchContour: pitchContour,
                    currentPosition: player.position,
                    totalDuration: player.totalDuration,
                    onSeek: player.seek,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        key: const Key('live_voice_playback_rewind'),
                        tooltip: 'Rewind 10 seconds',
                        icon: const Icon(Icons.replay_10_rounded),
                        onPressed: () => player.seek(
                          player.position - const Duration(seconds: 10),
                        ),
                      ),
                      FloatingActionButton.small(
                        key: const Key('live_voice_playback_toggle'),
                        heroTag: 'live_voice_playback_toggle',
                        onPressed: player.isPlaying
                            ? player.pause
                            : player.play,
                        child: Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      IconButton(
                        key: const Key('live_voice_playback_forward'),
                        tooltip: 'Forward 10 seconds',
                        icon: const Icon(Icons.forward_10_rounded),
                        onPressed: () => player.seek(
                          player.position + const Duration(seconds: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
