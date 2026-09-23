import 'package:flutter/material.dart';

/// Cross-platform ArchiveMe tokens. Keep in step with
/// `packages/shared/lib/design/archive-design-tokens.ts`.
abstract final class ArchiveDesignTokens {
  static const background = Color(0xFFF8F6F1);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF3F0EA);
  static const foreground = Color(0xFF172033);
  static const muted = Color(0xFF667085);
  static const subtle = Color(0xFF4B5568);
  static const border = Color(0xFFE5E0D8);
  static const accent = Color(0xFF2563EB);
  static const accentHover = Color(0xFF1D4ED8);
  static const accentSoft = Color(0xFFEAF2FF);
  static const onAccent = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF0F766E);
  static const focus = Color(0xFF1D4ED8);
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFDC2626);

  static const darkBackground = Color(0xFF09090B);
  static const darkForeground = Color(0xFFFAFAFA);
  static const darkMuted = Color(0xFFA1A1AA);
  static const darkAccent = Color(0xFF8B5CF6);

  static const spaceXs = 8.0;
  static const spaceSm = 16.0;
  static const spaceMd = 24.0;
  static const spaceLg = 32.0;
  static const spaceXl = 48.0;
  static const spaceTouch = 44.0;
  static const spaceControl = 48.0;
  static const spaceButton = 56.0;

  static const radiusControl = 16.0;
  static const radiusButton = 28.0;

  static const fontHeadline = 32.0;
  static const fontSection = 22.0;
  static const fontCard = 18.0;
  static const fontBody = 16.0;
  static const fontCaption = 14.0;
  static const fontWriting = 17.0;

  static const FontWeight weightHeadline = FontWeight.w700;
  static const FontWeight weightSection = FontWeight.w600;
  static const FontWeight weightCard = FontWeight.w600;
  static const FontWeight weightBody = FontWeight.w400;
  static const FontWeight weightCaption = FontWeight.w400;
  static const FontWeight weightWriting = FontWeight.w400;

  static const leadingHeadline = 1.35;
  static const leadingSection = 1.4;
  static const leadingCard = 1.4;
  static const leadingBody = 1.5;
  static const leadingCaption = 1.45;
  static const leadingWriting = 1.7;

  static const trackingHeadline = -0.4;
  static const trackingSection = 0.0;
  static const trackingCard = 0.0;
  static const trackingBody = 0.0;
  static const trackingCaption = 0.0;
  static const trackingWriting = 0.15;
}
