import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/theme_system/memory_typography.dart';

void main() {
  test('viewport-fluid bases grow and remain bounded', () {
    final compact = MemoryTypography.forViewport(320);
    final wide = MemoryTypography.forViewport(1024);
    final oversized = MemoryTypography.forViewport(2000);

    expect(wide.pageTitle.fontSize, greaterThan(compact.pageTitle.fontSize!));
    expect(wide.body.fontSize, greaterThan(compact.body.fontSize!));
    expect(oversized.pageTitle.fontSize, wide.pageTitle.fontSize);
    expect(
      oversized.graphLabelMetrics.fontSize,
      wide.graphLabelMetrics.fontSize,
    );
    expect(MemoryTypography.readableLineWidth, 680);
  });

  testWidgets('system TextScaler remains authoritative without clamping', (
    tester,
  ) async {
    const scaler = TextScaler.linear(2.75);
    late MemoryTypography typography;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), textScaler: scaler),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              typography = MemoryTypography.of(context);
              return Text('A remembered detail', style: typography.body);
            },
          ),
        ),
      ),
    );

    final baseSize = typography.body.fontSize!;
    expect(typography.textScaler.scale(baseSize), baseSize * 2.75);
    final richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.textScaler.scale(baseSize), baseSize * 2.75);
  });

  test('graph label metrics honor large accessibility scaling', () {
    final typography = MemoryTypography.forViewport(
      390,
      textScaler: const TextScaler.linear(4),
    );
    final metrics = typography.graphLabelMetrics;

    expect(metrics.scaledFontSize(typography.textScaler), metrics.fontSize * 4);
    expect(
      metrics.scaledFontSize(typography.textScaler, selected: true),
      metrics.selectedFontSize * 4,
    );
  });
}
