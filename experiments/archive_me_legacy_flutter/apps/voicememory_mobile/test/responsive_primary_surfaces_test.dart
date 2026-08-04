import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/l10n/generated/app_localizations.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/onboarding/onboarding_visuals.dart';
import 'package:voicememory_mobile/screens/account_auth_screen.dart';
import 'package:voicememory_mobile/screens/onboarding_intent_screen.dart';
import 'package:voicememory_mobile/screens/onboarding_loop_screen.dart';
import 'package:voicememory_mobile/widgets/archive_search/archive_search_bar.dart';
import 'package:voicememory_mobile/widgets/main_shell.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';
import 'package:voicememory_mobile/widgets/record/record_first_run_privacy_reassurance.dart';

import 'support/ios_device_viewport.dart';

void main() {
  testWidgets(
    'pushed shell applies lateral and conditional bottom safe areas',
    (tester) async {
      const viewport = IosDeviceViewport(
        name: 'notched landscape',
        logicalSize: Size(844, 390),
        devicePixelRatio: 1,
        viewPadding: EdgeInsets.fromLTRB(47, 0, 33, 21),
      );
      applyIosDeviceViewport(tester, viewport);

      await tester.pumpWidget(
        const MaterialApp(
          home: PushedScreenShell(
            title: 'Details',
            showBottomDone: false,
            body: ColoredBox(
              key: Key('safe_body'),
              color: Colors.blue,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(const Key('safe_body')));
      expect(rect.left, 47);
      expect(rect.right, 844 - 33);
      expect(rect.bottom, 390 - 21);
    },
  );

  testWidgets('dense archive search keeps a 48 point target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ArchiveSearchBar(onChanged: (_) {})),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('archive_search_bar'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('first-run privacy link keeps a 48 point target', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RecordFirstRunPrivacyReassurance()),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const Key('record_first_run_privacy_link')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('account auth adds keyboard inset to scroll padding', (
    tester,
  ) async {
    applyIosDeviceViewport(
      tester,
      IosDeviceViewport.iPhoneSe,
      keyboardHeight: 216,
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountAuthScreen(intent: AccountAuthIntent.createAccount),
      ),
    );

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect((scroll.padding! as EdgeInsets).bottom, greaterThan(216));
  });

  testWidgets('onboarding stays usable on SE at 320 percent text', (
    tester,
  ) async {
    applyIosDeviceViewport(
      tester,
      IosDeviceViewport.iPhoneSe,
      textScale: IosDynamicType.accessibilityExtraExtraExtraLarge,
    );

    await tester.pumpWidget(const MaterialApp(home: OnboardingIntentScreen()));
    await tester.pump();

    expect(find.byKey(const Key('onboarding_intent_skip')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: OnboardingLoopScreen()));
    await tester.pump();

    expect(find.byKey(const Key('onboarding_loop_start_cta')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decorative onboarding network compacts under large text', (
    tester,
  ) async {
    applyIosDeviceViewport(
      tester,
      IosDeviceViewport.iPhoneSe,
      textScale: IosDynamicType.accessibilityExtraExtraExtraLarge,
    );
    final networkPage = OnboardingPages.pages.firstWhere(
      (page) => page.visual == OnboardingVisualKind.patternNetwork,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OnboardingPageVisual(page: networkPage)),
      ),
    );

    expect(tester.getSize(find.byType(OnboardingPageVisual)).height, 96);
  });

  testWidgets(
    'main navigation labels remain discoverable at narrow large text',
    (tester) async {
      applyIosDeviceViewport(
        tester,
        IosDeviceViewport.iPhoneSe,
        textScale: IosDynamicType.accessibilityExtraExtraExtraLarge,
      );
      final router = GoRouter(
        initialLocation: '/record',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                MainShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/record', builder: (_, _) => const SizedBox()),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/archive-belief',
                    builder: (_, _) => const SizedBox(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/belief-changes',
                    builder: (_, _) => const SizedBox(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/account',
                    builder: (_, _) => const SizedBox(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Changes'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.bySemanticsLabel('Primary navigation'), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(find.byKey(const Key('radial_action_menu')), findsNothing);
    },
  );
}
