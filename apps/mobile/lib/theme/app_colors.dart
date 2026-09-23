import 'package:archiveme_mobile/theme/archive_design_tokens.dart';
import 'package:flutter/material.dart';

/// ArchiveMe consumer light palette — calm, premium, ambition-pressure tracking.
class AppColors {
  AppColors._();

  /// Page background — warm off-white.
  static const Color backgroundPrimary = ArchiveDesignTokens.background;
  static const Color backgroundSecondary = ArchiveDesignTokens.surface;
  static const Color surfaceAlt = ArchiveDesignTokens.surfaceAlt;
  static const Color textPrimary = ArchiveDesignTokens.foreground;
  static const Color textSecondary = ArchiveDesignTokens.muted;
  static const Color textMuted = ArchiveDesignTokens.subtle;
  static const Color borderSubtle = ArchiveDesignTokens.border;
  static const Color focusRing = ArchiveDesignTokens.focus;
  static const Color accentPrimary = ArchiveDesignTokens.accent;
  static const Color accentSecondary = ArchiveDesignTokens.secondary;
  static const Color accentLight = ArchiveDesignTokens.accentSoft;
  static const Color onAccent = ArchiveDesignTokens.onAccent;
  static const Color warning = ArchiveDesignTokens.warning;
  static const Color success = ArchiveDesignTokens.success;
  static const Color error = ArchiveDesignTokens.danger;

  /// Destructive actions (delete account, clear archive, ignore-forever).
  static const Color destructive = ArchiveDesignTokens.danger;
  static const Color destructiveLight = Color(0xFFFDECEC);

  /// Locked/unavailable (Pro-gated) surfaces. [lockedText] on [lockedSurface]
  /// resolves to ~4.6:1 contrast, fixing the earlier gray-on-gray pairing
  /// (textSecondary on surfaceAlt) called out in the accessibility audit.
  static const Color lockedSurface = Color(0xFFEDEBE4);
  static const Color lockedText = Color(0xFF3F4757);
  static const Color lockedIcon = Color(0xFF5B6478);

  /// Proof-confidence bands — plain-language labels pair with these fills,
  /// never a raw numeric score.
  static const Color proofConfidenceLow = Color(0xFF9A6A00);
  static const Color proofConfidenceMedium = Color(0xFF2563EB);
  static const Color proofConfidenceHigh = Color(0xFF15803D);

  /// Value-emphasis surface (e.g. Free vs Pro comparison cards). Slightly
  /// cooler/greener than [surfaceAlt] so a comparison block reads as a
  /// distinct highlighted region rather than another grouped section.
  static const Color surfaceHighlight = Color(0xFFF8FAF8);

  /// Warm nudge/insight card surface — the "what to try next" style prompt
  /// cards (post-save insight, next-evidence prompt, etc.). This exact value
  /// is already the de facto standard for that card family across the app
  /// (most of those call sites still use a private `_warmSurface` constant
  /// rather than this token); naming it here lets newly-touched call sites
  /// reference one documented token instead of repeating the raw literal.
  static const Color warmSurface = Color(0xFFFFFBF5);

  /// Warm nudge/insight card border — pairs with [warmSurface] as the border
  /// of that same card family. Like [warmSurface], most existing call sites
  /// still repeat this as a private `_warmBorder` constant; this token lets
  /// newly-touched call sites consolidate on one documented value.
  static const Color warmBorder = Color(0xFFF5E6D3);

  /// Fully transparent — used to suppress a default Material paint (e.g.
  /// splash/highlight/divider colors, or a surfaceTintColor override) rather
  /// than to convey any visible hue. Named here so raw-literal migration
  /// doesn't have to invent a fake semantic meaning for "no paint".
  static const Color transparent = Color(0x00000000);

  static Color get shadowColor => const Color(0x0D172033);
}
