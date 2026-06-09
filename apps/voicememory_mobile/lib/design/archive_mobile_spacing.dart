import 'package:flutter/material.dart';

import 'archive_responsive_layout.dart';
import '../theme/app_spacing.dart';

/// Archive Experience spacing — aligned with [AppSpacing].
class ArchiveMobileSpacing {
  ArchiveMobileSpacing._();

  static const double xs = AppSpacing.xs;
  static const double sm = AppSpacing.sm;
  static const double md = AppSpacing.md;
  static const double lg = AppSpacing.lg;
  static const double xl = AppSpacing.xl;

  /// Default mobile page padding — prefer [pagePaddingFor] on wide layouts.
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 12, 20, 24);

  static EdgeInsets pagePaddingFor(BuildContext context) =>
      ArchiveResponsiveLayout.pagePadding(context);
}
