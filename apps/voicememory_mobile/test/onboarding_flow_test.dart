import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/product/loop_mode_copy.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/screens/onboarding_intent_screen.dart';
import 'package:voicememory_mobile/screens/onboarding_loop_screen.dart';
import 'package:voicememory_mobile/screens/onboarding_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_onboarding_flow_journal_$stamp.json',
    prefsPath: '/tmp/vm_onboarding_flow_prefs_$stamp.json',
  );
  onboardingGate.resetSessionRedirectsForTest();
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 3}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

GoRouter _onboardingRouter() {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/onboarding-intent',
        builder: (context, state) => const OnboardingIntentScreen(),
      ),
      GoRoute(
        path: '/onboarding-loop',
        builder: (context, state) => const OnboardingLoopScreen(),
      ),
      GoRoute(
        path: '/record',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Record screen')),
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('onboarding page 2 does not overflow on iPhone SE size',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
    await _pumpFrames(tester, frames: 5);

    expect(
      find.text(OnboardingPages.pages[1].title),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('onboarding_primary_cta')), findsOneWidget);
  });

  testWidgets('onboarding final CTA routes to intent screen', (tester) async {
    final router = _onboardingRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _pumpFrames(tester);

    for (var i = 0; i < OnboardingPages.pageCount - 1; i++) {
      await tester.tap(find.text(ConsumerUiCopy.onboardingContinueCta));
      await _pumpFrames(tester, frames: 5);
    }

    await tester.tap(find.text(ConsumerUiCopy.onboardingFinalCta));
    await _pumpFrames(tester, frames: 5);

    expect(
      find.text(ConsumerUiCopy.acquisitionIntentQuestion),
      findsOneWidget,
    );
  });

  testWidgets('loop screen start CTA stores prove_enough and routes to record',
      (tester) async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final router = _onboardingRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/onboarding-loop');
    await _pumpFrames(tester, frames: 5);

    final startButton = find.byKey(const Key('onboarding_loop_start_cta'));
    expect(startButton, findsOneWidget);
    expect(tester.widget<FilledButton>(startButton).onPressed, isNotNull);

    await tester.tap(startButton);
    await _pumpFrames(tester, frames: 10);

    expect(find.text('Record screen'), findsOneWidget);
    final active = await LoopModeCoordinator.loadActive();
    expect(active?.id, LoopModeIds.proveEnough);
  });

  testWidgets('loop skip routes safely with prove_enough default', (tester) async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final router = _onboardingRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/onboarding-loop');
    await _pumpFrames(tester, frames: 5);

    await tester.tap(find.byKey(const Key('onboarding_loop_skip')));
    await _pumpFrames(tester, frames: 10);

    expect(find.text('Record screen'), findsOneWidget);
  });

  testWidgets('intent skip routes to loop screen with working start CTA',
      (tester) async {
    final router = _onboardingRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/onboarding-intent');
    await _pumpFrames(tester, frames: 5);

    await tester.tap(find.byKey(const Key('onboarding_intent_skip')));
    await _pumpFrames(tester, frames: 5);

    expect(find.text(LoopModeCopy.onboardingTitle), findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.byKey(const Key('onboarding_loop_start_cta')),
      ).onPressed,
      isNotNull,
    );
  });
}
