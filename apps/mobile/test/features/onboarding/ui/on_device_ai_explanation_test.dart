import 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_explanation.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_explanation_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/onboarding_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapExplanation({
    VoidCallback? onContinue,
    VoidCallback? onCancel,
    VoidCallback? onSeeDetails,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: OnDeviceAiExplanation(
          onContinue: onContinue ?? () {},
          onCancel: onCancel ?? () {},
          onSeeDetails: onSeeDetails ?? () {},
        ),
      ),
    );
  }

  group('OnDeviceAiExplanation', () {
    testWidgets('is a named alias of the disclosure screen', (
      tester,
    ) async {
      await tester.pumpWidget(wrapExplanation());

      expect(find.byKey(OnDeviceAiExplanation.screenKey), findsOneWidget);
      expect(find.byKey(OnDeviceAiDisclosure.screenKey), findsOneWidget);
      expect(find.byKey(OnDeviceAiDisclosureScreen.screenKey), findsOneWidget);
      expect(find.text(OnDeviceAiExplanationCopy.heading), findsOneWidget);
      expect(find.text(OnDeviceAiExplanationCopy.body), findsOneWidget);
    });

    testWidgets('the continue CTA proceeds into the app', (tester) async {
      var proceeded = 0;
      await tester.pumpWidget(wrapExplanation(onContinue: () => proceeded++));

      await tester.tap(find.byKey(OnDeviceAiDisclosureScreen.continueKey));
      await tester.pump();

      expect(proceeded, 1);
    });

    testWidgets('headings stay visible at 800x600', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapExplanation());

      expect(tester.takeException(), isNull);
      expect(find.byKey(OnDeviceAiDisclosureScreen.titleKey), findsOneWidget);
      expect(find.text(OnDeviceAiExplanationCopy.heading), findsOneWidget);
      final titleRect = tester.getRect(
        find.byKey(OnDeviceAiDisclosureScreen.titleKey),
      );
      expect(titleRect.top, greaterThanOrEqualTo(0));
      expect(titleRect.bottom, lessThanOrEqualTo(600));
    });
  });

  group('onboarding inserts the explanation before the dashboard', () {
    testWidgets('the first page is OnDeviceAiExplanation, not the welcome page', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump();

      expect(find.byKey(OnDeviceAiExplanation.screenKey), findsOneWidget);
      expect(find.byKey(OnDeviceAiDisclosureScreen.screenKey), findsOneWidget);
      expect(find.byKey(const Key('onboarding_page_view')), findsNothing);
      expect(find.text(ConsumerUiCopy.onboardingContinueCta), findsNothing);
      expect(find.text(OnDeviceAiExplanationCopy.understandCta), findsOneWidget);
    });

    testWidgets('the welcome step is after Continue, not first', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen(debugStartAtWelcome: true)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byKey(OnDeviceAiExplanation.screenKey), findsNothing);
      expect(find.byKey(const Key('onboarding_page_view')), findsOneWidget);
    });
  });
}
