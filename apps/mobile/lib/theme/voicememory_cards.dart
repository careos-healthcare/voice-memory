import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Premium cards — white surface, subtle border, 24px radius, soft shadow.
class VoiceMemoryCards {
  VoiceMemoryCards._();

  static const double radius = 24;

  static BoxDecoration standard({Color? background, BuildContext? context}) {
    final scheme = context == null ? null : Theme.of(context).colorScheme;
    return BoxDecoration(
      color: background ?? scheme?.surface ?? VoiceMemoryColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: scheme?.outline ?? VoiceMemoryColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration flat({Color? background, BuildContext? context}) {
    final scheme = context == null ? null : Theme.of(context).colorScheme;
    return BoxDecoration(
      color: background ?? scheme?.surface ?? VoiceMemoryColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: scheme?.outline ?? VoiceMemoryColors.border),
    );
  }

  static CardThemeData cardTheme({Color? surface, Color? border}) =>
      CardThemeData(
        color: surface ?? VoiceMemoryColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: border ?? VoiceMemoryColors.border),
        ),
        shadowColor: AppColors.shadowColor,
      );
}
