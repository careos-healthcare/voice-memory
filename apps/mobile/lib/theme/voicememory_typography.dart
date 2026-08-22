import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Reflective personal-archive type scale — generous line height, no all caps.
class VoiceMemoryTypography {
  VoiceMemoryTypography._();

  static const double headline = 32;
  static const double sectionTitle = 22;
  static const double body = 16;
  static const double caption = 14;

  static const double pageTitle = headline;
  static const double cardTitle = 18;
  static const double metadata = caption;
  static const double secondary = caption;

  static TextStyle headlineStyle({Color? color}) => TextStyle(
    fontSize: headline,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: color ?? VoiceMemoryColors.textPrimary,
    letterSpacing: -0.4,
  );

  static TextStyle sectionTitleStyle({Color? color}) => TextStyle(
    fontSize: sectionTitle,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: color ?? VoiceMemoryColors.textPrimary,
  );

  static TextStyle pageTitleStyle({Color? color}) =>
      headlineStyle(color: color);

  static TextStyle cardTitleStyle({Color? color}) => TextStyle(
    fontSize: cardTitle,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: color ?? VoiceMemoryColors.textPrimary,
  );

  static TextStyle bodyStyle({Color? color}) => TextStyle(
    fontSize: body,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color ?? VoiceMemoryColors.textPrimary,
  );

  static TextStyle metadataStyle({Color? color}) => TextStyle(
    fontSize: caption,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: color ?? VoiceMemoryColors.textSecondary,
  );

  static TextStyle secondaryStyle({Color? color}) =>
      metadataStyle(color: color);

  static TextStyle sectionLabelStyle({
    Color accent = VoiceMemoryColors.primaryIndigo,
  }) => TextStyle(
    fontSize: caption,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: accent,
  );
}