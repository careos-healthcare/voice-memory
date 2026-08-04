import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The amount of GPU work and transparency used to render a glass surface.
enum GlassRenderQuality { full, reduced, off }

/// Process-local cap controlled by the Apex frame budget tracker.
final class GlassQualityGovernor {
  GlassQualityGovernor._();

  static GlassRenderQuality maximum = GlassRenderQuality.full;

  static GlassRenderQuality cap(GlassRenderQuality requested) =>
      requested.index >= maximum.index ? requested : maximum;
}

/// Resolves the effective glass quality for the current accessibility context.
///
/// Implementations are injectable so callers and tests can supply device
/// capability policy without coupling this reusable widget to app state.
abstract interface class GlassRenderPolicy {
  const GlassRenderPolicy();

  GlassRenderQuality resolve(
    MediaQueryData mediaQuery,
    GlassRenderQuality requestedQuality,
  );
}

/// Keeps requested effects unless accessibility or device capability asks for
/// a less expensive, more legible presentation.
final class AccessibilityAwareGlassRenderPolicy implements GlassRenderPolicy {
  const AccessibilityAwareGlassRenderPolicy({this.isLowCapability = false});

  final bool isLowCapability;

  @override
  GlassRenderQuality resolve(
    MediaQueryData mediaQuery,
    GlassRenderQuality requestedQuality,
  ) {
    if (requestedQuality == GlassRenderQuality.off || mediaQuery.highContrast) {
      return GlassRenderQuality.off;
    }
    if (requestedQuality == GlassRenderQuality.reduced ||
        isLowCapability ||
        mediaQuery.disableAnimations ||
        mediaQuery.accessibleNavigation) {
      return GlassRenderQuality.reduced;
    }
    return GlassRenderQuality.full;
  }
}

/// A deterministic policy useful for previews and focused widget tests.
final class FixedGlassRenderPolicy implements GlassRenderPolicy {
  const FixedGlassRenderPolicy(this.quality);

  final GlassRenderQuality quality;

  @override
  GlassRenderQuality resolve(
    MediaQueryData mediaQuery,
    GlassRenderQuality requestedQuality,
  ) => quality;
}

/// A clipped, performance-aware glass surface with a refraction edge.
class GlassmorphicContainer extends StatelessWidget {
  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(20)),
    this.padding = const EdgeInsets.all(16),
    this.fillColor = const Color(0xff171a24),
    this.blurSigma = 18,
    this.opacity = .72,
    this.refractionColors = const [
      Color(0xb3ffffff),
      Color(0x4d8ea7ff),
      Color(0x1affffff),
    ],
    this.renderQuality = GlassRenderQuality.full,
    this.renderPolicy = const AccessibilityAwareGlassRenderPolicy(),
  }) : assert(blurSigma >= 0),
       assert(opacity >= 0 && opacity <= 1);

  final Widget child;
  final BorderRadiusGeometry radius;
  final EdgeInsetsGeometry padding;
  final Color fillColor;
  final double blurSigma;
  final double opacity;
  final List<Color> refractionColors;
  final GlassRenderQuality renderQuality;
  final GlassRenderPolicy renderPolicy;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    final quality = GlassQualityGovernor.cap(
      renderPolicy.resolve(mediaQuery, renderQuality),
    );
    final resolvedRadius = radius.resolve(Directionality.of(context));
    final effectiveOpacity = switch (quality) {
      GlassRenderQuality.full => opacity,
      GlassRenderQuality.reduced => opacity.clamp(.82, 1).toDouble(),
      GlassRenderQuality.off => 1.0,
    };

    final borderColor = refractionColors.isEmpty
        ? Colors.transparent
        : refractionColors.first.withValues(alpha: .45);
    final content = CustomPaint(
      foregroundPainter: quality == GlassRenderQuality.off
          ? null
          : GlassRefractionBorderPainter(
              radius: resolvedRadius,
              colors: refractionColors,
            ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fillColor.withValues(alpha: effectiveOpacity),
          borderRadius: resolvedRadius,
          border: quality == GlassRenderQuality.off
              ? Border.all(color: borderColor)
              : null,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: quality == GlassRenderQuality.full && blurSigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: content,
              )
            : content,
      ),
    );
  }
}

/// Paints a single inset gradient stroke; no shadows or additional saveLayer.
@immutable
final class GlassRefractionBorderPainter extends CustomPainter {
  const GlassRefractionBorderPainter({
    required this.radius,
    required this.colors,
    this.strokeWidth = 1,
  });

  final BorderRadius radius;
  final List<Color> colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || colors.isEmpty || strokeWidth <= 0) return;
    final inset = strokeWidth / 2;
    final rect = (Offset.zero & size).deflate(inset);
    final path = Path()..addRRect(radius.toRRect(rect));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant GlassRefractionBorderPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      !listEquals(oldDelegate.colors, colors);
}
