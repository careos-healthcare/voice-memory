import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/memory_graph/rendering/memory_graph_visual_style.dart';
import 'package:voicememory_mobile/features/theme_system/theme_models.dart';
import 'package:voicememory_mobile/features/theme_system/visual_theme_tokens.dart';

void main() {
  test('rapid theme projection and canvas transforms stay CPU-bounded', () {
    final stopwatch = Stopwatch()..start();
    var checksum = 0;
    for (var index = 0; index < 25000; index++) {
      final archetype =
          ThemeArchetype.values[index % ThemeArchetype.values.length];
      final tokens = VisualThemeTokens.resolve(
        ThemePreferences(
          archetype: archetype,
          customAccentValue: Color.fromARGB(
            255,
            index % 255,
            (index * 3) % 255,
            (index * 7) % 255,
          ).toARGB32(),
          nodeGlowDiffusion: (index % 150) / 100,
        ),
        index.isEven ? Brightness.dark : Brightness.light,
      );
      final style = MemoryGraphVisualStyle.fromTokens(tokens);
      final transform = Matrix4.identity()
        ..translateByDouble(index % 640, index % 480, 0, 1)
        ..scaleByDouble(1 + math.sin(index / 100) * .4, 1, 1, 1);
      checksum ^= style.background.toARGB32();
      checksum ^= transform.storage[index % 16].round();
    }
    stopwatch.stop();

    expect(checksum, isA<int>());
    // This host-side guard detects accidental super-linear work. GPU blur and
    // real 60fps are measured by the profile integration benchmark.
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
  });
}
