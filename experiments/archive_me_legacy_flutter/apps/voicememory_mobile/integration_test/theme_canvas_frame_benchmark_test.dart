import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicememory_mobile/features/memory_graph/rendering/memory_graph_visual_style.dart';
import 'package:voicememory_mobile/features/theme_system/theme_models.dart';
import 'package:voicememory_mobile/features/theme_system/visual_theme_tokens.dart';
import 'package:voicememory_mobile/shared/ui/glassmorphic_container.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile theme toggling and canvas navigation frame timings', (
    tester,
  ) async {
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> frames) => timings.addAll(frames);
    WidgetsBinding.instance.addTimingsCallback(collect);
    addTearDown(() => WidgetsBinding.instance.removeTimingsCallback(collect));

    await tester.pumpWidget(const _BenchmarkApp());
    for (var frame = 0; frame < 180; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    if (kProfileMode && timings.isNotEmpty) {
      final spans =
          timings
              .map(
                (frame) =>
                    frame.buildDuration.inMicroseconds +
                    frame.rasterDuration.inMicroseconds,
              )
              .toList()
            ..sort();
      final p90 = spans[(spans.length * .9).floor().clamp(0, spans.length - 1)];
      expect(
        p90,
        lessThanOrEqualTo(16667),
        reason: '90th percentile profile frame exceeded 60fps budget.',
      );
    }
  });
}

class _BenchmarkApp extends StatefulWidget {
  const _BenchmarkApp();

  @override
  State<_BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<_BenchmarkApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final archetype =
          ThemeArchetype.values[(_controller.value *
                      ThemeArchetype.values.length)
                  .floor() %
              ThemeArchetype.values.length];
      final tokens = VisualThemeTokens.resolve(
        ThemePreferences(archetype: archetype),
        Brightness.dark,
      );
      final style = MemoryGraphVisualStyle.fromTokens(tokens);
      return MaterialApp(
        theme: ThemeData(
          brightness: tokens.brightness,
          scaffoldBackgroundColor: tokens.background,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(
                    _controller.value * -160,
                    _controller.value * 80,
                  ),
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _BenchmarkGraphPainter(style)),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: GlassmorphicContainer(
                  fillColor: tokens.glassFill,
                  opacity: tokens.glassOpacity,
                  blurSigma: tokens.blurSigma,
                  refractionColors: [
                    tokens.glassBorderStart,
                    tokens.glassBorderEnd,
                  ],
                  child: Text(
                    archetype.name,
                    style: TextStyle(color: tokens.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _BenchmarkGraphPainter extends CustomPainter {
  const _BenchmarkGraphPainter(this.style);
  final MemoryGraphVisualStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = style.background);
    final edge = Paint()
      ..color = style.edge.withValues(alpha: .4)
      ..strokeWidth = 1;
    for (var index = 0; index < 2500; index++) {
      final point = Offset((index % 50) * 24.0, (index ~/ 50) * 24.0);
      if (index % 50 != 49) {
        canvas.drawLine(point, point + const Offset(24, 0), edge);
      }
      canvas.drawCircle(
        point,
        2.5,
        Paint()..color = style.nodePalette[index % style.nodePalette.length],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BenchmarkGraphPainter oldDelegate) =>
      oldDelegate.style != style;
}
