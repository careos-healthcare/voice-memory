import 'package:flutter/material.dart';

/// Semantic colour roles for retained V1 surfaces.
///
/// Screens name what a colour *means* — evidence, a Then quote, a destructive
/// action — never a literal light-mode value. Because every role is derived
/// from the active [ColorScheme], a surface that uses these tokens is correct
/// in dark mode by construction rather than by inspection.
///
/// Meaning is never carried by colour alone; these roles pair with the labels
/// and icons the widgets already render.
@immutable
class ArchiveSemanticColors extends ThemeExtension<ArchiveSemanticColors> {
  const ArchiveSemanticColors({
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.divider,
    required this.focus,
    required this.evidenceQuote,
    required this.evidenceQuoteSurface,
    required this.thenEvidence,
    required this.nowEvidence,
    required this.success,
    required this.warning,
    required this.destructive,
    required this.disabled,
    required this.selected,
  });

  final Color background;
  final Color surface;
  final Color elevatedSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color divider;
  final Color focus;

  /// Colour of the user's own saved words when quoted back to them.
  final Color evidenceQuote;
  final Color evidenceQuoteSurface;

  /// The earlier side of a comparison.
  final Color thenEvidence;

  /// The later side of a comparison.
  final Color nowEvidence;

  final Color success;
  final Color warning;
  final Color destructive;
  final Color disabled;
  final Color selected;

  static ArchiveSemanticColors fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return ArchiveSemanticColors(
      background: scheme.surface,
      surface: scheme.surfaceContainerLow,
      elevatedSurface: scheme.surfaceContainerHigh,
      primaryText: scheme.onSurface,
      secondaryText: scheme.onSurfaceVariant,
      divider: scheme.outlineVariant,
      focus: scheme.primary,
      evidenceQuote: scheme.onSurface,
      evidenceQuoteSurface: scheme.surfaceContainerHighest,
      thenEvidence: isDark ? const Color(0xFFAAB4C3) : const Color(0xFF5C6B7F),
      nowEvidence: scheme.primary,
      success: isDark ? const Color(0xFF4ADE80) : const Color(0xFF1B7F3B),
      warning: isDark ? const Color(0xFFFBBF24) : const Color(0xFF8A5A00),
      destructive: scheme.error,
      disabled: scheme.onSurface.withValues(alpha: .38),
      selected: scheme.primary.withValues(alpha: isDark ? .24 : .12),
    );
  }

  /// Resolves the tokens for [context], falling back to the active scheme so a
  /// widget can never silently render an unthemed colour.
  static ArchiveSemanticColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ArchiveSemanticColors>() ??
        fromScheme(theme.colorScheme);
  }

  @override
  ArchiveSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? elevatedSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? divider,
    Color? focus,
    Color? evidenceQuote,
    Color? evidenceQuoteSurface,
    Color? thenEvidence,
    Color? nowEvidence,
    Color? success,
    Color? warning,
    Color? destructive,
    Color? disabled,
    Color? selected,
  }) => ArchiveSemanticColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    primaryText: primaryText ?? this.primaryText,
    secondaryText: secondaryText ?? this.secondaryText,
    divider: divider ?? this.divider,
    focus: focus ?? this.focus,
    evidenceQuote: evidenceQuote ?? this.evidenceQuote,
    evidenceQuoteSurface: evidenceQuoteSurface ?? this.evidenceQuoteSurface,
    thenEvidence: thenEvidence ?? this.thenEvidence,
    nowEvidence: nowEvidence ?? this.nowEvidence,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    destructive: destructive ?? this.destructive,
    disabled: disabled ?? this.disabled,
    selected: selected ?? this.selected,
  );

  @override
  ArchiveSemanticColors lerp(covariant ArchiveSemanticColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return ArchiveSemanticColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      elevatedSurface: mix(elevatedSurface, other.elevatedSurface),
      primaryText: mix(primaryText, other.primaryText),
      secondaryText: mix(secondaryText, other.secondaryText),
      divider: mix(divider, other.divider),
      focus: mix(focus, other.focus),
      evidenceQuote: mix(evidenceQuote, other.evidenceQuote),
      evidenceQuoteSurface: mix(
        evidenceQuoteSurface,
        other.evidenceQuoteSurface,
      ),
      thenEvidence: mix(thenEvidence, other.thenEvidence),
      nowEvidence: mix(nowEvidence, other.nowEvidence),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      destructive: mix(destructive, other.destructive),
      disabled: mix(disabled, other.disabled),
      selected: mix(selected, other.selected),
    );
  }
}
