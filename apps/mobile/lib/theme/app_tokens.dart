import 'package:archiveme_mobile/theme/archive_design_tokens.dart';
import 'package:flutter/material.dart';

/// Tailwind primary, neutral, type, and 4px spacing, shared with the web theme.
///
/// Hex values match `archiveDesignTokens.primary` and `.neutral`.
/// `spacingN` is N × 4px, the same step as Tailwind's spacing scale.
abstract final class AppTokens {
  static const Color primary50 = Color(0xFFEFF6FF);
  static const Color primary100 = Color(0xFFDBEAFE);
  static const Color primary200 = Color(0xFFBFDBFE);
  static const Color primary300 = Color(0xFF93C5FD);
  static const Color primary400 = Color(0xFF60A5FA);
  static const Color primary500 = Color(0xFF3B82F6);
  static const Color primary600 = Color(0xFF2563EB);
  static const Color primary700 = Color(0xFF1D4ED8);
  static const Color primary800 = Color(0xFF1E40AF);
  static const Color primary900 = Color(0xFF1E3A8A);

  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFE5E5E5);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral400 = Color(0xFFA3A3A3);
  static const Color neutral500 = Color(0xFF737373);
  static const Color neutral600 = Color(0xFF525252);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral800 = Color(0xFF262626);
  static const Color neutral900 = Color(0xFF171717);

  static const double spacing1 = 4.0;
  static const double spacing2 = 8.0;
  static const double spacing3 = 12.0;
  static const double spacing4 = 16.0;
  static const double spacing5 = 20.0;
  static const double spacing6 = 24.0;
  static const double spacing7 = 28.0;
  static const double spacing8 = 32.0;
  static const double spacing9 = 36.0;
  static const double spacing10 = 40.0;
  static const double spacing11 = 44.0;
  static const double spacing12 = 48.0;
  static const double spacing14 = 56.0;
  static const double spacing16 = 64.0;

  static TextStyle headline({Color? color}) => TextStyle(
    fontSize: ArchiveDesignTokens.fontHeadline,
    fontWeight: ArchiveDesignTokens.weightHeadline,
    height: ArchiveDesignTokens.leadingHeadline,
    letterSpacing: ArchiveDesignTokens.trackingHeadline,
    color: color ?? ArchiveDesignTokens.foreground,
  );

  static TextStyle section({Color? color}) => TextStyle(
    fontSize: ArchiveDesignTokens.fontSection,
    fontWeight: ArchiveDesignTokens.weightSection,
    height: ArchiveDesignTokens.leadingSection,
    letterSpacing: ArchiveDesignTokens.trackingSection,
    color: color ?? ArchiveDesignTokens.foreground,
  );

  static TextStyle card({Color? color}) => TextStyle(
    fontSize: ArchiveDesignTokens.fontCard,
    fontWeight: ArchiveDesignTokens.weightCard,
    height: ArchiveDesignTokens.leadingCard,
    letterSpacing: ArchiveDesignTokens.trackingCard,
    color: color ?? ArchiveDesignTokens.foreground,
  );

  static TextStyle body({Color? color}) => TextStyle(
    fontSize: ArchiveDesignTokens.fontBody,
    fontWeight: ArchiveDesignTokens.weightBody,
    height: ArchiveDesignTokens.leadingBody,
    letterSpacing: ArchiveDesignTokens.trackingBody,
    color: color ?? ArchiveDesignTokens.foreground,
  );

  static TextStyle caption({Color? color}) => TextStyle(
    fontSize: ArchiveDesignTokens.fontCaption,
    fontWeight: ArchiveDesignTokens.weightCaption,
    height: ArchiveDesignTokens.leadingCaption,
    letterSpacing: ArchiveDesignTokens.trackingCaption,
    color: color ?? ArchiveDesignTokens.muted,
  );

  static TextStyle writing({Color? color}) => TextStyle(
    fontSize: ArchiveDesignTokens.fontWriting,
    fontWeight: ArchiveDesignTokens.weightWriting,
    height: ArchiveDesignTokens.leadingWriting,
    letterSpacing: ArchiveDesignTokens.trackingWriting,
    color: color ?? ArchiveDesignTokens.foreground,
  );
}
