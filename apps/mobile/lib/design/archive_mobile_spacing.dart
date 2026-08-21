import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Archive Experience spacing — aligned with [AppSpacing].
class ArchiveMobileSpacing {
  ArchiveMobileSpacing._();

  static const double xs = AppSpacing.xs;
  static const double sm = AppSpacing.sm;
  static const double md = AppSpacing.md;
  static const double lg = AppSpacing.lg;
  static const double xl = AppSpacing.xl;

  /// Vertical gap between primary proof-stack cards on Patterns / Archive.
  static const double proofStackCardGap = md;

  /// Default mobile page padding — prefer [pagePaddingFor] on wide layouts.
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 12, 20, 24);

  static EdgeInsets pagePaddingFor(BuildContext context) =>
      ArchiveResponsiveLayout.pagePadding(context);
}