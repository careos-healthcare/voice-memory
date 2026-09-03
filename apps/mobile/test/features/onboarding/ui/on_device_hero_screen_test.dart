import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap({
    required bool allowedRemote,
    VoidCallback? onContinue,
    bool submitting = false,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: OnDeviceHeroScreen(
          allowedRemote: allowedRemote,
          submitting: submitting,
          onContinue: onContinue ?? () {},
        ),
      ),
    );
  }

  group('OnDeviceHeroScreen', () {
    testWidgets('confirms an allow decision and nothing else', (tester) async {
      await tester.pumpWidget(wrap(allowedRemote: true));

      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsOneWidget);
      expect(find.byKey(OnDeviceHeroScreen.panelKey), findsOneWidget);
      expect(find.text(OnDeviceHeroCopy.allowedTitle), findsOneWidget);
      expect(find.text(OnDeviceHeroCopy.allowedBody), findsOneWidget);
      expect(find.text(OnDeviceHeroCopy.declinedTitle), findsNothing);
      expect(find.byKey(const Key('encryption_status_card')), findsNothing);
    });

    testWidgets('confirms a decline decision and nothing else', (tester) async {
      await tester.pumpWidget(wrap(allowedRemote: false));

      expect(find.text(OnDeviceHeroCopy.declinedTitle), findsOneWidget);
      expect(find.text(OnDeviceHeroCopy.declinedBody), findsOneWidget);
      expect(find.text(OnDeviceHeroCopy.allowedTitle), findsNothing);
    });

    testWidgets('the title is a semantic header', (tester) async {
      await tester.pumpWidget(wrap(allowedRemote: true));

      expect(
        tester.getSemantics(find.byKey(OnDeviceHeroScreen.titleKey)),
        matchesSemantics(isHeader: true, label: OnDeviceHeroCopy.allowedTitle),
      );
    });

    group('primary action', () {
      testWidgets('proceeds into the app when tapped', (tester) async {
        var proceeded = 0;
        await tester.pumpWidget(
          wrap(allowedRemote: false, onContinue: () => proceeded++),
        );

        expect(find.text(OnDeviceHeroCopy.continueCta), findsOneWidget);
        await tester.tap(find.byKey(OnDeviceHeroScreen.continueKey));
        await tester.pump();

        expect(proceeded, 1);
      });

      testWidgets('is disabled while completion is in flight', (tester) async {
        var proceeded = 0;
        await tester.pumpWidget(
          wrap(
            allowedRemote: true,
            onContinue: () => proceeded++,
            submitting: true,
          ),
        );

        await tester.tap(
          find.byKey(OnDeviceHeroScreen.continueKey),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(proceeded, 0);
        final button = tester.widget<FilledButton>(
          find.byKey(OnDeviceHeroScreen.continueKey),
        );
        expect(button.onPressed, isNull);
      });
    });

    for (final width in [320.0, 390.0, 834.0, 1024.0]) {
      testWidgets('does not overflow at width $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrap(allowedRemote: true));

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('scrolls rather than overflowing at 2x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: wrap(allowedRemote: true),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byKey(OnDeviceHeroScreen.continueKey), findsOneWidget);
    });
  });
}
