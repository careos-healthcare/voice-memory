import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/voicememory_colors.dart';

/// A lightweight, 60fps microphone visualizer driven by decibel samples.
///
/// Samples may arrive at a much lower rate than the display refresh rate. The
/// painter interpolates between them on a vsync ticker, keeping stream work and
/// layout out of the frame loop.
class AudioVisualizer extends StatefulWidget {
  const AudioVisualizer({
    super.key,
    required this.decibels,
    this.height = 48,
    this.barCount = 24,
    this.color = VoiceMemoryColors.primaryIndigo,
  });

  final Stream<double> decibels;
  final double height;
  final int barCount;
  final Color color;

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  StreamSubscription<double>? _levelSubscription;
  double _displayLevel = 0.06;
  double _targetLevel = 0.06;

  @override
  void initState() {
    super.initState();
    _ticker =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_interpolateLevel)
          ..repeat();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.decibels, widget.decibels)) {
      _subscribe();
    }
  }

  void _subscribe() {
    unawaited(_levelSubscription?.cancel());
    _levelSubscription = widget.decibels.listen((decibels) {
      if (!decibels.isFinite) return;
      final normalized = ((decibels.clamp(-60.0, 0.0) + 60.0) / 60.0);
      _targetLevel = math.sqrt(normalized).clamp(0.06, 1.0);
    });
  }

  void _interpolateLevel() {
    _displayLevel += (_targetLevel - _displayLevel) * 0.18;
  }

  @override
  void dispose() {
    unawaited(_levelSubscription?.cancel());
    _ticker
      ..removeListener(_interpolateLevel)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Live microphone level',
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: CustomPaint(
            painter: _AudioVisualizerPainter(
              level: () => _displayLevel,
              phase: () => _ticker.value,
              barCount: widget.barCount,
              color: widget.color,
              repaint: _ticker,
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioVisualizerPainter extends CustomPainter {
  _AudioVisualizerPainter({
    required this.level,
    required this.phase,
    required this.barCount,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final double Function() level;
  final double Function() phase;
  final int barCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.isEmpty) return;

    final gap = math.min(4.0, size.width / (barCount * 3));
    final barWidth = math.max(
      2.0,
      (size.width - gap * (barCount - 1)) / barCount,
    );
    final center = (barCount - 1) / 2;
    final currentLevel = level();
    final currentPhase = phase() * math.pi * 2;
    final paint = Paint()..color = color;

    for (var index = 0; index < barCount; index++) {
      final distance = center == 0 ? 0.0 : (index - center).abs() / center;
      final envelope = 0.45 + (1 - distance) * 0.55;
      final ripple = 0.72 + math.sin(currentPhase + index * 0.62).abs() * 0.28;
      final barHeight = math.max(
        4.0,
        size.height * currentLevel * envelope * ripple,
      );
      final left = index * (barWidth + gap);
      final top = (size.height - barHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AudioVisualizerPainter oldDelegate) =>
      oldDelegate.barCount != barCount || oldDelegate.color != color;
}
