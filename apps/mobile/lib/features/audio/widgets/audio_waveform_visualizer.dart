import 'package:archiveme_mobile/features/audio/waveform_picture.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Normalized amplitude bars, tone colors, and touchable pause handles.
class AudioWaveformVisualizer extends StatelessWidget {
  const AudioWaveformVisualizer({
    required this.picture,
    required this.progress,
    super.key,
    this.onScrub,
    this.onHandleScrub,
  });

  final WaveformPicture picture;
  final double progress;
  final ValueChanged<double>? onScrub;
  final ValueChanged<double>? onHandleScrub;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width;
        if (constraints.maxWidth.isFinite) {
          width = constraints.maxWidth;
        } else {
          width = 320;
        }
        final size = Size(width, 96);
        return GestureDetector(
          key: const Key('audio_waveform_visualizer'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _touch(details.localPosition, size, dragged: false),
          onHorizontalDragUpdate: (details) =>
              _touch(details.localPosition, size, dragged: true),
          child: CustomPaint(
            painter: AudioWaveformVisualizerPainter(
              picture: picture,
              progress: progress,
            ),
            child: SizedBox(height: size.height, width: size.width),
          ),
        );
      },
    );
  }

  void _touch(Offset local, Size size, {required bool dragged}) {
    final geometry = WaveformGeometry(
      size: size,
      barCount: picture.amplitudes.length,
    );
    if (!dragged) {
      final handle = geometry.handleAt(local, picture.silences);
      if (handle != null) {
        onHandleScrub?.call(picture.silences[handle].start);
        return;
      }
    }
    onScrub?.call(geometry.fractionAt(local.dx));
  }
}

/// Paints one bar per amplitude sample.
class AudioWaveformVisualizerPainter extends CustomPainter {
  const AudioWaveformVisualizerPainter({
    required this.picture,
    required this.progress,
  });

  final WaveformPicture picture;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final amplitudes = picture.amplitudes;
    if (amplitudes.isEmpty || size.isEmpty) return;
    final geometry = WaveformGeometry(size: size, barCount: amplitudes.length);
    for (var index = 0; index < amplitudes.length; index++) {
      final fraction = (index + 0.5) / amplitudes.length;
      final silent = picture.silences.any((gap) => gap.contains(fraction));
      final tone = toneAt(fraction, picture.tones);
      final rect = geometry.barRect(
        index,
        amplitudes[index],
        silent: silent,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = waveformBarColor(tone, silent: silent),
      );
    }
    for (final silence in picture.silences) {
      final center = geometry.handleCenter(silence);
      canvas
        ..drawCircle(
          center,
          6,
          Paint()..color = AppTokens.neutral50,
        )
        ..drawCircle(
          center,
          6,
          Paint()
            ..color = AppTokens.primary800
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
    final playhead = progress.clamp(0, 1).toDouble() * size.width;
    canvas.drawLine(
      Offset(playhead, 0),
      Offset(playhead, size.height),
      Paint()
        ..color = AppTokens.neutral900
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant AudioWaveformVisualizerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        !identical(oldDelegate.picture, picture);
  }
}
