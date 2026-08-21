import 'package:archiveme_mobile/features/live_audio/presentation/live_voice_session_presentation.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/widgets/indigo_capture_waveform.dart';
import 'package:archiveme_mobile/widgets/live_voice/live_voice_speaking_waveform.dart';
import 'package:flutter/material.dart';

class LiveVoiceStatusCard extends StatelessWidget {
  const LiveVoiceStatusCard({
    required this.visualState, required this.seconds, super.key,
    this.playbackQueueDepth = 0,
  });

  final LiveVoiceVisualState visualState;
  final int seconds;
  final int playbackQueueDepth;

  @override
  Widget build(BuildContext context) {
    final statusLabel = LiveVoiceSessionPresentation.statusLabel(visualState);
    final helperText = LiveVoiceSessionPresentation.helperText(visualState);
    final timer = LiveVoiceSessionPresentation.formatTimer(seconds);
    final showWaveform =
        visualState == LiveVoiceVisualState.listening ||
        visualState == LiveVoiceVisualState.speaking ||
        visualState == LiveVoiceVisualState.connecting ||
        visualState == LiveVoiceVisualState.reconnecting;

    final icon = switch (visualState) {
      LiveVoiceVisualState.speaking => Icons.volume_up_rounded,
      LiveVoiceVisualState.saving => Icons.cloud_upload_outlined,
      LiveVoiceVisualState.error => Icons.error_outline,
      LiveVoiceVisualState.reconnecting => Icons.sync,
      _ => Icons.mic,
    };

    final accent = switch (visualState) {
      LiveVoiceVisualState.error => VoiceMemoryColors.textSecondary,
      LiveVoiceVisualState.speaking => VoiceMemoryColors.captureSuccess,
      _ => VoiceMemoryColors.primaryIndigo,
    };

    return Semantics(
      label: '$statusLabel, $timer',
      child: Container(
        key: const Key('live_voice_status_card'),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.16),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (visualState == LiveVoiceVisualState.connecting ||
                visualState == LiveVoiceVisualState.reconnecting ||
                visualState == LiveVoiceVisualState.saving)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: accent,
                  ),
                ),
              )
            else
              Icon(icon, size: 44, color: accent),
            if (showWaveform) ...[
              const SizedBox(height: 14),
              if (visualState == LiveVoiceVisualState.speaking)
                LiveVoiceSpeakingWaveform(queueDepth: playbackQueueDepth)
              else
                const IndigoCaptureWaveform(),
            ],
            const SizedBox(height: 12),
            Text(
              statusLabel,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              timer,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              helperText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: VoiceMemoryColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}