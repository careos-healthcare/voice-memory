import 'package:flutter/material.dart';

/// ArchiveMe consumer light palette — calm, premium, ambition-pressure tracking.
class AppColors {
  AppColors._();

  /// Page background — warm off-white.
  static const Color backgroundPrimary = Color(0xFFF8F6F1);

  /// Cards, sheets, nav bar.
  static const Color backgroundSecondary = Color(0xFFFFFFFF);

  /// Subtle grouped sections.
  static const Color surfaceAlt = Color(0xFFF3F0EA);

  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);

  /// De-emphasized text (timestamps, helper captions) — darker than
  /// [textSecondary] on [surfaceAlt]/[locked] backgrounds to keep WCAG AA
  /// (>=4.5:1) instead of the older gray-on-gray combination.
  static const Color textMuted = Color(0xFF4B5568);

  static const Color borderSubtle = Color(0xFFE5E0D8);

  /// Focus ring for keyboard/switch-control navigation.
  static const Color focusRing = Color(0xFF1D4ED8);

  /// Primary CTA / links.
  static const Color accentPrimary = Color(0xFF2563EB);

  /// Loop Mode / secondary emphasis.
  static const Color accentSecondary = Color(0xFF0F766E);

  /// Soft highlight fills (chips, selected states).
  static const Color accentLight = Color(0xFFEAF2FF);

  static const Color onAccent = Color(0xFFFFFFFF);

  static const Color warning = Color(0xFFB45309);
  static const Color success = Color(0xFF15803D);
  static const Color error = Color(0xFFDC2626);

  /// Destructive actions (delete account, clear archive, ignore-forever).
  static const Color destructive = Color(0xFFDC2626);
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