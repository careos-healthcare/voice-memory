import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/archive_evidence_map.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/security/app_privacy_shell.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';

void main() {
  testWidgets('AppPrivacyShell does not throw without GoRouter above it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppPrivacyShell(
          child: Text('launch body', key: Key('launch_body')),
        ),
      ),
    );

    expect(find.byKey(const Key('launch_body')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppPrivacyShell uses router location when GoRouter is present', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/record',
      routes: [
        GoRoute(
          path: '/record',
          builder: (context, state) => const AppPrivacyShell(
            child: Text('record tab', key: Key('record_tab')),
          ),
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AppPrivacyShell(
            child: Text('about tab', key: Key('about_tab')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record_tab')), findsOneWidget);
    expect(tester.takeException(), isNull);

    router.go('/about');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about_tab')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppPrivacyShell survives MaterialApp.router builder context', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/record',
      routes: [
        GoRoute(
          path: '/record',
          builder: (context, state) => const Scaffold(
            body: Text('record route', key: Key('record_route')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            AppPrivacyShell(child: child ?? const SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record_route')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows privacy overlay when route is sensitive and inactive', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SensitiveScreenGuard(
          routeIsSensitive: true,
          child: const Text('secret reflection', key: Key('secret_body')),
        ),
      ),
    );

    expect(find.byKey(const Key('secret_body')), findsOneWidget);
    expect(
      find.byKey(const Key('sensitive_screen_privacy_overlay')),
      findsNothing,
    );

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(
      find.byKey(const Key('sensitive_screen_privacy_overlay')),
      findsOneWidget,
    );
  });

  testWidgets('hides overlay again on resume', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SensitiveScreenGuard(
          hideInAppSwitcher: true,
          child: const Text('archive'),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(
      find.byKey(const Key('sensitive_screen_privacy_overlay')),
      findsOneWidget,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      find.byKey(const Key('sensitive_screen_privacy_overlay')),
      findsNothing,
    );
  });

  test('SensitiveRoutes flags private screens', () {
    expect(SensitiveRoutes.isSensitiveRoute('/entry/abc'), isTrue);
    expect(SensitiveRoutes.isSensitiveRoute('/record'), isTrue);
    expect(SensitiveRoutes.isSensitiveRoute('/export'), isTrue);
    expect(SensitiveRoutes.isSensitiveRoute('/insight-quality'), isTrue);
    expect(
      SensitiveRoutes.isSensitiveRoute(
        ArchiveEvidenceMapNavigation.contextPath(CaptureContextTagIds.work),
      ),
      isTrue,
    );
    expect(SensitiveRoutes.isSensitiveRoute('/about'), isFalse);
  });
}
