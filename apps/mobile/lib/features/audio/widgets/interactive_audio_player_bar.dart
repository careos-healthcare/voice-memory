import 'dart:async';

import 'package:archiveme_mobile/audio/silence_trim.dart';
import 'package:archiveme_mobile/features/audio/pitch_preserving_playback.dart';
import 'package:archiveme_mobile/features/audio/waveform_picture.dart';
import 'package:archiveme_mobile/features/audio/widgets/audio_waveform_visualizer.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Scrub, speed, and skip-silence controls for one recording.
class InteractiveAudioPlayerBar extends StatefulWidget {
  const InteractiveAudioPlayerBar({
    required this.picture,
    required this.position,
    required this.speed,
    required this.skipSilence,
    required this.onSeek,
    required this.onSpeed,
    required this.onSkipSilence,
    super.key,
    this.transport,
  });

  final WaveformPicture picture;

  /// Current playhead as a fraction of the recording, from 0 to 1.
  final double position;
  final double speed;
  final bool skipSilence;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSpeed;
  final ValueChanged<bool> onSkipSilence;
  final PitchPreservingTransport? transport;

  @override
  State<InteractiveAudioPlayerBar> createState() =>
      _InteractiveAudioPlayerBarState();
}

class _InteractiveAudioPlayerBarState extends State<InteractiveAudioPlayerBar> {
  @override
  void initState() {
    super.initState();
    _scheduleSilenceJump(widget.position);
  }

  @override
  void didUpdateWidget(InteractiveAudioPlayerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position ||
        oldWidget.skipSilence != widget.skipSilence) {
      _scheduleSilenceJump(widget.position);
    }
  }

  void _scheduleSilenceJump(double position) {
    final target = skipSilenceTarget(
      position: position,
      silences: widget.picture.silences,
      enabled: widget.skipSilence,
    );
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.position != position) return;
      widget.onSeek(target);
      final transport = widget.transport;
      if (transport != null) unawaited(transport.seekTo(target));
    });
  }

  void _selectSpeed(double speed) {
    widget.onSpeed(speed);
    final transport = widget.transport;
    if (transport != null) unawaited(transport.setSpeed(speed));
  }

  void _seek(double fraction) {
    widget.onSeek(fraction);
    final transport = widget.transport;
    if (transport != null) unawaited(transport.seekTo(fraction));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AudioWaveformVisualizer(
          picture: widget.picture,
          progress: widget.position,
          onScrub: _seek,
          onHandleScrub: _seek,
        ),
        const SizedBox(height: AppTokens.spacing2),
        Wrap(
          spacing: AppTokens.spacing2,
          children: [
            for (final speed in PlaybackReviewSpeeds.speeds)
              ChoiceChip(
                key: Key(
                  'audio_speed_${speed.toString().replaceAll('.', '_')}',
                ),
                label: Text(PlaybackReviewSpeeds.label(speed)),
                selected: widget.speed == speed,
                onSelected: (_) => _selectSpeed(speed),
              ),
          ],
        ),
        SwitchListTile(
          key: const Key('audio_skip_silence'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Trim silence'),
          value: widget.skipSilence,
          onChanged: widget.onSkipSilence,
        ),
      ],
    );
  }
}
