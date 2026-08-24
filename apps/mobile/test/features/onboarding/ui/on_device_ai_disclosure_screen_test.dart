import 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_disclosure_screen.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_explanation_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _requestedFalseOnDeviceBody =
    'Our AI processes everything directly on this device. Your data never '
    'leaves your phone.';

void main() {
  Widget wrapScreen({
    VoidCallback? onContinue,
    VoidCallback? onCancel,
    bool submitting = false,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: OnDeviceAiDisclosureScreen(
          submitting: submitting,
          onContinue: onContinue ?? () {},
          onCancel: onCancel ?? () {},
        ),
      ),
    );
  }

  group('OnDeviceAiDisclosureScreen', () {
    testWidgets('renders the accurate callout and CTAs', (tester) async {
      await tester.pumpWidget(wrapScreen());

      expect(find.byKey(OnDeviceAiDisclosureScreen.screenKey), findsOneWidget);
      expect(find.byKey(OnDeviceAiDisclosureScreen.shieldKey), findsOneWidget);
      expect(find.text(OnDeviceAiDisclosureCopy.heading), findsOneWidget);
      expect(find.text(OnDeviceAiDisclosureCopy.body), findsOneWidget);
      expect(find.text(OnDeviceAiDisclosureCopy.understandCta), findsOneWidget);
      expect(find.text(OnDeviceAiDisclosureCopy.cancelCta), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('the continue CTA calls onContinue', (tester) async {
      var proceeded = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        wrapScreen(
          onContinue: () => proceeded++,
          onCancel: () => cancelled++,
        ),
      );

      await tester.tap(find.byKey(OnDeviceAiDisclosureScreen.continueKey));
      await tester.pump();

      expect(proceeded, 1);
      expect(cancelled, 0);
    });

    testWidgets('Cancel calls onCancel and does not continue', (tester) async {
      var proceeded = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        wrapScreen(
          onContinue: () => proceeded++,
          onCancel: () => cancelled++,
        ),
      );

      await tester.tap(find.byKey(OnDeviceAiDisclosureScreen.cancelKey));
      await tester.pump();

      expect(cancelled, 1);
      expect(proceeded, 0);
    });

    testWidgets('does not ship the banned on-device absolute', (tester) async {
      await tester.pumpWidget(wrapScreen());

      expect(find.text(_requestedFalseOnDeviceBody), findsNothing);
      expect(find.textContaining('never leaves your phone'), findsNothing);
      expect(
        find.textContaining('processes everything directly on this device'),
        findsNothing,
      );
      expect(find.textContaining('Works Fully Offline'), findsNothing);
      expect(find.textContaining('Zero Third-Party Sharing'), findsNothing);
      expect(find.textContaining('never goes to the cloud'), findsNothing);
    });

    testWidgets('headings stay visible at 800x600', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapScreen());

      expect(tester.takeException(), isNull);
      expect(find.text(OnDeviceAiDisclosureCopy.heading), findsOneWidget);
      final titleRect = tester.getRect(
        find.byKey(OnDeviceAiDisclosureScreen.titleKey),
      );
      expect(titleRect.top, greaterThanOrEqualTo(0));
      expect(titleRect.bottom, lessThanOrEqualTo(600));
    });
  });
}
