import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/screens/onboarding_screen.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';

Future<void> _resetServices() async {
  final stamp = DateTime.now().microsecondsSinceEpoch.toString();
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_layout_journal_$stamp.json',
    prefsPath: '/tmp/vm_layout_prefs_$stamp.json',
  );
}

void main() {
  setUp(() async {
    await _resetServices();
  });

  Future<void> pumpAtSize(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  group('patterns empty', () {
    for (final size in const [
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 800),
    ]) {
      testWidgets('renders without overflow at ${size.width.toInt()}w', (
        tester,
      ) async {
        await pumpAtSize(
          tester,
          size,
          const PatternsEmptyView(fillViewport: false),
        );
        expect(
          find.text(ConsumerUiCopy.patternsEmptyPageTitle),
          findsOneWidget,
        );
      });
    }
  });

  group('paywall', () {
    for (final size in const [
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 800),
    ]) {
      testWidgets(
        'fallback renders without overflow at ${size.width.toInt()}w',
        (tester) async {
          await pumpAtSize(tester, size, const PaywallScreen());
          expect(find.text('ArchiveMe Pro'), findsWidgets);
        },
      );
    }
  });

  group('account', () {
    testWidgets('renders without overflow on phone', (tester) async {
      await pumpAtSize(tester, const Size(390, 844), const AccountScreen());
      expect(find.text(ConsumerUiCopy.accountTitle), findsOneWidget);
    });

    testWidgets('renders without overflow on iPad width', (tester) async {
      await pumpAtSize(tester, const Size(820, 1180), const AccountScreen());
      expect(find.text(ConsumerUiCopy.accountTitle), findsOneWidget);
    });
  });

  group('settings', () {
    for (final size in const [
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 800),
    ]) {
      testWidgets('renders without overflow at ${size.width.toInt()}w', (
        tester,
      ) async {
        await pumpAtSize(tester, size, const SettingsScreen());
        expect(find.text(ConsumerUiCopy.settings), findsOneWidget);
      });
    }
  });

  group('onboarding', () {
    testWidgets('renders without overflow on iPad width', (tester) async {
      await pumpAtSize(tester, const Size(820, 1180), const OnboardingScreen());
      expect(find.text('ArchiveMe'), findsOneWidget);
      expect(find.text(OnboardingPages.pages[0].title), findsOneWidget);
    });
  });
}
