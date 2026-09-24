import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:archiveme_mobile/theme/archive_design_tokens.dart';
import 'package:archiveme_mobile/theme/oled_archive_theme.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/theme/writing_canvas_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App-wide light and dark themes — follows system appearance by default.
class AppTheme {
  AppTheme._();

  static const Color background = AppColors.backgroundPrimary;
  static const Color surface = AppColors.backgroundSecondary;
  static const Color muted = AppColors.textSecondary;
  static const Color foreground = AppColors.textPrimary;
  static const Color accent = AppColors.borderSubtle;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppTokens.primary600)
        .copyWith(
          primary: AppTokens.primary600,
          onPrimary: AppColors.onAccent,
          primaryContainer: AppColors.accentLight,
          onPrimaryContainer: AppColors.textPrimary,
          secondary: AppColors.accentSecondary,
          onSecondary: AppColors.onAccent,
          secondaryContainer: const Color(0xFFCCFBF1),
          onSecondaryContainer: AppColors.textPrimary,
          surface: AppColors.backgroundSecondary,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.surfaceAlt,
          outline: AppColors.borderSubtle,
          error: AppColors.error,
          onError: AppColors.onAccent,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.backgroundPrimary,
      canvasColor: AppColors.backgroundPrimary,
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        surfaceTintColor: Colors.transparent,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.backgroundPrimary,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: VoiceMemoryCards.cardTheme(),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        indicatorColor: AppColors.accentPrimary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            );
          }
          return VoiceMemoryTypography.metadataStyle(
            color: VoiceMemoryColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.accentPrimary);
          }
          return const IconThemeData(color: VoiceMemoryColors.textTertiary);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.primary600,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(
            double.infinity,
            ArchiveDesignTokens.spaceButton,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spacing4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ArchiveDesignTokens.radiusButton,
            ),
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          minimumSize: const Size(
            ArchiveDesignTokens.spaceControl,
            ArchiveDesignTokens.spaceControl,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          side: const BorderSide(color: AppColors.borderSubtle),
          minimumSize: const Size(
            ArchiveDesignTokens.spaceControl,
            ArchiveDesignTokens.spaceControl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ArchiveDesignTokens.radiusButton,
            ),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: AppColors.onAccent,
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentPrimary,
        linearTrackColor: AppColors.accentLight,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.accentLight,
        selectedColor: AppColors.accentPrimary.withValues(alpha: 0.14),
        labelStyle: VoiceMemoryTypography.metadataStyle(),
        secondaryLabelStyle: VoiceMemoryTypography.metadataStyle(
          color: AppColors.accentPrimary,
        ),
        side: const BorderSide(color: AppColors.borderSubtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ArchiveDesignTokens.radiusControl,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: AppTokens.headline(),
        headlineMedium: AppTokens.headline(),
        titleLarge: AppTokens.section(),
        titleMedium: AppTokens.card(),
        bodyLarge: AppTokens.body(),
        bodyMedium: AppTokens.writing(),
        bodySmall: AppTokens.caption(),
        labelLarge: AppTokens.card(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        hintStyle: VoiceMemoryTypography.metadataStyle(
          color: VoiceMemoryColors.textTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            ArchiveDesignTokens.radiusControl,
          ),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            ArchiveDesignTokens.radiusControl,
          ),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            ArchiveDesignTokens.radiusControl,
          ),
          borderSide: const BorderSide(
            color: AppColors.accentPrimary,
            width: 1.5,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        contentTextStyle: VoiceMemoryTypography.metadataStyle(
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ArchiveDesignTokens.radiusControl,
          ),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[WritingCanvasTheme.light],
    );
  }

  /// True-black OLED theme used when the system appearance is dark.
  static ThemeData dark() => OledArchiveTheme.data();
}
