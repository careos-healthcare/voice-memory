import 'package:archiveme_mobile/theme/archive_design_tokens.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Reflective personal-archive type scale — generous line height, no all caps.
class VoiceMemoryTypography {
  VoiceMemoryTypography._();

  static const double headline = ArchiveDesignTokens.fontHeadline;
  static const double sectionTitle = ArchiveDesignTokens.fontSection;
  static const double body = ArchiveDesignTokens.fontBody;
  static const double caption = ArchiveDesignTokens.fontCaption;

  static const double pageTitle = headline;
  static const double cardTitle = ArchiveDesignTokens.fontCard;
  static const double metadata = caption;
  static const double secondary = caption;

  static TextStyle headlineStyle({Color? color}) => TextStyle(
    fontSize: headline,
    fontWeight: ArchiveDesignTokens.weightHeadline,
    height: ArchiveDesignTokens.leadingHeadline,
    letterSpacing: ArchiveDesignTokens.trackingHeadline,
    color: color ?? VoiceMemoryColors.textPrimary,
  );

  static TextStyle sectionTitleStyle({Color? color}) => TextStyle(
    fontSize: sectionTitle,
    fontWeight: ArchiveDesignTokens.weightSection,
    height: ArchiveDesignTokens.leadingSection,
    letterSpacing: ArchiveDesignTokens.trackingSection,
    color: color ?? VoiceMemoryColors.textPrimary,
  );

  static TextStyle pageTitleStyle({Color? color}) =>
      headlineStyle(color: color);

  static TextStyle cardTitleStyle({Color? color}) => TextStyle(
    fontSize: cardTitle,
    fontWeight: ArchiveDesignTokens.weightCard,
    height: ArchiveDesignTokens.leadingCard,
    letterSpacing: ArchiveDesignTokens.trackingCard,
    color: color ?? VoiceMemoryColors.textPrimary,
  );

  static TextStyle bodyStyle({Color? color}) => TextStyle(
    fontSize: body,
    fontWeight: ArchiveDesignTokens.weightBody,
    height: ArchiveDesignTokens.leadingBody,
    letterSpacing: ArchiveDesignTokens.trackingBody,
    color: color ?? VoiceMemoryColors.textPrimary,
  );

  /// Writing-canvas body — editorial leading for long-form typing.
  static TextStyle writingCanvasStyle({Color? color}) => TextStyle(
    fontSize: ArchiveDesignTokens.fontWriting,
    fontWeight: ArchiveDesignTokens.weightWriting,
    height: ArchiveDesignTokens.leadingWriting,
    letterSpacing: ArchiveDesignTokens.trackingWriting,
    color: color ?? VoiceMemoryColors.textPrimary,
  );

  static TextStyle metadataStyle({Color? color}) => TextStyle(
    fontSize: caption,
    fontWeight: ArchiveDesignTokens.weightCaption,
    height: ArchiveDesignTokens.leadingCaption,
    letterSpacing: ArchiveDesignTokens.trackingCaption,
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
