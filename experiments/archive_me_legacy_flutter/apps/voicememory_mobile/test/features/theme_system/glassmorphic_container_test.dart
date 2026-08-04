import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/shared/ui/glassmorphic_container.dart';

void main() {
  Widget host({
    required GlassRenderQuality quality,
    GlassRenderPolicy policy = const AccessibilityAwareGlassRenderPolicy(),
    MediaQueryData mediaQuery = const MediaQueryData(),
  }) => MediaQuery(
    data: mediaQuery,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: GlassmorphicContainer(
        renderQuality: quality,
        renderPolicy: policy,
        child: const Text('Memory'),
      ),
    ),
  );

  Finder refractionPainter() => find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint &&
        widget.foregroundPainter is GlassRefractionBorderPainter,
  );

  testWidgets('full quality uses clipped blur and refraction shader', (
    tester,
  ) async {
    await tester.pumpWidget(host(quality: GlassRenderQuality.full));

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(refractionPainter(), findsOneWidget);
  });

  testWidgets('reduced quality keeps refraction but removes blur pass', (
    tester,
  ) async {
    await tester.pumpWidget(host(quality: GlassRenderQuality.reduced));

    expect(find.byType(BackdropFilter), findsNothing);
    expect(refractionPainter(), findsOneWidget);
  });

  testWidgets('off quality uses opaque border fallback without shaders', (
    tester,
  ) async {
    await tester.pumpWidget(host(quality: GlassRenderQuality.off));

    expect(find.byType(BackdropFilter), findsNothing);
    expect(refractionPainter(), findsNothing);
    final decoration =
        tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
            as BoxDecoration;
    expect(decoration.color?.a, 1);
    expect(decoration.border, isNotNull);
  });

  test('accessibility policy lowers expensive or translucent effects', () {
    const policy = AccessibilityAwareGlassRenderPolicy();

    expect(
      policy.resolve(
        const MediaQueryData(disableAnimations: true),
        GlassRenderQuality.full,
      ),
      GlassRenderQuality.reduced,
    );
    expect(
      policy.resolve(
        const MediaQueryData(highContrast: true),
        GlassRenderQuality.full,
      ),
      GlassRenderQuality.off,
    );
    expect(
      const AccessibilityAwareGlassRenderPolicy(
        isLowCapability: true,
      ).resolve(const MediaQueryData(), GlassRenderQuality.full),
      GlassRenderQuality.reduced,
    );
  });
}
