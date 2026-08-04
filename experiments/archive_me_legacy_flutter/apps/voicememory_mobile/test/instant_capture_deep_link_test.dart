import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/screens/low_effort_yes_capture_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  group('instant capture deep links', () {
    test('maps two-slash widget and watch URLs to capture routes', () {
      expect(
        resolveInstantCaptureDeepLink(Uri.parse('archiveme://quick-capture')),
        '/quick-yes-capture?instant=1',
      );
      expect(
        resolveInstantCaptureDeepLink(Uri.parse('archiveme://voice-session')),
        '/record?instant=1',
      );
    });

    test('accepts path-form URLs and preserves safe query parameters', () {
      expect(
        resolveInstantCaptureDeepLink(
          Uri.parse('archiveme:///quick-capture?source=lock-screen'),
        ),
        '/quick-yes-capture?source=lock-screen&instant=1',
      );
      expect(
        resolveInstantCaptureDeepLink(Uri.parse('https://quick-capture')),
        isNull,
      );
      expect(
        resolveInstantCaptureDeepLink(Uri.parse('archiveme://unknown')),
        isNull,
      );
    });

    test('resolved targets are registered in the application router', () {
      expect(
        appRouter.configuration
            .findMatch(Uri.parse('/quick-yes-capture?instant=1'))
            .isError,
        isFalse,
      );
      expect(
        appRouter.configuration
            .findMatch(Uri.parse('/record?instant=1'))
            .isError,
        isFalse,
      );
    });
  });

  testWidgets('GoRouter normalizes a custom-scheme cold start', (tester) async {
    final router = GoRouter(
      initialLocation: 'archiveme://quick-capture',
      overridePlatformDefaultLocation: true,
      redirect: (context, state) => resolveInstantCaptureDeepLink(state.uri),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/quick-yes-capture',
          builder: (context, state) => const Text('instant quick capture'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('instant quick capture'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/quick-yes-capture?instant=1',
    );
  });

  testWidgets(
    'instant quick capture renders without asynchronous cohort loading',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const LowEffortYesCaptureScreen(instantMode: true),
        ),
      );

      expect(
        find.byKey(const Key('low_effort_yes_capture_screen')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byKey(const Key('low_effort_yes_capture_save_button')),
        findsOneWidget,
      );
    },
  );
}
