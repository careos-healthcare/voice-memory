import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Dense-data typography whose base sizes respond gently to viewport width.
///
/// Font sizes here are unscaled design bases. Flutter's ambient [TextScaler]
/// remains authoritative for Text widgets, and is exposed for custom painters.
@immutable
final class MemoryTypography {
  const MemoryTypography._({
    required this.viewportWidth,
    required this.textScaler,
    required this.display,
    required this.pageTitle,
    required this.sectionTitle,
    required this.cardTitle,
    required this.body,
    required this.denseBody,
    required this.label,
    required this.caption,
    required this.graphLabelMetrics,
  });

  static const double compactViewport = 320;
  static const double expandedViewport = 1024;
  static const double readableLineWidth = 680;
  static const double denseReadableLineWidth = 520;

  final double viewportWidth;

  /// Pass this unchanged to TextPainter for labels drawn outside Text widgets.
  final TextScaler textScaler;

  final TextStyle display;
  final TextStyle pageTitle;
  final TextStyle sectionTitle;
  final TextStyle cardTitle;
  final TextStyle body;
  final TextStyle denseBody;
  final TextStyle label;
  final TextStyle caption;
  final MemoryGraphLabelMetrics graphLabelMetrics;

  factory MemoryTypography.of(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MemoryTypography.forViewport(
      mediaQuery.size.width,
      textScaler: mediaQuery.textScaler,
    );
  }

  @visibleForTesting
  factory MemoryTypography.forViewport(
    double viewportWidth, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    double size(double compact, double expanded) =>
        fluidBase(viewportWidth, compact: compact, expanded: expanded);

    final graphBase = size(11.5, 13);
    return MemoryTypography._(
      viewportWidth: viewportWidth,
      textScaler: textScaler,
      display: TextStyle(
        fontSize: size(34, 44),
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
      ),
      pageTitle: TextStyle(
        fontSize: size(28, 36),
        height: 1.16,
        fontWeight: FontWeight.w700,
        letterSpacing: -.45,
      ),
      sectionTitle: TextStyle(
        fontSize: size(20, 24),
        height: 1.24,
        fontWeight: FontWeight.w600,
        letterSpacing: -.2,
      ),
      cardTitle: TextStyle(
        fontSize: size(17, 19),
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      body: TextStyle(
        fontSize: size(15.5, 17),
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
      denseBody: TextStyle(
        fontSize: size(14, 15),
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
      label: TextStyle(
        fontSize: size(13, 14),
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: .1,
      ),
      caption: TextStyle(
        fontSize: size(12, 13),
        height: 1.35,
        fontWeight: FontWeight.w400,
      ),
      graphLabelMetrics: MemoryGraphLabelMetrics(
        fontSize: graphBase,
        selectedFontSize: size(13, 15),
        lineHeight: 1.2,
        maxWidth: size(84, 116),
        nodeGap: size(6, 8),
      ),
    );
  }

  /// Linear viewport interpolation with bounds only on the design base.
  ///
  /// Accessibility scaling is deliberately not included or clamped here.
  static double fluidBase(
    double viewportWidth, {
    required double compact,
    required double expanded,
  }) {
    final progress =
        ((viewportWidth - compactViewport) /
                (expandedViewport - compactViewport))
            .clamp(0.0, 1.0);
    return lerpDouble(compact, expanded, progress)!;
  }
}

/// Layout and type inputs shared by graph labels and preview painters.
@immutable
final class MemoryGraphLabelMetrics {
  const MemoryGraphLabelMetrics({
    required this.fontSize,
    required this.selectedFontSize,
    required this.lineHeight,
    required this.maxWidth,
    required this.nodeGap,
  });

  final double fontSize;
  final double selectedFontSize;
  final double lineHeight;
  final double maxWidth;
  final double nodeGap;

  TextStyle style({bool selected = false, Color? color}) => TextStyle(
    fontSize: selected ? selectedFontSize : fontSize,
    height: lineHeight,
    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    color: color,
  );

  /// Resolves the system scale for custom canvas layout without limiting it.
  double scaledFontSize(TextScaler textScaler, {bool selected = false}) =>
      textScaler.scale(selected ? selectedFontSize : fontSize);
}
