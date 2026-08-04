import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/router/route_catalog.dart';
import 'package:voicememory_mobile/screens/onboarding_screen.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 3}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

GoRouter _onboardingRouter({
  required Future<void> Function() persistCompletion,
}) {
  return GoRouter(
    initialLocation: RouteCatalog.onboarding,
    routes: [
      GoRoute(
        path: RouteCatalog.onboarding,
        builder: (context, state) => OnboardingScreen(
          persistCompletion: persistCompletion,
          onCaptureSelected: (destination) => context.go(destination),
        ),
      ),
      GoRoute(
        path: RouteCatalog.recordHome,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('VOICE_CAPTURE_MARKER'))),
      ),
      GoRoute(
        path: RouteCatalog.quickTextCapture,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('TEXT_CAPTURE_MARKER'))),
      ),
    ],
  );
}

void main() {
  testWidgets('shows exactly one promise screen with two capture choices', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('onboarding_promise_screen')), findsOneWidget);
    expect(find.text(OnboardingPages.pages.single.title), findsOneWidget);
    expect(find.text('Record a moment'), findsOneWidget);
    expect(find.text('Type instead'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('Record persists completion and enters voice capture', (
    tester,
  ) async {
    var persisted = false;
    final router = _onboardingRouter(
      persistCompletion: () async => persisted = true,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('onboarding_primary_cta')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await _pumpFrames(tester, frames: 12);

    expect(persisted, isTrue);
    expect(onboardingGate.complete, isTrue);
    expect(find.text('VOICE_CAPTURE_MARKER'), findsOneWidget);
    expect(find.textContaining('cold-start'), findsNothing);
    expect(find.textContaining('Memory Graph'), findsNothing);
  });

  testWidgets(
    'Type persists completion and enters existing text capture route',
    (tester) async {
      var persisted = false;
      final router = _onboardingRouter(
        persistCompletion: () async => persisted = true,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpFrames(tester);

      await tester.tap(find.byKey(const Key('onboarding_type_instead_cta')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await _pumpFrames(tester, frames: 12);

      expect(persisted, isTrue);
      expect(find.text('TEXT_CAPTURE_MARKER'), findsOneWidget);
    },
  );

  test('onboarding completion does not activate proveEnough', () {
    final source = File(
      'lib/screens/onboarding_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('LoopModeCoordinator.activate')));
    expect(source, isNot(contains('LoopModeIds.proveEnough')));
  });

  testWidgets('back does not reveal a legacy onboarding step', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await _pumpFrames(tester);

    await tester.binding.handlePopRoute();
    await _pumpFrames(tester);

    expect(find.byKey(const Key('onboarding_promise_screen')), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  for (final configuration in <({Size size, double textScale})>[
    (size: const Size(320, 568), textScale: 1),
    (size: const Size(390, 844), textScale: 1),
    (size: const Size(390, 844), textScale: 2),
  ]) {
    testWidgets(
      'promise layout fits ${configuration.size} at ${configuration.textScale}x text',
      (tester) async {
        tester.view.physicalSize = configuration.size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue =
            configuration.textScale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
        await _pumpFrames(tester);

        expect(find.text(OnboardingPages.primaryAction), findsOneWidget);
        expect(find.text(OnboardingPages.secondaryAction), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
