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
