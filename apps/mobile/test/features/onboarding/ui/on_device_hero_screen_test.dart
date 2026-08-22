import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Copy-level assertions live in on_device_hero_copy_test.dart so they stay
// runnable without the widget graph. This file covers rendering, the CTA, and
// the one thing on the screen that is read at runtime rather than written down.

void main() {
  Widget wrap({
    VoidCallback? onContinue,
    VoidCallback? onSeeDetails,
    bool submitting = false,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: OnDeviceHeroScreen(
          submitting: submitting,
          onContinue: onContinue ?? () {},
          onSeeDetails: onSeeDetails ?? () {},
        ),
      ),
    );
  }

  group('OnDeviceHeroScreen', () {
    testWidgets('renders the hero panel with all three trust badges', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());

      expect(find.byKey(OnDeviceHeroScreen.screenKey), findsOneWidget);
      expect(find.byKey(OnDeviceHeroScreen.panelKey), findsOneWidget);
      expect(find.text(OnDeviceHeroCopy.title), findsOneWidget);
      expect(find.text(OnDeviceHeroCopy.lede), findsOneWidget);

      for (var i = 1; i <= OnDeviceHeroCopy.pillars.length; i++) {
        expect(
          find.byKey(OnDeviceHeroScreen.pillarKey(i)),
          findsOneWidget,
          reason: 'pillar $i',
        );
      }
      for (final pillar in OnDeviceHeroCopy.pillars) {
        expect(find.text(pillar.title), findsOneWidget, reason: pillar.title);
        expect(find.text(pillar.body), findsOneWidget, reason: pillar.body);
      }
    });

    testWidgets('the title is a semantic header', (tester) async {
      await tester.pumpWidget(wrap());

      expect(
        tester.getSemantics(find.byKey(OnDeviceHeroScreen.titleKey)),
        matchesSemantics(isHeader: true, label: OnDeviceHeroCopy.title),
      );
    });

    testWidgets('each badge is one semantic container', (tester) async {
      await tester.pumpWidget(wrap());

      for (final pillar in OnDeviceHeroCopy.pillars) {
        expect(
          find.bySemanticsLabel('${pillar.title}. ${pillar.body}'),
          findsOneWidget,
          reason: pillar.title,
        );
      }
    });

    group('primary action', () {
      testWidgets('proceeds into the app when tapped', (tester) async {
        var proceeded = 0;
        await tester.pumpWidget(wrap(onContinue: () => proceeded++));

        expect(find.text(OnDeviceHeroCopy.continueCta), findsOneWidget);
        await tester.tap(find.byKey(OnDeviceHeroScreen.continueKey));
        await tester.pump();

        expect(proceeded, 1);
      });

      testWidgets('is disabled while completion is in flight', (tester) async {
        var proceeded = 0;
        await tester.pumpWidget(
          wrap(onContinue: () => proceeded++, submitting: true),
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

    testWidgets('the detail link opens the privacy surface', (tester) async {
      var opened = 0;
      await tester.pumpWidget(wrap(onSeeDetails: () => opened++));

      // The link sits below the badges, so scroll it up before tapping.
      await tester.ensureVisible(find.byKey(OnDeviceHeroScreen.detailLinkKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(OnDeviceHeroScreen.detailLinkKey));
      await tester.pump();

      expect(opened, 1);
      expect(find.text(OnDeviceHeroCopy.detailLink), findsOneWidget);
    });

    group('storage protection is read live, not asserted', () {
      // `SecureSqliteLockService.encryptionEnabled` is a runtime flag with an
      // "unavailable" state, so the hero must show whatever this build does.
      // Under `flutter test` the flag defaults to false.
      late bool original;

      setUp(() => original = SecureSqliteLockService.encryptionEnabled);
      tearDown(
        () => SecureSqliteLockService.encryptionEnabled = original,
      );

      testWidgets('reports the unavailable state when encryption is off', (
        tester,
      ) async {
        SecureSqliteLockService.encryptionEnabled = false;
        await tester.pumpWidget(wrap());

        expect(find.byKey(OnDeviceHeroScreen.storageStatusKey), findsOneWidget);
        expect(
          find.text(
            PrivacySecurityControlCenterCopy.encryptionInactiveLabel,
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('encryption_status_active_badge')),
          findsNothing,
        );
      });

      testWidgets('reports the active state when encryption is on', (
        tester,
      ) async {
        SecureSqliteLockService.encryptionEnabled = true;
        await tester.pumpWidget(wrap());

        expect(
          find.text(PrivacySecurityControlCenterCopy.encryptionActiveLabel),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('encryption_status_active_badge')),
          findsOneWidget,
        );
      });
    });

    for (final width in [320.0, 390.0, 834.0, 1024.0]) {
      testWidgets('does not overflow at width $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrap());

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
          child: wrap(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      // The CTA sits outside the scroll view, so it stays reachable.
      expect(find.byKey(OnDeviceHeroScreen.continueKey), findsOneWidget);
    });
  });
}
