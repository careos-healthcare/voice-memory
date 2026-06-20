import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/first_session_pattern_card.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '${Directory.systemTemp.path}/vm_rescue_tomorrow_journal_$stamp.json',
    prefsPath: '${Directory.systemTemp.path}/vm_rescue_tomorrow_prefs_$stamp.json',
    skipRevenueCat: true,
  );
}

void main() {
  setUpAll(() async {
    await _reset('widget_harness');
  });

  testWidgets('tomorrow check section shows Tomorrow, check this', (
    tester,
  ) async {
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

    expect(
      find.text(ConsumerUiCopy.firstSessionWatchTomorrowSection),
      findsOneWidget,
    );
    expect(find.text('Tomorrow, check this'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.tomorrowCheckReasonLine), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.firstSessionUseTomorrowCta),
      findsOneWidget,
    );
  });

  testWidgets('Make it sharper changes the check option', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    expect(find.text(ConsumerUiCopy.chooseTomorrowQuestionLabel), findsNothing);
    await tester.scrollUntilVisible(
      find.text(ConsumerUiCopy.makeItSharperCta),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(ConsumerUiCopy.makeItSharperCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(ConsumerUiCopy.chooseTomorrowQuestionLabel), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Direct'));
    await tester.pump();
  });

  test('tomorrow check activation events increment', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = ActivationEventsStore(AppServices.instance.prefs);

    await ActivationTracker.trackActivationTomorrowCheckShown();
    await ActivationTracker.trackActivationTomorrowCheckUsed();
    await ActivationTracker.trackActivationTomorrowCheckSharpened();
    final events = await store.read();
    expect(events.activationTomorrowCheckShown, 1);
    expect(events.activationTomorrowCheckUsed, 1);
    expect(events.activationTomorrowCheckSharpened, 1);
  });
}
