import 'dart:async';

import 'package:flutter/material.dart';

import '../features/audio_digest_speaker.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AudioDigestPlaybackState { idle, loading, playing, error }

class AudioDigestPlayerWidget extends StatefulWidget {
  const AudioDigestPlayerWidget({
    super.key,
    required this.narrative,
    this.title = 'Weekly Audio Retrospective',
    this.speaker,
  });

  final String title;
  final String narrative;
  final AudioDigestSpeaker? speaker;

  @override
  State<AudioDigestPlayerWidget> createState() =>
      _AudioDigestPlayerWidgetState();
}

class _AudioDigestPlayerWidgetState extends State<AudioDigestPlayerWidget> {
  late final AudioDigestSpeaker _speaker;
  late final bool _ownsSpeaker;
  AudioDigestPlaybackState _playbackState = AudioDigestPlaybackState.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ownsSpeaker = widget.speaker == null;
    _speaker = widget.speaker ?? FlutterTtsAudioDigestSpeaker();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _speaker.initialize(
        onStarted: () => _setPlaybackState(AudioDigestPlaybackState.playing),
        onCompleted: () => _setPlaybackState(AudioDigestPlaybackState.idle),
        onError: (message) {
          if (!mounted) return;
          setState(() {
            _playbackState = AudioDigestPlaybackState.error;
            _errorMessage = message;
          });
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _playbackState = AudioDigestPlaybackState.error;
        _errorMessage = error.toString();
      });
    }
  }

  void _setPlaybackState(AudioDigestPlaybackState state) {
    if (!mounted) return;
    setState(() {
      _playbackState = state;
      if (state != AudioDigestPlaybackState.error) _errorMessage = null;
    });
  }

  Future<void> _togglePlayback() async {
    if (_playbackState == AudioDigestPlaybackState.loading) return;
    if (_playbackState == AudioDigestPlaybackState.playing) {
      await _speaker.stop();
      _setPlaybackState(AudioDigestPlaybackState.idle);
      return;
    }

    _setPlaybackState(AudioDigestPlaybackState.loading);
    try {
      await _speaker.speak(widget.narrative);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _playbackState = AudioDigestPlaybackState.error;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  void dispose() {
    if (_ownsSpeaker) unawaited(_speaker.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _playbackState == AudioDigestPlaybackState.playing;
    final loading = _playbackState == AudioDigestPlaybackState.loading;
    final actionLabel = playing ? 'Stop audio digest' : 'Play audio digest';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.title,
      child: Card(
        color: AppColors.backgroundSecondary,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.graphic_eq,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Listen to a private, evidence-based summary of your archive.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (loading) ...[
                const SizedBox(height: AppSpacing.sm),
                const LinearProgressIndicator(),
              ],
              if (_playbackState == AudioDigestPlaybackState.error) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Audio playback is unavailable right now.'
                  '${_errorMessage == null ? '' : ' Try again.'}',
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Semantics(
                button: true,
                label: actionLabel,
                child: ExcludeSemantics(
                  child: FilledButton.icon(
                    key: const Key('audio_digest_play_button'),
                    onPressed: loading
                        ? null
                        : () => unawaited(_togglePlayback()),
                    icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                    label: Text(playing ? 'Stop' : 'Play retrospective'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
