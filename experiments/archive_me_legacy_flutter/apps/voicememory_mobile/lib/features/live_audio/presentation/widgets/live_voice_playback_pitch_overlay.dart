import 'package:flutter/material.dart';

import '../controllers/live_voice_playback_player.dart';
import 'pitch_contour_overlay_widget.dart';

/// Binds [PitchContourOverlayWidget] to [LiveVoicePlaybackPlayer] seek state.
class LiveVoicePlaybackPitchOverlay extends StatelessWidget {
  const LiveVoicePlaybackPitchOverlay({
    super.key,
    required this.player,
    required this.pitchContour,
  });

  final LiveVoicePlaybackPlayer player;
  final List<double> pitchContour;

  @override
  Widget build(BuildContext context) {
    if (pitchContour.isEmpty || player.totalDuration <= Duration.zero) {
      return const SizedBox.shrink(key: Key('live_voice_pitch_overlay_empty'));
    }

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        return PitchContourOverlayWidget(
          key: const Key('live_voice_pitch_overlay'),
          pitchContour: pitchContour,
          currentPosition: player.position,
          totalDuration: player.totalDuration,
          onSeek: player.seek,
        );
      },
    );
  }
}
