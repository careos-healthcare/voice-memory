import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'archive_semantic_colors.dart';
import 'voicememory_cards.dart';
import 'voicememory_colors.dart';
import 'voicememory_typography.dart';
import '../features/theme_system/visual_theme_tokens.dart';

/// App-wide light and dark themes selected from the device preference.
class AppTheme {
  AppTheme._();

  static const Color background = AppColors.backgroundPrimary;
  static const Color surface = AppColors.backgroundSecondary;
  static const Color muted = AppColors.textSecondary;
  static const Color foreground = AppColors.textPrimary;
  static const Color accent = AppColors.borderSubtle;

  static ThemeData fromTokens(VisualThemeTokens tokens) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: tokens.accent,
          brightness: tokens.brightness,
        ).copyWith(
          primary: tokens.accent,
          onPrimary: tokens.brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          secondary: tokens.secondaryAccent,
          surface: tokens.surface,
          onSurface: tokens.onSurface,
          surfaceContainer: tokens.surfaceElevated,
          surfaceContainerHighest: tokens.surfaceElevated,
          outline: tokens.outline,
          outlineVariant: tokens.outline.withValues(alpha: .65),
          error: tokens.negative,
        );
    final overlayStyle = tokens.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: tokens.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.background,
      canvasColor: tokens.background,
      extensions: [tokens, ArchiveSemanticColors.fromScheme(scheme)],
      textTheme: TextTheme(
        headlineLarge: VoiceMemoryTypography.headlineStyle(
          color: tokens.onSurface,
        ),
        headlineMedium: VoiceMemoryTypography.headlineStyle(
          color: tokens.onSurface,
        ),
        titleLarge: VoiceMemoryTypography.sectionTitleStyle(
          color: tokens.onSurface,
        ),
        titleMedium: VoiceMemoryTypography.cardTitleStyle(
          color: tokens.onSurface,
        ),
        bodyLarge: VoiceMemoryTypography.bodyStyle(color: tokens.onSurface),
        bodyMedium: VoiceMemoryTypography.metadataStyle(
          color: tokens.onSurface,
        ),
        bodySmall: VoiceMemoryTypography.secondaryStyle(
          color: tokens.onSurfaceMuted,
        ),
        labelLarge: VoiceMemoryTypography.cardTitleStyle(
          color: tokens.onSurface,
        ),
      ),
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle.copyWith(
          systemNavigationBarColor: tokens.background,
          systemNavigationBarIconBrightness:
              tokens.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tokens.outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.accent.withValues(alpha: .16),
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceElevated,
        selectedColor: tokens.accent.withValues(alpha: .18),
        side: BorderSide(color: tokens.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.accent,
          side: BorderSide(color: tokens.outline),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.outline, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceElevated,
        contentTextStyle: TextStyle(color: tokens.onSurface),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accentPrimary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.accentPrimary,
          onPrimary: AppColors.onAccent,
          primaryContainer: AppColors.accentLight,
          onPrimaryContainer: AppColors.textPrimary,
          secondary: AppColors.accentSecondary,
          onSecondary: AppColors.onAccent,
          secondaryContainer: Color(0xFFCCFBF1),
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
      extensions: [ArchiveSemanticColors.fromScheme(scheme)],
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
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accentPrimary,
      brightness: Brightness.dark,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      extensions: [ArchiveSemanticColors.fromScheme(scheme)],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: scheme.surface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }
}
