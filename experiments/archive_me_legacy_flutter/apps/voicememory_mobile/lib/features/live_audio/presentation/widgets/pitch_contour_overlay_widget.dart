import 'package:flutter/material.dart';

class PitchContourOverlayWidget extends StatelessWidget {
  const PitchContourOverlayWidget({
    super.key,
    required this.pitchContour,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
  });

  final List<double> pitchContour;
  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<Duration> onSeek;

  void _handleGesture(Offset localPosition, Size size) {
    if (totalDuration == Duration.zero || size.width == 0) return;
    final fraction = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final seekMs = (totalDuration.inMilliseconds * fraction).round();
    onSeek(Duration(milliseconds: seekMs));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressFraction = totalDuration.inMilliseconds > 0
        ? (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          key: const Key('pitch_contour_overlay'),
          onTapDown: (details) => _handleGesture(details.localPosition, size),
          onPanUpdate: (details) => _handleGesture(details.localPosition, size),
          child: Container(
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              painter: _PitchContourPainter(
                pitchContour: pitchContour,
                progressFraction: progressFraction,
                lineColor: theme.colorScheme.primary,
                playedColor: theme.colorScheme.tertiary,
                cursorColor: theme.colorScheme.error,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _PitchContourPainter extends CustomPainter {
  _PitchContourPainter({
    required this.pitchContour,
    required this.progressFraction,
    required this.lineColor,
    required this.playedColor,
    required this.cursorColor,
  });

  final List<double> pitchContour;
  final double progressFraction;
  final Color lineColor;
  final Color playedColor;
  final Color cursorColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchContour.isEmpty || size.width <= 0 || size.height <= 0) return;

    final minHz = pitchContour.reduce((a, b) => a < b ? a : b);
    final maxHz = pitchContour.reduce((a, b) => a > b ? a : b);
    final hzRange = (maxHz - minHz) == 0 ? 1.0 : (maxHz - minHz);

    final basePaint = Paint()
      ..color = lineColor.withAlpha(100)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final playedPaint = Paint()
      ..color = playedColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final basePath = Path();
    final playedPath = Path();

    final sampleCount = pitchContour.length;
    final dx = sampleCount <= 1 ? 0.0 : size.width / (sampleCount - 1);
    final cursorX = size.width * progressFraction;
    var playedStarted = false;

    for (var i = 0; i < sampleCount; i++) {
      final x = sampleCount <= 1 ? size.width / 2 : i * dx;
      final normalizedY = (pitchContour[i] - minHz) / hzRange;
      final y = size.height - (normalizedY * (size.height - 16) + 8);

      if (i == 0) {
        basePath.moveTo(x, y);
      } else {
        basePath.lineTo(x, y);
      }

      if (x <= cursorX) {
        if (!playedStarted) {
          playedPath.moveTo(x, y);
          playedStarted = true;
        } else {
          playedPath.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(basePath, basePaint);
    canvas.drawPath(playedPath, playedPaint);

    final cursorPaint = Paint()
      ..color = cursorColor
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(cursorX, 0),
      Offset(cursorX, size.height),
      cursorPaint,
    );

    canvas.drawCircle(Offset(cursorX, size.height / 2), 6, cursorPaint);
  }

  @override
  bool shouldRepaint(covariant _PitchContourPainter oldDelegate) {
    return oldDelegate.progressFraction != progressFraction ||
        oldDelegate.pitchContour.length != pitchContour.length ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.cursorColor != cursorColor;
  }
}
