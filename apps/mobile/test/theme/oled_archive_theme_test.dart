import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/oled_archive_theme.dart';
import 'package:archiveme_mobile/theme/writing_canvas_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark theme is true black with OLED contrast and scale padding', () {
    final theme = AppTheme.dark();

    expect(theme.scaffoldBackgroundColor, OledArchiveTheme.black);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(theme.canvasColor, const Color(0xFF000000));
    expect(theme.colorScheme.surface, const Color(0xFF000000));
    expect(theme.textTheme.bodyLarge?.color, isNot(const Color(0xFFFFFFFF)));

    expect(
      OledArchiveTheme.contrastRatio(OledArchiveTheme.text, OledArchiveTheme.black),
      greaterThanOrEqualTo(12),
    );
    expect(
      OledArchiveTheme.contrastRatio(
        OledArchiveTheme.textSecondary,
        OledArchiveTheme.black,
      ),
      greaterThanOrEqualTo(7),
    );
    expect(
      OledArchiveTheme.contrastRatio(
        OledArchiveTheme.textTertiary,
        OledArchiveTheme.black,
      ),
      greaterThanOrEqualTo(4.5),
    );

    final wide = OledArchiveTheme.paddingForLogicalWidth(
      OledArchiveTheme.spaceBlack13LogicalShortSide,
    );
    expect(wide.left, AppSpacing.lg);
    expect(wide.top, AppSpacing.xs);
    expect(wide.bottom, AppSpacing.md);
    expect(
      OledArchiveTheme.paddingForLogicalWidth(390).left,
      AppSpacing.sm,
    );
    expect(ArchiveMobileSpacing.pagePadding, OledArchiveTheme.phonePadding);

    final canvas = theme.extension<WritingCanvasTheme>();
    expect(canvas?.textStyle.height, WritingCanvasTheme.lineHeight);
    expect(canvas?.contentPadding.vertical, 36);
  });
}
