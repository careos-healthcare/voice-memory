import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'horizon_models.dart';

class HorizonCanvasLayer extends StatelessWidget {
  const HorizonCanvasLayer({
    super.key,
    required this.branches,
    required this.year,
    this.pivotByBranchId = const {},
  });

  final List<TimelineBranch> branches;
  final double year;
  final Map<String, Offset> pivotByBranchId;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const Key('horizon-canvas-layer'),
        painter: _HorizonPainter(
          branches: branches,
          year: year,
          pivotByBranchId: pivotByBranchId,
          colors: const [
            Color(0xFFFFB74D),
            Color(0xFFB388FF),
            Color(0xFF4DD0E1),
            Color(0xFFF06292),
          ],
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

final class _HorizonPainter extends CustomPainter {
  const _HorizonPainter({
    required this.branches,
    required this.year,
    required this.colors,
    required this.pivotByBranchId,
  });

  final List<TimelineBranch> branches;
  final double year;
  final List<Color> colors;
  final Map<String, Offset> pivotByBranchId;

  @override
  void paint(Canvas canvas, Size size) {
    if (branches.isEmpty || size.isEmpty) return;
    for (var branchIndex = 0; branchIndex < branches.length; branchIndex++) {
      final branch = branches[branchIndex];
      final pivot =
          pivotByBranchId[branch.id] ?? Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(
        pivot,
        8,
        Paint()..color = const Color(0xFF4DD0E1).withValues(alpha: .9),
      );
      final color = colors[branchIndex % colors.length];
      final projections =
          branch.projections
              .where(
                (projection) => _projectionYear(projection.horizon) <= year,
              )
              .toList()
            ..sort(
              (left, right) => _projectionYear(
                left.horizon,
              ).compareTo(_projectionYear(right.horizon)),
            );
      var previous = pivot;
      for (var index = 0; index < projections.length; index++) {
        final projection = projections[index];
        final distance = math
            .min(size.shortestSide * .42, 72 + index * 68)
            .toDouble();
        final angle =
            -math.pi / 2 +
            (branchIndex - (branches.length - 1) / 2) * .65 +
            index * .09;
        final point =
            pivot + Offset(math.cos(angle), math.sin(angle)) * distance;
        _particleLink(canvas, previous, point, color);
        canvas.drawCircle(
          point,
          5 + projection.probability * 7,
          Paint()..color = color.withValues(alpha: .32),
        );
        canvas.drawCircle(
          point,
          3.5,
          Paint()..color = color.withValues(alpha: .95),
        );
        previous = point;
      }
    }
  }

  static void _particleLink(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
  ) {
    final vector = end - start;
    final length = vector.distance;
    if (length == 0) return;
    final direction = vector / length;
    final paint = Paint()..color = color.withValues(alpha: .52);
    for (var distance = 0.0; distance < length; distance += 9) {
      final point = start + direction * distance;
      canvas.drawCircle(point, 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HorizonPainter oldDelegate) =>
      oldDelegate.year != year ||
      oldDelegate.pivotByBranchId != pivotByBranchId ||
      oldDelegate.branches.map((item) => item.updatedAt).join() !=
          branches.map((item) => item.updatedAt).join();
}

int _projectionYear(HorizonProjection value) => switch (value) {
  HorizonProjection.oneYear => 1,
  HorizonProjection.threeYears => 3,
  HorizonProjection.fiveYears => 5,
};
