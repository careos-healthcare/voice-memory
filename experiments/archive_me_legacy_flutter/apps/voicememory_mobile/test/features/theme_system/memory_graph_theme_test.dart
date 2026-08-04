import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/features/memory_graph/rendering/memory_graph_visual_style.dart';
import 'package:voicememory_mobile/features/theme_system/theme_models.dart';
import 'package:voicememory_mobile/features/theme_system/visual_theme_tokens.dart';
import 'package:voicememory_mobile/ui/screens/life_os/graph_painter.dart';
import 'package:voicememory_mobile/ui/screens/life_os/knowledge_graph_layout.dart';

void main() {
  test('graph style projects every preset palette', () {
    for (final archetype in ThemeArchetype.values) {
      final tokens = VisualThemeTokens.resolve(
        ThemePreferences(archetype: archetype),
        Brightness.dark,
      );
      final style = MemoryGraphVisualStyle.fromTokens(tokens);
      expect(style.background, tokens.graphBackground);
      expect(style.documentNode, tokens.documentNode);
      expect(style.nodeColor(NodeType.person), isNot(Colors.transparent));
      expect(style.glowDiffusion, tokens.nodeGlowDiffusion);
    }
  });

  test('painter invalidates on palette and text scale changes', () {
    final node = GraphNode(
      id: 'goal',
      type: NodeType.goal,
      label: 'Future self',
      confidence: .9,
      evidence: [
        GraphNodeEvidence(
          entryId: 'entry',
          observedAt: DateTime.utc(2026, 7, 1),
          confidence: .9,
          excerpt: 'Future self',
          startUtf16: 0,
          endUtf16: 11,
        ),
      ],
    );
    final layout = ForceDirectedKnowledgeGraphLayout.compute(
      [node],
      const [],
      const Size(400, 300),
    );
    final viewState = KnowledgeGraphViewState();
    final controller = TransformationController();
    addTearDown(viewState.dispose);
    addTearDown(controller.dispose);
    GraphPainter painter(MemoryGraphVisualStyle style, TextScaler textScaler) =>
        GraphPainter(
          layout: layout,
          edges: const [],
          viewState: viewState,
          transformationController: controller,
          viewportSize: layout.size,
          visualStyle: style,
          textScaler: textScaler,
          onSemanticTap: (_) {},
        );

    final base = painter(MemoryGraphVisualStyle.fallback, TextScaler.noScaling);
    final darkStyle = MemoryGraphVisualStyle.fromTokens(
      VisualThemeTokens.resolve(
        const ThemePreferences(archetype: ThemeArchetype.obsidian),
        Brightness.dark,
      ),
    );
    expect(
      painter(darkStyle, TextScaler.noScaling).shouldRepaint(base),
      isTrue,
    );
    expect(
      painter(
        MemoryGraphVisualStyle.fallback,
        const TextScaler.linear(2),
      ).shouldRepaint(base),
      isTrue,
    );
    expect(base.visibleEdgeCount, 0);
  });
}
