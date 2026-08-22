import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/first_session_pattern_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_rescue_tomorrow_journal_$stamp.json',
    prefsPath: '/tmp/vm_rescue_tomorrow_prefs_$stamp.json',
    skipRevenueCat: true,
  );
}

void main() {
  testWidgets('tomorrow check section shows Tomorrow, check this', (
    tester,
  ) async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await tester.runAsync(() => _reset(stamp));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstSessionPatternCard(
              pattern: ScreenshotSampleData.firstSessionPatternSample,
              reflectionText: 'I said yes before checking what I needed.',
            ),
          ),
        ),
      ),
    );

    expect(
      find.text(ConsumerUiCopy.firstSessionWatchTomorrowSection),
      findsOneWidget,
    );
    expect(find.text('Tomorrow, check this'), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.firstSessionUseTomorrowCta),
      findsOneWidget,
    );
  });

  testWidgets('Make it sharper changes the check option', (tester) async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await tester.runAsync(() => _reset(stamp));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstSessionPatternCard(
              pattern: ScreenshotSampleData.firstSessionPatternSample,
              reflectionText: 'I said yes before checking what I needed.',
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    await tester.tap(find.text(ConsumerUiCopy.makeItSharperCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Direct'), findsOneWidget);
    await tester.tap(find.text('Direct'));
    await tester.pump();
  });
}