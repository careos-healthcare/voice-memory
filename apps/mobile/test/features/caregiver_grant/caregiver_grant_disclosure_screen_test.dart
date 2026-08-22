import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_copy.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_disclosure_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onCancel,
  VoidCallback? onContinue,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: CaregiverDisclosureScreen(
          onCancel: onCancel,
          onContinue: onContinue,
        ),
      ),
    ),
  );
}

void main() {
  group('CaregiverDisclosureScreen', () {
    testWidgets('renders every section heading', (tester) async {
      // The body is a lazy ListView, so the last section is off-screen at the
      // 800x600 default. A tall viewport asserts on content, not on scroll.
      tester.view.physicalSize = const Size(400 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester);

      expect(find.text(CaregiverGrantCopy.canSeeHeading), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.cannotHeading), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.stopHeading), findsOneWidget);
    });

    testWidgets('renders what a caregiver can and cannot see', (tester) async {
      tester.view.physicalSize = const Size(400 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester);

      for (final bullet in [
        ...CaregiverGrantCopy.canSee,
        ...CaregiverGrantCopy.cannot,
      ]) {
        expect(find.text(bullet), findsOneWidget, reason: bullet);
      }
    });

    testWidgets('says the limits are how the screens are built', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester);

      expect(find.text(CaregiverGrantCopy.cannotCaveat), findsOneWidget);
    });

    testWidgets('says turning access off reaches the server too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester);

      expect(find.text(CaregiverGrantCopy.stopReachesServer), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.stopEndEarly), findsOneWidget);
    });

    testWidgets('Cancel is present and visible without scrolling', (
      tester,
    ) async {
      await _pump(tester);

      final cancel = find.byKey(CaregiverDisclosureScreen.cancelKey);
      expect(cancel, findsOneWidget);
      expect(find.text(CaregiverGrantCopy.disclosureCancel), findsWidgets);

      final rect = tester.getRect(cancel);
      final screen = tester.getSize(find.byType(MaterialApp));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(screen.height));
      expect(rect.height, greaterThanOrEqualTo(48));
    });

    testWidgets('Cancel invokes the cancel callback', (tester) async {
      var cancelled = 0;
      await _pump(tester, onCancel: () => cancelled += 1);

      await tester.tap(find.byKey(CaregiverDisclosureScreen.cancelKey));
      await tester.pump();

      expect(cancelled, 1);
    });

    testWidgets('the app bar back button also cancels', (tester) async {
      var cancelled = 0;
      await _pump(tester, onCancel: () => cancelled += 1);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(cancelled, 1);
    });

    testWidgets('the primary action advances', (tester) async {
      var advanced = 0;
      await _pump(tester, onContinue: () => advanced += 1);

      await tester.tap(find.byKey(CaregiverDisclosureScreen.continueKey));
      await tester.pump();

      expect(advanced, 1);
    });

    testWidgets('Cancel stays visible and tappable at 3x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var cancelled = 0;
      await _pump(tester, onCancel: () => cancelled += 1, textScale: 3);

      expect(tester.takeException(), isNull);

      final cancel = find.byKey(CaregiverDisclosureScreen.cancelKey);
      expect(cancel, findsOneWidget);
      expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));

      await tester.tap(cancel);
      await tester.pump();
      expect(cancelled, 1);
    });
  });
}
