import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/onboarding/onboarding_visuals.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/onboarding_screen.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';

/// Exports onboarding-1.png … onboarding-4.png for design review.
///
/// Run:
/// ```bash
/// cd apps/voicememory_mobile
/// flutter test test/export_onboarding_pages_png_test.dart
/// ```
///
/// Output default: `~/Desktop/upload12/screenshots/onboarding-{1..4}.png`
void main() {
  testWidgets('export belief-first onboarding pages as PNG', (tester) async {
    const logicalSize = Size(393, 852);
    await tester.binding.setSurfaceSize(logicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final home = Platform.environment['HOME'] ?? '';
    final outDir =
        Platform.environment['ONBOARDING_SCREENSHOT_ROOT'] ??
        (home.isNotEmpty
            ? '$home/Desktop/upload12/screenshots'
            : 'build/onboarding_screenshots');
    await Directory(outDir).create(recursive: true);

    for (var i = 0; i < OnboardingPages.pageCount; i++) {
      final page = OnboardingPages.pages[i];
      final isLast = i == OnboardingPages.pageCount - 1;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.backgroundPrimary,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.accentPrimary,
              brightness: Brightness.light,
            ),
          ),
          home: MediaQuery(
            data: const MediaQueryData(size: logicalSize),
            child: SizedBox(
              width: logicalSize.width,
              height: logicalSize.height,
              child: _OnboardingExportFrame(
                pageIndex: i,
                page: page,
                isLast: isLast,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await _writePng(tester: tester, path: '$outDir/onboarding-${i + 1}.png');
    }

    // ignore: avoid_print
    print('Onboarding screenshots written to: $outDir');
  });
}

class _OnboardingExportFrame extends StatelessWidget {
  const _OnboardingExportFrame({
    required this.pageIndex,
    required this.page,
    required this.isLast,
  });

  final int pageIndex;
  final OnboardingPageData page;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: OnboardingAmbientGlow()),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.xs,
                      0,
                    ),
                    child: Text(
                      'ArchiveMe',
                      style: OnboardingTypography.label(
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            page.title,
                            style: OnboardingTypography.title(context),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            page.body,
                            style: OnboardingTypography.body(context),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          OnboardingPageVisual(page: page),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        for (var j = 0; j < OnboardingPages.pageCount; j++)
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: j < OnboardingPages.pageCount - 1
                                    ? 6
                                    : 0,
                              ),
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: j <= pageIndex
                                    ? AppColors.accentPrimary
                                    : AppColors.borderSubtle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: isLast
                        ? FilledButton(
                            onPressed: () {},
                            child: Text(ConsumerUiCopy.onboardingFinalCta),
                          )
                        : FilledButton(
                            onPressed: () {},
                            child: const Text('Continue'),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _writePng({
  required WidgetTester tester,
  required String path,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(bytes, isNotNull);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}
