import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Shared consumer-facing type scale — use instead of raw metadata styles for explanations.
abstract class ArchiveMobileTypography {
  ArchiveMobileTypography._();

  static const double minBodySize = 16;
  static const double minBodySizeWide = 17;
  static const double minExplanationSize = 16;
  static const double minExplanationSizeWide = 17;
  static const double minLabelSize = 14;
  static const double minLabelSizeWide = 15;
  static const double minHelperSize = 13.5;
  static const double minHelperSizeWide = 14.5;
  static const double minCtaSize = 16;

  /// Serif for the person's own words. Sans for everything the app writes.
  static const String userWordsFamily = 'Newsreader';
  static const String uiFamily = 'Inter';

  static TextStyle userWords(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: userWordsFamily,
    fontSize: 17,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle userWordsQuote(BuildContext context, {Color? color}) =>
      userWords(context, color: color).copyWith(fontStyle: FontStyle.italic);

  static TextStyle uiTitle(BuildContext context, {Color? color}) =>
      responsiveSectionTitle(context).copyWith(
        fontFamily: uiFamily,
        color: color,
      );

  static TextStyle uiBody(BuildContext context, {Color? color}) =>
      responsiveBody(context, color: color).copyWith(fontFamily: uiFamily);

  static TextStyle uiLabel(BuildContext context, {Color? color}) =>
      cardLabel(context, color: color).copyWith(fontFamily: uiFamily);

  static TextStyle uiHelper(BuildContext context, {Color? color}) =>
      responsiveHelper(context, color: color).copyWith(fontFamily: uiFamily);

  static bool _wide(BuildContext context) =>
      ArchiveResponsiveLayout.isTabletOrDesktop(context);

  static TextStyle eyebrow(BuildContext context) => cardLabel(context);

  static TextStyle recordPageTitle(BuildContext context) =>
      responsivePageTitle(context);

  static TextStyle responsivePageTitle(BuildContext context) =>
      VoiceMemoryTypography.headlineStyle().copyWith(
        fontSize: _wide(context) ? 32 : 26,
        height: 1.25,
        letterSpacing: -0.35,
      );

  static TextStyle responsiveSectionTitle(BuildContext context) =>
      VoiceMemoryTypography.sectionTitleStyle().copyWith(
        fontSize: _wide(context) ? 19 : 17,
        height: 1.3,
      );

  /// Primary readable body — default for subtitles and card copy.
  static TextStyle responsiveBody(BuildContext context, {Color? color}) =>
      VoiceMemoryTypography.bodyStyle(
        color: color ?? VoiceMemoryColors.textSecondary,
      ).copyWith(
        fontSize: _wide(context) ? minBodySizeWide : minBodySize,
        height: 1.45,
      );

  /// Main explanations — never caption-sized.
  static TextStyle explanationBody(BuildContext context, {Color? color}) =>
      VoiceMemoryTypography.bodyStyle(
        color: color ?? VoiceMemoryColors.textPrimary,
      ).copyWith(
        fontSize: _wide(context) ? minExplanationSizeWide : minExplanationSize,
        height: 1.45,
      );

  /// Section labels inside cards (replaces metadata for headings).
  static TextStyle cardLabel(BuildContext context, {Color? color}) => TextStyle(
    fontSize: _wide(context) ? minLabelSizeWide : minLabelSize,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: color ?? VoiceMemoryColors.primaryIndigo,
  );

  static TextStyle responsiveHelper(BuildContext context, {Color? color}) =>
      VoiceMemoryTypography.metadataStyle(
        color: color ?? VoiceMemoryColors.textSecondary,
      ).copyWith(
        fontSize: _wide(context) ? minHelperSizeWide : minHelperSize,
        height: 1.4,
      );

  static TextStyle responsiveCta(BuildContext context) => const TextStyle(
    fontSize: minCtaSize,
    fontWeight: FontWeight.w600,
    color: VoiceMemoryColors.onPrimary,
  );

  static TextStyle listTitle(BuildContext context) => TextStyle(
    fontSize: _wide(context) ? 17 : 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: VoiceMemoryColors.textPrimary,
  );

  static TextStyle listSubtitle(BuildContext context) =>
      responsiveBody(context);

  static TextStyle pageTitle(BuildContext context) =>
      archiveSurfaceTitle(context);

  /// Primary archive surface titles — 28–34pt hierarchy.
  static TextStyle archiveSurfaceTitle(BuildContext context) =>
      VoiceMemoryTypography.headlineStyle().copyWith(
        fontSize: _wide(context) ? 34 : 30,
        height: 1.2,
        letterSpacing: -0.4,
        color: VoiceMemoryColors.textPrimary,
      );

  static TextStyle sectionTitle(BuildContext context) =>
      responsiveSectionTitle(context);

  static TextStyle body(BuildContext context) => responsiveBody(context);

  static TextStyle caption(BuildContext context) => responsiveHelper(context);
}

/// A person's words set as a quotation: italic serif and a left rule.
class UserWordsQuote extends StatelessWidget {
  const UserWordsQuote({
    required this.text,
    super.key,
    this.maxLines,
    this.color,
    this.fontSize,
  });

  final String text;
  final int? maxLines;
  final Color? color;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: ink.withValues(alpha: 0.45), width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          text,
          maxLines: maxLines,
          overflow: maxLines == null
              ? TextOverflow.clip
              : TextOverflow.ellipsis,
          style: ArchiveMobileTypography.userWordsQuote(
            context,
            color: ink,
          ).copyWith(fontSize: fontSize),
        ),
      ),
    );
  }
}
