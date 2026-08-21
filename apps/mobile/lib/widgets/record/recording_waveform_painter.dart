import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws a mirrored bar waveform from precomputed level samples.
class RecordingWaveformPainter extends CustomPainter {
  RecordingWaveformPainter({
    required Listenable repaint,
    required this.levels,
    required this.color,
    this.barWidth = 3,
    this.barGap = 2,
    this.minBarHeight = 4,
    this.maxBarHeight = 28,
  }) : super(repaint: repaint);

  final List<double> levels;
  final Color color;
  final double barWidth;
  final double barGap;
  final double minBarHeight;
  final double maxBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0 || size.height <= 0) return;

    final barStride = barWidth + barGap;
    final visibleBars = math.min(
      levels.length,
      (size.width / barStride).floor().clamp(1, levels.length),
    );
    final startIndex = levels.length - visibleBars;
    final totalWidth = visibleBars * barStride - barGap;
    var x = (size.width - totalWidth) / 2;
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth
      ..isAntiAlias = true;

    for (var i = 0; i < visibleBars; i++) {
      final level = levels[startIndex + i];
      final halfHeight =
          minBarHeight + (maxBarHeight - minBarHeight) * level * 0.5;
      final alpha = 0.35 + (level * 0.55);
      paint.color = color.withValues(alpha: alpha.clamp(0.35, 0.95));
      canvas.drawLine(
        Offset(x + barWidth / 2, centerY - halfHeight),
        Offset(x + barWidth / 2, centerY + halfHeight),
        paint,
      );
      x += barStride;
    }
  }

  @override
  bool shouldRepaint(covariant RecordingWaveformPainter oldDelegate) {
    return oldDelegate.levels != levels ||
        oldDelegate.color != color ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.barGap != barGap ||
        oldDelegate.minBarHeight != minBarHeight ||
        oldDelegate.maxBarHeight != maxBarHeight;
  }
}