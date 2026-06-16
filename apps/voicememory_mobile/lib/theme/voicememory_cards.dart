import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'voicememory_colors.dart';

/// Premium cards — white surface, subtle border, 24px radius, soft shadow.
class VoiceMemoryCards {
  VoiceMemoryCards._();

  static const double radius = 24;

  static BoxDecoration standard({Color? background}) => BoxDecoration(
    color: background ?? VoiceMemoryColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: VoiceMemoryColors.border, width: 1),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowColor,
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration flat({Color? background}) => BoxDecoration(
    color: background ?? VoiceMemoryColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: VoiceMemoryColors.border, width: 1),
  );

  static CardThemeData cardTheme() => CardThemeData(
    color: VoiceMemoryColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: VoiceMemoryColors.border, width: 1),
    ),
    shadowColor: AppColors.shadowColor,
  );
}
