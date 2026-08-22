import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_section.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Statement-level assertions live in on_device_architecture_copy_test.dart,
// which imports only the copy constants so it stays runnable independently of
// the widget graph.

void main() {
  group('OnDeviceArchitectureSection', () {
    Widget wrap({required bool onboarding, Size? size}) {
      final section = OnDeviceArchitectureSection(
        useOnboardingTypography: onboarding,
      );
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: size == null
                ? section
                : SizedBox(width: size.width, child: section),
          ),
        ),
      );
    }

    const blocks = [
      OnDeviceArchitectureCopy.architectureHeading,
      OnDeviceArchitectureCopy.architectureBody,
      OnDeviceArchitectureCopy.storageBody,
      OnDeviceArchitectureCopy.remoteHeading,
      OnDeviceArchitectureCopy.remoteCallout,
      OnDeviceArchitectureCopy.analyticsBody,
      OnDeviceArchitectureCopy.ownershipHeading,
      OnDeviceArchitectureCopy.ownershipBody,
      OnDeviceArchitectureCopy.ownershipControls,
    ];

    for (final onboarding in [false, true]) {
      final label = onboarding ? 'onboarding' : 'settings';
      testWidgets('shows every block under its heading ($label)', (
        tester,
      ) async {
        await tester.pumpWidget(wrap(onboarding: onboarding));

        expect(
          find.byKey(OnDeviceArchitectureSection.sectionKey),
          findsOneWidget,
        );
        for (final block in blocks) {
          expect(find.text(block), findsOneWidget, reason: block);
        }
      });
    }

    testWidgets('the opt-in qualifier gets the accent callout', (tester) async {
      await tester.pumpWidget(wrap(onboarding: false));

      final callout = find.byKey(OnDeviceArchitectureSection.remoteCalloutKey);
      expect(callout, findsOneWidget);
      expect(
        find.descendant(
          of: callout,
          matching: find.text(OnDeviceArchitectureCopy.remoteCallout),
        ),
        findsOneWidget,
      );
    });

    testWidgets('every heading exposes header semantics', (tester) async {
      await tester.pumpWidget(wrap(onboarding: false));

      for (final heading in const [
        OnDeviceArchitectureCopy.architectureHeading,
        OnDeviceArchitectureCopy.remoteHeading,
        OnDeviceArchitectureCopy.ownershipHeading,
      ]) {
        expect(
          tester.getSemantics(find.text(heading)),
          matchesSemantics(isHeader: true, label: heading),
          reason: heading,
        );
      }
    });

    for (final width in [320.0, 390.0, 834.0, 1024.0]) {
      testWidgets('does not overflow at width $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrap(onboarding: false));

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('long text scrolls rather than overflowing at 2x scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: wrap(onboarding: true),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
