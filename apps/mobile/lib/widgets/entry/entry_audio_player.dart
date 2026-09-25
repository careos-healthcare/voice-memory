import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/audio/playback_service.dart';
import 'package:archiveme_mobile/features/capture_flow/recording_feedback.dart';
import 'package:archiveme_mobile/features/entry_detail/entry_detail_copy.dart';
import 'package:archiveme_mobile/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Plays the recording stored with a journal entry.
class EntryAudioPlayer extends StatefulWidget {
  const EntryAudioPlayer({
    required this.audioPath,
    required this.durationSeconds,
    this.playback,
    this.compact = false,
    super.key,
  });

  final String? audioPath;
  final int durationSeconds;
  final PlaybackService? playback;

  /// Play control only, for a voice card. Hides the missing-file message.
  final bool compact;

  static const speeds = [1.0, 1.5, 2.0];

  @override
  State<EntryAudioPlayer> createState() => _EntryAudioPlayerState();
}

class _EntryAudioPlayerState extends State<EntryAudioPlayer> {
  PlaybackService? _playback;
  List<double> _levels = const [];
  var _playing = false;
  var _speedIndex = 0;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool get _fileReady {
    final path = widget.audioPath?.trim() ?? '';
    if (path.isEmpty) return false;
    return File(path).existsSync();
  }

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.durationSeconds);
    unawaited(_loadLevels());
    final playback = widget.playback;
    _playback = playback;
  }

  Future<void> _loadLevels() async {
    final path = widget.audioPath?.trim() ?? '';
    if (path.isEmpty) return;
    final levels = await RecordingAmplitudeSeries.readBeside(File(path));
    if (!mounted || levels.isEmpty) return;
    setState(() => _levels = levels);
  }

  @override
  void dispose() {
    unawaited(_playback?.stop());
    super.dispose();
  }

  Future<void> _toggle() async {
    final path = widget.audioPath?.trim() ?? '';
    final playback = _playback;
    if (_playing) {
      setState(() => _playing = false);
      await playback?.pause();
      return;
    }
    setState(() => _playing = true);
    if (playback == null) return;
    if (playback.state.phase == PlaybackPhase.paused &&
        playback.state.filePath == path) {
      await playback.resume();
    } else {
      await playback.playFile(path);
      await playback.setPlaybackSpeed(EntryAudioPlayer.speeds[_speedIndex]);
    }
  }

  Future<void> _cycleSpeed() async {
    final next = (_speedIndex + 1) % EntryAudioPlayer.speeds.length;
    setState(() => _speedIndex = next);
    await _playback?.setPlaybackSpeed(EntryAudioPlayer.speeds[next]);
  }

  Future<void> _seek(double fraction) async {
    final totalMs = _total.inMilliseconds;
    if (totalMs <= 0) return;
    final position = Duration(milliseconds: (totalMs * fraction).round());
    setState(() => _position = position);
    await _playback?.seek(position);
  }

  @override
  Widget build(BuildContext context) {
    if (!_fileReady) {
      if (widget.compact) return const SizedBox.shrink();
      return Text(
        EntryDetailCopy.audioMissing,
        key: const Key('entry_detail_audio_missing'),
        style: TextStyle(color: context.palette.textMuted, height: 1.45),
      );
    }

    final speed = EntryAudioPlayer.speeds[_speedIndex];
    final speedLabel = speed == speed.roundToDouble()
        ? '${speed.toStringAsFixed(0)}×'
        : '${speed.toStringAsFixed(1)}×';
    final fraction = _total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);

    final playButton = Semantics(
      button: true,
      label: _playing ? 'Pause recording' : 'Play recording',
      child: IconButton(
        key: const Key('entry_detail_play'),
        onPressed: _toggle,
        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
      ),
    );
    if (widget.compact) {
      return KeyedSubtree(
        key: const Key('entry_detail_audio_player'),
        child: playButton,
      );
    }

    return Column(
      key: const Key('entry_detail_audio_player'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            playButton,
            Expanded(
              child: _levels.isEmpty
                  ? Semantics(
                      label: 'Playback progress',
                      child: Slider(
                        key: const Key('entry_detail_progress'),
                        value: fraction,
                        onChanged: _seek,
                      ),
                    )
                  : Semantics(
                      label: 'Playback waveform',
                      child: LayoutBuilder(
                        key: const Key('entry_detail_waveform'),
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) {
                              final width = constraints.maxWidth;
                              if (width <= 0) return;
                              unawaited(
                                _seek(details.localPosition.dx / width),
                              );
                            },
                            child: CustomPaint(
                              size: Size(constraints.maxWidth, 36),
                              painter: _WaveformPainter(
                                levels: _levels,
                                progress: fraction,
                                color: context.palette.accentPrimary,
                                dim: context.palette.borderSubtle,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Semantics(
              button: true,
              label: 'Playback speed $speedLabel',
              child: TextButton(
                key: const Key('entry_detail_speed'),
                onPressed: _cycleSpeed,
                child: Text(speedLabel),
              ),
            ),
          ],
        ),
        Text(
          '${_clock(_position)} / ${_clock(_total)}',
          key: const Key('entry_detail_playback_time'),
          style: TextStyle(color: context.palette.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.levels,
    required this.progress,
    required this.color,
    required this.dim,
  });

  final List<double> levels;
  final double progress;
  final Color color;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0) return;
    final played = Paint()..color = color;
    final rest = Paint()..color = dim;
    final gap = size.width * 0.004;
    final barWidth = (size.width - gap * (levels.length - 1)) / levels.length;
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i].clamp(0.0, 1.0);
      final height = size.height * (0.12 + 0.88 * level);
      final left = i * (barWidth + gap);
      final fraction = levels.length == 1 ? 1.0 : i / (levels.length - 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          const Radius.circular(1),
        ),
        fraction <= progress ? played : rest,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.levels != levels;
}
