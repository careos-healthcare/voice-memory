import 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_explanation.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_ai_explanation_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/onboarding_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapDisclosure({
    VoidCallback? onContinue,
    VoidCallback? onCancel,
    VoidCallback? onSeeDetails,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: OnDeviceAiDisclosure(
          onContinue: onContinue ?? () {},
          onCancel: onCancel ?? () {},
          onSeeDetails: onSeeDetails ?? () {},
        ),
      ),
    );
  }

  group('OnDeviceAiDisclosure', () {
    test('OnDeviceAiExplanation remains a typedef of OnDeviceAiDisclosure', () {
      final alias = OnDeviceAiDisclosure(
        onContinue: () {},
        onCancel: () {},
      );
      expect(alias, isA<OnDeviceAiDisclosure>());
    });

    testWidgets('builds OnDeviceAiDisclosureScreen', (tester) async {
      await tester.pumpWidget(wrapDisclosure());

      expect(find.byKey(OnDeviceAiDisclosure.screenKey), findsOneWidget);
      expect(find.byKey(OnDeviceAiExplanation.explanationKey), findsOneWidget);
      expect(find.byKey(OnDeviceAiDisclosureScreen.screenKey), findsOneWidget);
      expect(find.text(OnDeviceAiDisclosureCopy.heading), findsOneWidget);
      expect(find.text(OnDeviceAiDisclosureCopy.body), findsOneWidget);
    });

    testWidgets('the continue CTA proceeds into the app', (tester) async {
      var proceeded = 0;
      await tester.pumpWidget(wrapDisclosure(onContinue: () => proceeded++));

      await tester.tap(find.byKey(OnDeviceAiDisclosureScreen.continueKey));
      await tester.pump();

      expect(proceeded, 1);
    });

    testWidgets('Cancel returns without continuing', (tester) async {
      var proceeded = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        wrapDisclosure(
          onContinue: () => proceeded++,
          onCancel: () => cancelled++,
        ),
      );

      await tester.tap(find.byKey(OnDeviceAiDisclosureScreen.cancelKey));
      await tester.pump();

      expect(cancelled, 1);
      expect(proceeded, 0);
    });

    testWidgets('headings stay visible at 800x600', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapDisclosure());

      expect(tester.takeException(), isNull);
      expect(find.byKey(OnDeviceAiDisclosureScreen.titleKey), findsOneWidget);
      expect(find.text(OnDeviceAiDisclosureCopy.heading), findsOneWidget);
      final titleRect = tester.getRect(
        find.byKey(OnDeviceAiDisclosureScreen.titleKey),
      );
      expect(titleRect.top, greaterThanOrEqualTo(0));
      expect(titleRect.bottom, lessThanOrEqualTo(600));
    });
  });

  group('onboarding inserts the disclosure before the dashboard', () {
    testWidgets('the first page is OnDeviceAiDisclosure, not the welcome page', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump();

      expect(find.byKey(OnDeviceAiDisclosure.screenKey), findsOneWidget);
      expect(find.byKey(OnDeviceAiDisclosureScreen.screenKey), findsOneWidget);
      expect(find.byKey(const Key('onboarding_page_view')), findsNothing);
      expect(find.text(ConsumerUiCopy.onboardingContinueCta), findsNothing);
      expect(find.text(OnDeviceAiDisclosureCopy.understandCta), findsOneWidget);
      expect(find.text(OnDeviceHeroCopy.continueCta), findsNothing);
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

      expect(find.byKey(OnDeviceAiDisclosure.screenKey), findsNothing);
      expect(find.byKey(const Key('onboarding_page_view')), findsOneWidget);
    });

    testWidgets('Continue on the first page advances to welcome, not /record', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump();

      await tester.tap(find.byKey(OnDeviceAiDisclosureScreen.continueKey));
      await tester.pump();

      expect(find.byKey(OnDeviceAiDisclosureScreen.screenKey), findsNothing);
      expect(find.byKey(const Key('onboarding_page_view')), findsOneWidget);
      expect(find.text(ConsumerUiCopy.onboardingContinueCta), findsOneWidget);
    });
  });
}
