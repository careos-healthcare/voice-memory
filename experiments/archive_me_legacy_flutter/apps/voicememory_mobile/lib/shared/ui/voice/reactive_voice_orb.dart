import 'dart:math' as math;

import 'package:flutter/material.dart';

class ReactiveVoiceOrb extends StatefulWidget {
  const ReactiveVoiceOrb({
    super.key,
    required this.level,
    required this.color,
    required this.animate,
  });

  final double level;
  final Color color;
  final bool animate;

  @override
  State<ReactiveVoiceOrb> createState() => _ReactiveVoiceOrbState();
}

class _ReactiveVoiceOrbState extends State<ReactiveVoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: 210,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _VoiceOrbPainter(
              level: widget.level.clamp(0, 1),
              phase: widget.animate ? _controller.value : 0,
              color: widget.color,
            ),
          ),
        ),
      ),
    ),
  );
}

class _VoiceOrbPainter extends CustomPainter {
  const _VoiceOrbPainter({
    required this.level,
    required this.phase,
    required this.color,
  });

  final double level;
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final pulse = (math.sin(phase * math.pi * 2) + 1) / 2;
    final radius = size.shortestSide * (.27 + level * .07);
    canvas.drawCircle(
      center,
      radius + 24 + pulse * 8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .3 + level * .18),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 40)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.25, -.3),
          colors: [
            Colors.white.withValues(alpha: .9),
            color.withValues(alpha: .95),
            Color.lerp(color, Colors.black, .25)!,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var index = 0; index < 3; index++) {
      final wave = radius + 8 + index * 9 + level * 12;
      canvas.drawCircle(
        center,
        wave,
        Paint()
          ..color = color.withValues(alpha: .28 / (index + 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceOrbPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.phase != phase ||
      oldDelegate.color != color;
}
