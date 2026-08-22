import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Theme-aware colors for premium share card export (light + dark).
class ArchiveDiscoverySharePalette {
  const ArchiveDiscoverySharePalette({
    required this.background,
    required this.backgroundGradientEnd,
    required this.border,
    required this.headline,
    required this.insight,
    required this.evidence,
    required this.footer,
    required this.accent,
    required this.shadow,
  });

  factory ArchiveDiscoverySharePalette.fromBrightness(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    if (isDark) {
      return const ArchiveDiscoverySharePalette(
        background: Color(0xFF0F1117),
        backgroundGradientEnd: Color(0xFF1A1F2E),
        border: Color(0xFF5B6CFF),
        headline: Color(0xFF9CA3AF),
        insight: Color(0xFFF3F4F6),
        evidence: Color(0xFF9CA3AF),
        footer: Color(0xFF8B9CFF),
        accent: VoiceMemoryColors.primaryIndigo,
        shadow: Color(0x66000000),
      );
    }
    return const ArchiveDiscoverySharePalette(
      background: Color(0xFFFAFAFC),
      backgroundGradientEnd: Color(0xFFF0F2FF),
      border: Color(0xFF4F5FD5),
      headline: Color(0xFF6B7280),
      insight: Color(0xFF111827),
      evidence: Color(0xFF6B7280),
      footer: VoiceMemoryColors.primaryIndigo,
      accent: VoiceMemoryColors.primaryIndigo,
      shadow: Color(0x1A1F2937),
    );
  }

  factory ArchiveDiscoverySharePalette.fromContext(BuildContext context) =>
      ArchiveDiscoverySharePalette.fromBrightness(Theme.of(context).brightness);

  final Color background;
  final Color backgroundGradientEnd;
  final Color border;
  final Color headline;
  final Color insight;
  final Color evidence;
  final Color footer;
  final Color accent;
  final Color shadow;
}