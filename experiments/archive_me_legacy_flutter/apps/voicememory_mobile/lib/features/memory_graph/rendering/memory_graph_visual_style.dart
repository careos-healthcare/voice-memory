import 'package:flutter/material.dart';

import '../../../core/graph/graph_node.dart';
import '../../theme_system/visual_theme_tokens.dart';

@immutable
final class MemoryGraphVisualStyle {
  const MemoryGraphVisualStyle({
    required this.background,
    required this.grid,
    required this.edge,
    required this.selection,
    required this.labelSurface,
    required this.labelText,
    required this.cardSurface,
    required this.cardShadow,
    required this.documentNode,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.nodePalette,
    required this.glowDiffusion,
  });

  final Color background;
  final Color grid;
  final Color edge;
  final Color selection;
  final Color labelSurface;
  final Color labelText;
  final Color cardSurface;
  final Color cardShadow;
  final Color documentNode;
  final Color positive;
  final Color negative;
  final Color warning;
  final List<Color> nodePalette;
  final double glowDiffusion;

  factory MemoryGraphVisualStyle.fromTokens(VisualThemeTokens tokens) =>
      MemoryGraphVisualStyle(
        background: tokens.graphBackground,
        grid: tokens.graphGrid,
        edge: tokens.graphEdge,
        selection: tokens.graphSelection,
        labelSurface: tokens.graphLabelSurface,
        labelText: tokens.graphLabelText,
        cardSurface: tokens.surfaceElevated,
        cardShadow: tokens.brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .65)
            : Colors.black.withValues(alpha: .22),
        documentNode: tokens.documentNode,
        positive: tokens.positive,
        negative: tokens.negative,
        warning: tokens.warning,
        nodePalette: List.unmodifiable(tokens.nodePalette),
        glowDiffusion: tokens.nodeGlowDiffusion,
      );

  static const fallback = MemoryGraphVisualStyle(
    background: Color(0xFFF8FAFC),
    grid: Color(0x148B6F47),
    edge: Color(0xFF667085),
    selection: Color(0xFFFFB547),
    labelSurface: Color(0xEFFFFFFF),
    labelText: Color(0xFF101828),
    cardSurface: Color(0xFFF8FAFC),
    cardShadow: Color(0x55000000),
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
    glowDiffusion: .55,
  );

  Color nodeColor(NodeType type) =>
      nodePalette[type.index % nodePalette.length];

  @override
  bool operator ==(Object other) =>
      other is MemoryGraphVisualStyle &&
      other.background == background &&
      other.grid == grid &&
      other.edge == edge &&
      other.selection == selection &&
      other.labelSurface == labelSurface &&
      other.labelText == labelText &&
      other.cardSurface == cardSurface &&
      other.cardShadow == cardShadow &&
      other.documentNode == documentNode &&
      other.positive == positive &&
      other.negative == negative &&
      other.warning == warning &&
      other.glowDiffusion == glowDiffusion &&
      _paletteEquals(other.nodePalette, nodePalette);

  @override
  int get hashCode => Object.hash(
    background,
    grid,
    edge,
    selection,
    labelSurface,
    labelText,
    cardSurface,
    cardShadow,
    documentNode,
    positive,
    negative,
    warning,
    glowDiffusion,
    Object.hashAll(nodePalette),
  );
}

bool _paletteEquals(List<Color> left, List<Color> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
