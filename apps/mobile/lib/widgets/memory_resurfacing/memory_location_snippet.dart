import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_models.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Static place sketch. It does not load map tiles or take gestures.
class MemoryLocationSnippet extends StatelessWidget {
  const MemoryLocationSnippet({required this.place, super.key});

  final MemoryPlace place;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).textTheme.bodySmall?.color ?? ink;
    return IgnorePointer(
      child: Column(
        key: const Key('memory_location_map'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 96,
            width: double.infinity,
            child: CustomPaint(
              painter: _StaticMapPainter(place: place, color: ink),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            place.label,
            style: TextStyle(fontSize: 12, color: muted.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _StaticMapPainter extends CustomPainter {
  const _StaticMapPainter({required this.place, required this.color});

  final MemoryPlace place;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Paint()..color = color.withValues(alpha: 0.05);
    canvas.drawRect(Offset.zero & size, ground);
    final line = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (var row = 1; row < 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (var column = 1; column < 5; column++) {
      final x = size.width * column / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    final x = ((place.longitude + 180) / 360).clamp(0.08, 0.92) * size.width;
    final y = ((90 - place.latitude) / 180).clamp(0.12, 0.88) * size.height;
    final pin = Paint()..color = color.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(x, y), 4, pin);
  }

  @override
  bool shouldRepaint(covariant _StaticMapPainter oldDelegate) {
    return oldDelegate.place.latitude != place.latitude ||
        oldDelegate.place.longitude != place.longitude ||
        oldDelegate.color != color;
  }
}
