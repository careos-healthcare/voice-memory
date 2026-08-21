import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
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

  // Dark palette — mirrors light structure with inverted luminance.
  static const Color _darkBackgroundPrimary = Color(0xFF0F1419);
  static const Color _darkBackgroundSecondary = Color(0xFF1A2234);
  static const Color _darkSurfaceAlt = Color(0xFF232D3F);
  static const Color _darkTextPrimary = Color(0xFFF3F4F6);
  static const Color _darkTextSecondary = Color(0xFF9CA3AF);
  static const Color _darkTextTertiary = Color(0xFF6B7280);
  static const Color _darkBorderSubtle = Color(0xFF2D3748);
  static const Color _darkAccentPrimary = Color(0xFF3B82F6);
  static const Color _darkAccentSecondary = Color(0xFF14B8A6);
  static const Color _darkAccentLight = Color(0xFF1E3A5F);
  static const Color _darkError = Color(0xFFF87171);

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accentPrimary,
        ).copyWith(
          primary: AppColors.accentPrimary,
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
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          side: const BorderSide(color: AppColors.borderSubtle),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: VoiceMemoryTypography.headlineStyle(),
        headlineMedium: VoiceMemoryTypography.headlineStyle(),
        titleLarge: VoiceMemoryTypography.sectionTitleStyle(),
        titleMedium: VoiceMemoryTypography.cardTitleStyle(),
        bodyLarge: VoiceMemoryTypography.bodyStyle(),
        bodyMedium: VoiceMemoryTypography.metadataStyle(),
        bodySmall: VoiceMemoryTypography.secondaryStyle(),
        labelLarge: VoiceMemoryTypography.cardTitleStyle(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        hintStyle: VoiceMemoryTypography.metadataStyle(
          color: VoiceMemoryColors.textTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _darkAccentPrimary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _darkAccentPrimary,
          onPrimary: AppColors.onAccent,
          primaryContainer: _darkAccentLight,
          onPrimaryContainer: _darkTextPrimary,
          secondary: _darkAccentSecondary,
          onSecondary: AppColors.onAccent,
          secondaryContainer: const Color(0xFF134E4A),
          onSecondaryContainer: _darkTextPrimary,
          surface: _darkBackgroundSecondary,
          onSurface: _darkTextPrimary,
          surfaceContainerHighest: _darkSurfaceAlt,
          outline: _darkBorderSubtle,
          error: _darkError,
          onError: AppColors.onAccent,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _darkBackgroundPrimary,
      canvasColor: _darkBackgroundPrimary,
      dialogTheme: const DialogThemeData(
        backgroundColor: _darkBackgroundSecondary,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkBackgroundSecondary,
        surfaceTintColor: Colors.transparent,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackgroundPrimary,
        foregroundColor: _darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: _darkBackgroundPrimary,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkBackgroundSecondary,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
          side: const BorderSide(color: _darkBorderSubtle),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.35),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkBackgroundSecondary,
        indicatorColor: _darkAccentPrimary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return VoiceMemoryTypography.metadataStyle(
              color: _darkAccentPrimary,
            );
          }
          return VoiceMemoryTypography.metadataStyle(
            color: _darkTextTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _darkAccentPrimary);
          }
          return const IconThemeData(color: _darkTextTertiary);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _darkAccentPrimary,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkAccentPrimary,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkAccentPrimary,
          side: const BorderSide(color: _darkBorderSubtle),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _darkAccentPrimary,
        foregroundColor: AppColors.onAccent,
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _darkAccentPrimary,
        linearTrackColor: _darkAccentLight,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkAccentLight,
        selectedColor: _darkAccentPrimary.withValues(alpha: 0.22),
        labelStyle: VoiceMemoryTypography.metadataStyle(
          color: _darkTextPrimary,
        ),
        secondaryLabelStyle: VoiceMemoryTypography.metadataStyle(
          color: _darkAccentPrimary,
        ),
        side: const BorderSide(color: _darkBorderSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorderSubtle,
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: VoiceMemoryTypography.headlineStyle(
          color: _darkTextPrimary,
        ),
        headlineMedium: VoiceMemoryTypography.headlineStyle(
          color: _darkTextPrimary,
        ),
        titleLarge: VoiceMemoryTypography.sectionTitleStyle(
          color: _darkTextPrimary,
        ),
        titleMedium: VoiceMemoryTypography.cardTitleStyle(
          color: _darkTextPrimary,
        ),
        bodyLarge: VoiceMemoryTypography.bodyStyle(color: _darkTextPrimary),
        bodyMedium: VoiceMemoryTypography.metadataStyle(
          color: _darkTextSecondary,
        ),
        bodySmall: VoiceMemoryTypography.secondaryStyle(
          color: _darkTextSecondary,
        ),
        labelLarge: VoiceMemoryTypography.cardTitleStyle(
          color: _darkTextPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkBackgroundSecondary,
        hintStyle: VoiceMemoryTypography.metadataStyle(
          color: _darkTextTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _darkBorderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _darkBorderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _darkAccentPrimary,
            width: 1.5,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkBackgroundSecondary,
        contentTextStyle: VoiceMemoryTypography.metadataStyle(
          color: _darkTextPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorderSubtle),
        ),
      ),
    );
  }
}