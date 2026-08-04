import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme_models.dart';

@immutable
final class VisualThemeTokens extends ThemeExtension<VisualThemeTokens> {
  const VisualThemeTokens({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.accent,
    required this.secondaryAccent,
    required this.outline,
    required this.glassFill,
    required this.glassBorderStart,
    required this.glassBorderEnd,
    required this.graphBackground,
    required this.graphGrid,
    required this.graphEdge,
    required this.graphSelection,
    required this.graphLabelSurface,
    required this.graphLabelText,
    required this.documentNode,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.nodePalette,
    required this.blurSigma,
    required this.glassOpacity,
    required this.nodeGlowDiffusion,
    required this.glassEffects,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color accent;
  final Color secondaryAccent;
  final Color outline;
  final Color glassFill;
  final Color glassBorderStart;
  final Color glassBorderEnd;
  final Color graphBackground;
  final Color graphGrid;
  final Color graphEdge;
  final Color graphSelection;
  final Color graphLabelSurface;
  final Color graphLabelText;
  final Color documentNode;
  final Color positive;
  final Color negative;
  final Color warning;
  final List<Color> nodePalette;
  final double blurSigma;
  final double glassOpacity;
  final double nodeGlowDiffusion;
  final GlassEffectPreference glassEffects;

  static VisualThemeTokens resolve(
    ThemePreferences preferences,
    Brightness platformBrightness,
  ) {
    final base = switch (preferences.archetype) {
      ThemeArchetype.obsidian => _obsidian,
      ThemeArchetype.parchment => _parchment,
      ThemeArchetype.cyberMatrix => _cyberMatrix,
      ThemeArchetype.dynamicSystem =>
        platformBrightness == Brightness.dark ? _dynamicDark : _dynamicLight,
    };
    final accent = preferences.customAccent ?? base.accent;
    final secondary = Color.lerp(accent, base.secondaryAccent, .55)!;
    return base.copyWith(
      accent: accent,
      secondaryAccent: secondary,
      glassFill: base.glassFill.withValues(alpha: preferences.glassOpacity),
      blurSigma: preferences.glassBlur,
      glassOpacity: preferences.glassOpacity,
      nodeGlowDiffusion: preferences.nodeGlowDiffusion,
      glassEffects: preferences.glassEffects,
      nodePalette: [accent, secondary, ...base.nodePalette.skip(2)],
    );
  }

  static const _obsidian = VisualThemeTokens(
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    surface: Color(0xFF07090D),
    surfaceElevated: Color(0xFF10131A),
    onSurface: Color(0xFFF4F7FB),
    onSurfaceMuted: Color(0xFF9BA7B8),
    accent: Color(0xFF22D3EE),
    secondaryAccent: Color(0xFF9B5CFF),
    outline: Color(0xFF263141),
    glassFill: Color(0xDC080C12),
    glassBorderStart: Color(0x99C7F9FF),
    glassBorderEnd: Color(0x225B70FF),
    graphBackground: Color(0xFF000000),
    graphGrid: Color(0x1922D3EE),
    graphEdge: Color(0xFF5D6C81),
    graphSelection: Color(0xFF67E8F9),
    graphLabelSurface: Color(0xE6111620),
    graphLabelText: Color(0xFFF4F7FB),
    documentNode: Color(0xFFA78BFA),
    positive: Color(0xFF34D399),
    negative: Color(0xFFFB7185),
    warning: Color(0xFFFBBF24),
    nodePalette: [
      Color(0xFF22D3EE),
      Color(0xFF9B5CFF),
      Color(0xFF34D399),
      Color(0xFFFFB454),
      Color(0xFFF472B6),
      Color(0xFF60A5FA),
    ],
    blurSigma: 18,
    glassOpacity: .86,
    nodeGlowDiffusion: .65,
    glassEffects: GlassEffectPreference.automatic,
  );

  static const _parchment = VisualThemeTokens(
    brightness: Brightness.light,
    background: Color(0xFFF4EAD7),
    surface: Color(0xFFFBF4E7),
    surfaceElevated: Color(0xFFFFFBF2),
    onSurface: Color(0xFF493B2B),
    onSurfaceMuted: Color(0xFF786650),
    accent: Color(0xFF9A5B35),
    secondaryAccent: Color(0xFF6F7B45),
    outline: Color(0xFFCDBB9F),
    glassFill: Color(0xE8FFF8EA),
    glassBorderStart: Color(0xE6FFFFFF),
    glassBorderEnd: Color(0x669A7A55),
    graphBackground: Color(0xFFF1E4CF),
    graphGrid: Color(0x268A6C48),
    graphEdge: Color(0xFF8B7357),
    graphSelection: Color(0xFF8E4B2B),
    graphLabelSurface: Color(0xEEFFF9EE),
    graphLabelText: Color(0xFF493B2B),
    documentNode: Color(0xFF7C5F8D),
    positive: Color(0xFF4D7A4B),
    negative: Color(0xFFAA4B40),
    warning: Color(0xFFAD6B24),
    nodePalette: [
      Color(0xFF9A5B35),
      Color(0xFF6F7B45),
      Color(0xFF527A78),
      Color(0xFFC17A45),
      Color(0xFF9A6175),
      Color(0xFF65749A),
    ],
    blurSigma: 12,
    glassOpacity: .91,
    nodeGlowDiffusion: .35,
    glassEffects: GlassEffectPreference.automatic,
  );

  static const _cyberMatrix = VisualThemeTokens(
    brightness: Brightness.dark,
    background: Color(0xFF080A09),
    surface: Color(0xFF111512),
    surfaceElevated: Color(0xFF181E19),
    onSurface: Color(0xFFE8F5E9),
    onSurfaceMuted: Color(0xFF9EAC9F),
    accent: Color(0xFFFFB000),
    secondaryAccent: Color(0xFF00E676),
    outline: Color(0xFF314638),
    glassFill: Color(0xE6121713),
    glassBorderStart: Color(0xAAFFE29A),
    glassBorderEnd: Color(0x4400E676),
    graphBackground: Color(0xFF080A09),
    graphGrid: Color(0x3300E676),
    graphEdge: Color(0xFF59A36E),
    graphSelection: Color(0xFFFFC247),
    graphLabelSurface: Color(0xEE101711),
    graphLabelText: Color(0xFFE8F5E9),
    documentNode: Color(0xFFFFC857),
    positive: Color(0xFF00E676),
    negative: Color(0xFFFF5A5F),
    warning: Color(0xFFFFB000),
    nodePalette: [
      Color(0xFFFFB000),
      Color(0xFF00E676),
      Color(0xFF00BCD4),
      Color(0xFFFF7043),
      Color(0xFF76FF03),
      Color(0xFFFFD740),
    ],
    blurSigma: 14,
    glassOpacity: .88,
    nodeGlowDiffusion: .85,
    glassEffects: GlassEffectPreference.automatic,
  );

  static const _dynamicLight = VisualThemeTokens(
    brightness: Brightness.light,
    background: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0F3F8),
    onSurface: Color(0xFF101828),
    onSurfaceMuted: Color(0xFF667085),
    accent: Color(0xFF5B5FEF),
    secondaryAccent: Color(0xFF14B8A6),
    outline: Color(0xFFD0D5DD),
    glassFill: Color(0xE8FFFFFF),
    glassBorderStart: Color(0xFFFFFFFF),
    glassBorderEnd: Color(0x557C8DB5),
    graphBackground: Color(0xFFF8FAFC),
    graphGrid: Color(0x148B6F47),
    graphEdge: Color(0xFF667085),
    graphSelection: Color(0xFFFFB547),
    graphLabelSurface: Color(0xEFFFFFFF),
    graphLabelText: Color(0xFF101828),
    documentNode: Color(0xFF7C5CFC),
    positive: Color(0xFF238636),
    negative: Color(0xFFCF222E),
    warning: Color(0xFF9A6700),
    nodePalette: [
      Color(0xFF5B5FEF),
      Color(0xFF14B8A6),
      Color(0xFF0072B2),
      Color(0xFFD97706),
      Color(0xFFA83C82),
      Color(0xFF2E7D32),
    ],
    blurSigma: 18,
    glassOpacity: .86,
    nodeGlowDiffusion: .55,
    glassEffects: GlassEffectPreference.automatic,
  );

  static const _dynamicDark = VisualThemeTokens(
    brightness: Brightness.dark,
    background: Color(0xFF0C1017),
    surface: Color(0xFF151B24),
    surfaceElevated: Color(0xFF1D2531),
    onSurface: Color(0xFFF2F4F7),
    onSurfaceMuted: Color(0xFFAAB4C3),
    accent: Color(0xFF8B8FFF),
    secondaryAccent: Color(0xFF2DD4BF),
    outline: Color(0xFF344054),
    glassFill: Color(0xE619202B),
    glassBorderStart: Color(0x99DCE3FF),
    glassBorderEnd: Color(0x334F67A5),
    graphBackground: Color(0xFF0C1017),
    graphGrid: Color(0x225B6D8C),
    graphEdge: Color(0xFF8491A5),
    graphSelection: Color(0xFFFFC468),
    graphLabelSurface: Color(0xED17202C),
    graphLabelText: Color(0xFFF2F4F7),
    documentNode: Color(0xFFAA8DFF),
    positive: Color(0xFF4ADE80),
    negative: Color(0xFFFB7185),
    warning: Color(0xFFFBBF24),
    nodePalette: [
      Color(0xFF8B8FFF),
      Color(0xFF2DD4BF),
      Color(0xFF60A5FA),
      Color(0xFFF59E0B),
      Color(0xFFF472B6),
      Color(0xFF4ADE80),
    ],
    blurSigma: 18,
    glassOpacity: .86,
    nodeGlowDiffusion: .65,
    glassEffects: GlassEffectPreference.automatic,
  );

  @override
  VisualThemeTokens copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? accent,
    Color? secondaryAccent,
    Color? outline,
    Color? glassFill,
    Color? glassBorderStart,
    Color? glassBorderEnd,
    Color? graphBackground,
    Color? graphGrid,
    Color? graphEdge,
    Color? graphSelection,
    Color? graphLabelSurface,
    Color? graphLabelText,
    Color? documentNode,
    Color? positive,
    Color? negative,
    Color? warning,
    List<Color>? nodePalette,
    double? blurSigma,
    double? glassOpacity,
    double? nodeGlowDiffusion,
    GlassEffectPreference? glassEffects,
  }) => VisualThemeTokens(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    onSurface: onSurface ?? this.onSurface,
    onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
    accent: accent ?? this.accent,
    secondaryAccent: secondaryAccent ?? this.secondaryAccent,
    outline: outline ?? this.outline,
    glassFill: glassFill ?? this.glassFill,
    glassBorderStart: glassBorderStart ?? this.glassBorderStart,
    glassBorderEnd: glassBorderEnd ?? this.glassBorderEnd,
    graphBackground: graphBackground ?? this.graphBackground,
    graphGrid: graphGrid ?? this.graphGrid,
    graphEdge: graphEdge ?? this.graphEdge,
    graphSelection: graphSelection ?? this.graphSelection,
    graphLabelSurface: graphLabelSurface ?? this.graphLabelSurface,
    graphLabelText: graphLabelText ?? this.graphLabelText,
    documentNode: documentNode ?? this.documentNode,
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
    warning: warning ?? this.warning,
    nodePalette: nodePalette ?? this.nodePalette,
    blurSigma: blurSigma ?? this.blurSigma,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    nodeGlowDiffusion: nodeGlowDiffusion ?? this.nodeGlowDiffusion,
    glassEffects: glassEffects ?? this.glassEffects,
  );

  @override
  VisualThemeTokens lerp(covariant VisualThemeTokens? other, double t) {
    if (other == null) return this;
    Color color(Color left, Color right) => Color.lerp(left, right, t)!;
    final paletteLength = nodePalette.length < other.nodePalette.length
        ? nodePalette.length
        : other.nodePalette.length;
    return copyWith(
      brightness: t < .5 ? brightness : other.brightness,
      background: color(background, other.background),
      surface: color(surface, other.surface),
      surfaceElevated: color(surfaceElevated, other.surfaceElevated),
      onSurface: color(onSurface, other.onSurface),
      onSurfaceMuted: color(onSurfaceMuted, other.onSurfaceMuted),
      accent: color(accent, other.accent),
      secondaryAccent: color(secondaryAccent, other.secondaryAccent),
      outline: color(outline, other.outline),
      glassFill: color(glassFill, other.glassFill),
      glassBorderStart: color(glassBorderStart, other.glassBorderStart),
      glassBorderEnd: color(glassBorderEnd, other.glassBorderEnd),
      graphBackground: color(graphBackground, other.graphBackground),
      graphGrid: color(graphGrid, other.graphGrid),
      graphEdge: color(graphEdge, other.graphEdge),
      graphSelection: color(graphSelection, other.graphSelection),
      graphLabelSurface: color(graphLabelSurface, other.graphLabelSurface),
      graphLabelText: color(graphLabelText, other.graphLabelText),
      documentNode: color(documentNode, other.documentNode),
      positive: color(positive, other.positive),
      negative: color(negative, other.negative),
      warning: color(warning, other.warning),
      nodePalette: [
        for (var index = 0; index < paletteLength; index++)
          color(nodePalette[index], other.nodePalette[index]),
      ],
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t),
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t),
      nodeGlowDiffusion: lerpDouble(
        nodeGlowDiffusion,
        other.nodeGlowDiffusion,
        t,
      ),
      glassEffects: t < .5 ? glassEffects : other.glassEffects,
    );
  }
}
