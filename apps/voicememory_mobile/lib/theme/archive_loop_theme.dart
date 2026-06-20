import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Soft, warm palette for loop-map surfaces — avoids harsh clinical white stacks.
abstract class ArchiveLoopTheme {
  ArchiveLoopTheme._();

  static const loopBackground = Color(0xFFF5F0E8);
  static const loopCard = Color(0xFFFAF7F2);
  static const loopCardAlt = Color(0xFFF0EBE3);
  static const loopBorder = Color(0xFFE4DAD0);
  static const loopAccentSoft = Color(0xFF4A6B85);
  static const loopTextPrimary = Color(0xFF2C2825);
  static const loopTextSecondary = Color(0xFF6B6560);

  static const double cardRadius = 20;

  static BoxDecoration cardDecoration({Color? background}) => BoxDecoration(
    color: background ?? loopCard,
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: loopBorder, width: 1),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowColor.withValues(alpha: 0.35),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );

  static ButtonStyle primaryCtaStyle(BuildContext context) {
    return FilledButton.styleFrom(
      backgroundColor: loopAccentSoft,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  static ButtonStyle secondaryCtaStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: loopAccentSoft,
      side: const BorderSide(color: loopBorder, width: 1.2),
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
