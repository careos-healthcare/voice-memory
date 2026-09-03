import 'package:flutter/material.dart';

/// Shared max widths and page padding for ArchiveMe high-visibility screens.
abstract class ArchiveResponsiveLayout {
  ArchiveResponsiveLayout._();

  static const double contentMaxWidth = 720;
  static const double cardMaxWidth = 680;
  static const double sectionGap = 12;
  static const double sectionGapWide = 14;
  static const double cardPadding = 16;
  static const double cardPaddingWide = 18;

  static bool isTabletOrDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  static int entryGridColumnsForWidth(double width) {
    if (width >= 1100) return 3;
    if (width >= 720) return 2;
    return 1;
  }

  static int entryGridColumns(BuildContext context) =>
      entryGridColumnsForWidth(MediaQuery.sizeOf(context).width);

  /// Tablet/desktop grids ignore text scale. Above this factor, Archive Home
  /// uses the phone [SliverList] path instead of a fixed-aspect [SliverGrid].
  static const double largeTextListFallbackThreshold = 1.3;

  /// Phone (one column) already lists. Large text on a wide viewport would
  /// clip [ArchiveEntryCard] inside `childAspectRatio` cells.
  static bool prefersEntryList({
    required int crossAxisCount,
    required TextScaler textScaler,
  }) {
    if (crossAxisCount <= 1) return true;
    return textScaler.scale(1) >= largeTextListFallbackThreshold;
  }

  static double horizontalCenterInset({
    required double viewportWidth,
    double maxWidth = contentMaxWidth,
  }) {
    if (viewportWidth <= maxWidth) return 0;
    return (viewportWidth - maxWidth) / 2;
  }

  static EdgeInsets dashboardSliverPadding({
    required BuildContext context,
    required double viewportWidth,
  }) {
    final base = pagePadding(context);
    final centerInset = horizontalCenterInset(viewportWidth: viewportWidth);
    return EdgeInsets.fromLTRB(
      base.left + centerInset,
      base.top,
      base.right + centerInset,
      base.bottom,
    );
  }

  static SliverGridDelegate entryGridDelegate({
    required BuildContext context,
    required int crossAxisCount,
  }) {
    final spacing = gap(context);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: crossAxisCount == 1 ? 1.35 : 0.95,
    );
  }

  static double gap(BuildContext context) =>
      isTabletOrDesktop(context) ? sectionGapWide : sectionGap;

  static EdgeInsets pagePadding(BuildContext context) {
    final wide = isTabletOrDesktop(context);
    return EdgeInsets.fromLTRB(
      wide ? 32 : 20,
      wide ? 12 : 8,
      wide ? 32 : 20,
      wide ? 24 : 16,
    );
  }

  static EdgeInsets cardInsets(BuildContext context) {
    final pad = isTabletOrDesktop(context) ? cardPaddingWide : cardPadding;
    return EdgeInsets.all(pad);
  }

  static Widget constrainContent({
    required BuildContext context,
    required Widget child,
    double maxWidth = contentMaxWidth,
    Alignment alignment = Alignment.topCenter,
  }) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  static Widget page({
    required BuildContext context,
    required Widget child,
    double maxWidth = contentMaxWidth,
    EdgeInsets? padding,
  }) {
    return Padding(
      padding: padding ?? pagePadding(context),
      child: constrainContent(
        context: context,
        maxWidth: maxWidth,
        child: child,
      ),
    );
  }
}