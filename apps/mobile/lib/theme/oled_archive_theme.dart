import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/writing_canvas_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// OLED dark theme for a 13-inch Space Black display.
///
/// The canvas is true black so unused pixels stay off. Type is off-white,
/// not pure white, so large text does not halo on tandem OLED. Every inset
/// is an [AppSpacing] step: 8, 16, 24, 32, or 48.
class OledArchiveTheme {
  OledArchiveTheme._();

  /// iPad Pro 13-inch (Space Black) logical short side at a 2× scale.
  static const double spaceBlack13LogicalShortSide = 1032;

  static const Color black = Color(0xFF000000);
  static const Color text = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color hairline = Color(0xFF2C2C2E);
  static const Color error = Color(0xFFFF8A80);

  static const EdgeInsets phonePadding = EdgeInsets.fromLTRB(
    AppSpacing.sm,
    AppSpacing.xs,
    AppSpacing.sm,
    AppSpacing.sm,
  );

  /// Wide canvas, including the 13-inch portrait and landscape sizes.
  static const EdgeInsets spaceBlack13Padding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.xs,
    AppSpacing.lg,
    AppSpacing.md,
  );

  static EdgeInsets paddingForLogicalWidth(double width) =>
      width >= 600 ? spaceBlack13Padding : phonePadding;

  static double contrastRatio(Color foreground, Color background) {
    final foregroundLuminance = foreground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    final lighter = foregroundLuminance > backgroundLuminance
        ? foregroundLuminance
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance
        ? backgroundLuminance
        : foregroundLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static ThemeData data() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: text,
      onPrimary: black,
      secondary: textSecondary,
      onSecondary: black,
      error: error,
      onError: black,
      surface: black,
      onSurface: text,
      surfaceContainerLowest: black,
      surfaceContainerLow: black,
      surfaceContainer: black,
      surfaceContainerHigh: black,
      surfaceContainerHighest: black,
      outline: hairline,
      outlineVariant: hairline,
      surfaceTint: black,
    );

    const title = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      height: 1.3,
      letterSpacing: -0.2,
      color: text,
    );
    const body = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: text,
    );
    const label = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: black,
      canvasColor: black,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: title,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          statusBarColor: black,
          systemNavigationBarColor: black,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      cardTheme: const CardThemeData(
        color: black,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: hairline),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: black,
        modalElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: text.withValues(alpha: 0.08),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return label.copyWith(color: selected ? text : textTertiary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? text : textTertiary);
        }),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        minVerticalPadding: AppSpacing.xs,
        tileColor: black,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: text,
          foregroundColor: black,
          elevation: 0,
          minimumSize: const Size(AppSpacing.xl, AppSpacing.xl),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: const RoundedRectangleBorder(),
          textStyle: label.copyWith(color: black),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(AppSpacing.xl, AppSpacing.xl),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          textStyle: label.copyWith(color: text),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: hairline),
          minimumSize: const Size(AppSpacing.xl, AppSpacing.xl),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: const RoundedRectangleBorder(),
          textStyle: label.copyWith(color: text),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: text,
        foregroundColor: black,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: text,
        linearTrackColor: hairline,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: black,
        selectedColor: text.withValues(alpha: 0.08),
        labelStyle: label,
        side: const BorderSide(color: hairline),
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 0.5,
        space: AppSpacing.sm,
      ),
      textTheme: TextTheme(
        headlineLarge: title.copyWith(fontSize: 28),
        headlineMedium: title,
        titleLarge: title,
        titleMedium: body.copyWith(fontWeight: FontWeight.w500),
        bodyLarge: body,
        bodyMedium: label,
        bodySmall: label.copyWith(color: textTertiary),
        labelLarge: label.copyWith(color: text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: black,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        hintStyle: label.copyWith(color: textTertiary),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: text),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: black,
        elevation: 0,
        behavior: SnackBarBehavior.fixed,
        contentTextStyle: label.copyWith(color: text),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: hairline),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[WritingCanvasTheme.oled],
    );
  }
}
