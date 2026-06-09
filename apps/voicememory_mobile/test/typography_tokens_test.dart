import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/record/tomorrow_return_card.dart';

void main() {
  group('ArchiveMobileTypography minimums', () {
    testWidgets('phone body and explanation styles meet readable minimum',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        ArchiveMobileTypography.responsiveBody(context).fontSize,
        greaterThanOrEqualTo(ArchiveMobileTypography.minBodySize),
      );
      expect(
        ArchiveMobileTypography.explanationBody(context).fontSize,
        greaterThanOrEqualTo(ArchiveMobileTypography.minExplanationSize),
      );
      expect(
        ArchiveMobileTypography.cardLabel(context).fontSize,
        greaterThanOrEqualTo(ArchiveMobileTypography.minLabelSize),
      );
    });

    testWidgets('wide layouts scale type without shrinking below phone minimums',
        (tester) async {
      late double phoneTitle;
      late double wideTitle;
      late double wideBody;

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              phoneTitle =
                  ArchiveMobileTypography.responsivePageTitle(context).fontSize!;
              return const SizedBox();
            },
          ),
        ),
      );

      tester.view.physicalSize = const Size(1024, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              wideTitle =
                  ArchiveMobileTypography.responsivePageTitle(context).fontSize!;
              wideBody =
                  ArchiveMobileTypography.responsiveBody(context).fontSize!;
              return const SizedBox();
            },
          ),
        ),
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(wideBody, greaterThanOrEqualTo(ArchiveMobileTypography.minBodySize));
      expect(wideTitle, greaterThan(phoneTitle));
    });
  });

  testWidgets('TomorrowReturnCard uses explanation body for primary copy',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TomorrowReturnCard(
            loop: ScreenshotSampleData.tomorrowReturnLoop,
          ),
        ),
      ),
    );
    await tester.pump();

    final bodyTexts = tester.widgetList<Text>(find.byType(Text)).where((t) {
      final data = t.data ?? '';
      return data == ConsumerUiCopy.tomorrowComparePatternsBody;
    });
    expect(bodyTexts, isNotEmpty);
    for (final text in bodyTexts) {
      expect(
        text.style?.fontSize ?? 0,
        greaterThanOrEqualTo(ArchiveMobileTypography.minBodySize),
      );
    }
  });
}
