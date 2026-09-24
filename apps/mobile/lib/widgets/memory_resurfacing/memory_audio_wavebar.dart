import 'dart:async';
import 'dart:math' as math;

import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Playback surface the wavebar scrubs. Production uses [JustAudioWavebarTransport].
abstract class WavebarTransport {
  Duration get position;
  Duration get duration;
  bool get playing;
  Stream<Duration> get positions;
  Future<void> seek(Duration position);
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
}

/// [just_audio] transport for a local file or a remote voice note.
class JustAudioWavebarTransport implements WavebarTransport {
  JustAudioWavebarTransport(this.path) : _player = AudioPlayer();

  final String path;
  final AudioPlayer _player;
  var _ready = false;

  @override
  Duration get position => _player.position;

  @override
  Duration get duration => _player.duration ?? Duration.zero;

  @override
  bool get playing => _player.playing;

  @override
  Stream<Duration> get positions => _player.positionStream;

  Future<void> _ensureLoaded() async {
    if (_ready) return;
    final remote = path.startsWith('http://') || path.startsWith('https://');
    if (remote) {
      await _player.setUrl(path);
    } else {
      await _player.setFilePath(path);
    }
    _ready = true;
  }

  @override
  Future<void> seek(Duration position) async {
    await _ensureLoaded();
    await _player.seek(position);
  }

  @override
  Future<void> play() async {
    await _ensureLoaded();
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

/// Inline voice-note bar. Drag or tap to scrub. Playback stays inside the card.
class MemoryAudioWavebar extends StatefulWidget {
  const MemoryAudioWavebar({
    required this.audioPath,
    this.transport,
    super.key,
  });

  final String audioPath;
  final WavebarTransport? transport;

  @override
  State<MemoryAudioWavebar> createState() => _MemoryAudioWavebarState();
}

class _MemoryAudioWavebarState extends State<MemoryAudioWavebar> {
  late final WavebarTransport _transport;
  StreamSubscription<Duration>? _positions;
  var _position = Duration.zero;
  var _scrubbing = false;
  var _playing = false;

  @override
  void initState() {
    super.initState();
    _transport =
        widget.transport ?? JustAudioWavebarTransport(widget.audioPath);
    _position = _transport.position;
    _playing = _transport.playing;
    _positions = _transport.positions.listen((position) {
      if (!mounted || _scrubbing) return;
      setState(() => _position = position);
    });
  }

  @override
  void dispose() {
    final pending = _positions?.cancel();
    if (pending != null) unawaited(pending);
    if (widget.transport == null) {
      unawaited(_transport.dispose());
    }
    super.dispose();
  }

  void _seekAt(double dx, double width) {
    final span = _transport.duration;
    if (span <= Duration.zero || width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    final target = Duration(
      microseconds: (span.inMicroseconds * fraction).round(),
    );
    setState(() => _position = target);
    unawaited(_transport.seek(target));
  }

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Row(
      key: const Key('memory_audio_wavebar'),
      children: [
        IconButton(
          key: const Key('memory_audio_play'),
          onPressed: () async {
            if (_playing) {
              await _transport.pause();
            } else {
              await _transport.play();
            }
            if (!mounted) return;
            setState(() => _playing = _transport.playing);
          },
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow, color: ink),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                key: const Key('memory_audio_scrub'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    _seekAt(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragStart: (_) => _scrubbing = true,
                onHorizontalDragUpdate: (details) =>
                    _seekAt(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragEnd: (_) => _scrubbing = false,
                onHorizontalDragCancel: () => _scrubbing = false,
                child: SizedBox(
                  height: AppSpacing.lg,
                  child: CustomPaint(
                    painter: _WavebarPainter(
                      seed: widget.audioPath,
                      progress: _progress,
                      color: ink,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double get _progress {
    final span = _transport.duration.inMicroseconds;
    if (span <= 0) return 0;
    return (_position.inMicroseconds / span).clamp(0.0, 1.0);
  }
}

class _WavebarPainter extends CustomPainter {
  const _WavebarPainter({
    required this.seed,
    required this.progress,
    required this.color,
  });

  final String seed;
  final double progress;
  final Color color;

  static const _bars = 42;

  @override
  void paint(Canvas canvas, Size size) {
    final played = Paint()..color = color.withValues(alpha: 0.9);
    final rest = Paint()..color = color.withValues(alpha: 0.22);
    final gap = 2.0;
    final barWidth = (size.width - gap * (_bars - 1)) / _bars;
    final random = math.Random(seed.hashCode);
    for (var index = 0; index < _bars; index++) {
      final height = size.height * (0.25 + random.nextDouble() * 0.75);
      final left = index * (barWidth + gap);
      final rect = Rect.fromLTWH(
        left,
        (size.height - height) / 2,
        barWidth,
        height,
      );
      final playedThrough = (index + 1) / _bars <= progress;
      canvas.drawRect(rect, playedThrough ? played : rest);
    }
  }

  @override
  bool shouldRepaint(covariant _WavebarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.seed != seed ||
        oldDelegate.color != color;
  }
}
