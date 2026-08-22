import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_copy.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_entry_point.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onSetUpAccess,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: ListView(
            children: [CaregiverEntryPoint(onSetUpAccess: onSetUpAccess)],
          ),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(() => CaregiverFeatureFlags.debugOverride = null);

  group('CaregiverEntryPoint', () {
    testWidgets('renders nothing while the caregiver flag is off', (
      tester,
    ) async {
      CaregiverFeatureFlags.debugOverride = false;
      await _pump(tester);

      expect(find.byKey(CaregiverEntryPoint.cardKey), findsNothing);
      expect(find.text(CaregiverGrantCopy.entryTitle), findsNothing);
    });

    testWidgets('defaults to off without an override', (tester) async {
      await _pump(tester);

      expect(find.byKey(CaregiverEntryPoint.cardKey), findsNothing);
    });

    testWidgets('renders title, subtitle, and action when enabled', (
      tester,
    ) async {
      CaregiverFeatureFlags.debugOverride = true;
      await _pump(tester);

      expect(find.byKey(CaregiverEntryPoint.cardKey), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.entryTitle), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.entrySubtitle), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.entryAction), findsOneWidget);
    });

    testWidgets('the action opens the flow', (tester) async {
      CaregiverFeatureFlags.debugOverride = true;
      var opened = 0;
      await _pump(tester, onSetUpAccess: () => opened += 1);

      await tester.tap(find.byKey(CaregiverEntryPoint.actionKey));
      await tester.pump();

      expect(opened, 1);
    });

    testWidgets('the action keeps a 48dp tap target', (tester) async {
      CaregiverFeatureFlags.debugOverride = true;
      await _pump(tester);

      final size = tester.getSize(find.byKey(CaregiverEntryPoint.actionKey));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('the title is a header node, separate from the subtitle', (
      tester,
    ) async {
      CaregiverFeatureFlags.debugOverride = true;
      final handle = tester.ensureSemantics();
      await _pump(tester);

      // Separate nodes matter here: a merged card node would make a screen
      // reader announce the subtitle as part of the heading.
      expect(
        tester.getSemantics(find.text(CaregiverGrantCopy.entryTitle)),
        matchesSemantics(label: CaregiverGrantCopy.entryTitle, isHeader: true),
      );
      expect(
        tester.getSemantics(find.text(CaregiverGrantCopy.entrySubtitle)),
        matchesSemantics(label: CaregiverGrantCopy.entrySubtitle),
      );
      handle.dispose();
    });

    testWidgets('does not overflow at 3x text scale', (tester) async {
      CaregiverFeatureFlags.debugOverride = true;
      tester.view.physicalSize = const Size(360 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, textScale: 3);

      expect(tester.takeException(), isNull);
      expect(find.byKey(CaregiverEntryPoint.cardKey), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.entryAction), findsOneWidget);
    });
  });
}
