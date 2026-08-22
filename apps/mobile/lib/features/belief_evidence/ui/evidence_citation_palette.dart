import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Colours for the citation surfaces, resolved per [Brightness].
///
/// [AppColors] is a light-only palette, so the dark values are derived from
/// the active [ColorScheme] instead of a second hard-coded palette. Every dark
/// foreground is blended against the background it sits on so the pairs stay
/// at or above 4.5:1 rather than inheriting whatever the seed produced.
class EvidenceCitationPalette {
  const EvidenceCitationPalette({
    required this.quoteBackground,
    required this.quoteBorder,
    required this.quoteAccent,
    required this.quoteText,
    required this.quoteMeta,
    required this.ungroundedBackground,
    required this.ungroundedBorder,
    required this.ungroundedIcon,
    required this.ungroundedTitle,
    required this.ungroundedBody,
  });

  factory EvidenceCitationPalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (scheme.brightness == Brightness.light) {
      return const EvidenceCitationPalette(
        quoteBackground: AppColors.accentLight,
        quoteBorder: AppColors.accentPrimary,
        quoteAccent: AppColors.accentPrimary,
        quoteText: AppColors.textPrimary,
        quoteMeta: AppColors.textMuted,
        ungroundedBackground: AppColors.surfaceAlt,
        ungroundedBorder: AppColors.borderSubtle,
        ungroundedIcon: AppColors.warning,
        ungroundedTitle: AppColors.textPrimary,
        ungroundedBody: AppColors.textMuted,
      );
    }

    final quoteBackground = scheme.primaryContainer;
    final ungroundedBackground = scheme.surfaceContainerHighest;
    return EvidenceCitationPalette(
      quoteBackground: quoteBackground,
      quoteBorder: scheme.primary,
      quoteAccent: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.55),
        scheme.onPrimaryContainer,
      ),
      quoteText: scheme.onPrimaryContainer,
      quoteMeta: Color.alphaBlend(
        scheme.onPrimaryContainer.withValues(alpha: 0.78),
        quoteBackground,
      ),
      ungroundedBackground: ungroundedBackground,
      ungroundedBorder: scheme.outline,
      ungroundedIcon: Color.alphaBlend(
        AppColors.warning.withValues(alpha: 0.45),
        scheme.onSurface,
      ),
      ungroundedTitle: scheme.onSurface,
      ungroundedBody: Color.alphaBlend(
        scheme.onSurface.withValues(alpha: 0.82),
        ungroundedBackground,
      ),
    );
  }

  final Color quoteBackground;
  final Color quoteBorder;
  final Color quoteAccent;
  final Color quoteText;
  final Color quoteMeta;
  final Color ungroundedBackground;
  final Color ungroundedBorder;
  final Color ungroundedIcon;
  final Color ungroundedTitle;
  final Color ungroundedBody;
}
