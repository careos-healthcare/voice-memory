import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_profile_card.dart';

void main() {
  testWidgets('renders Pattern profile card', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: PatternProfileCard(),
          ),
        ),
        GoRoute(
          path: '/pattern-profile',
          builder: (context, state) =>
              const Scaffold(body: Text('Profile screen')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('Pattern profile'), findsOneWidget);
    expect(find.text('See this pattern in one place.'), findsOneWidget);
    expect(find.text('Open profile'), findsOneWidget);
  });

  testWidgets('Open profile navigates to pattern profile route', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: PatternProfileCard(),
          ),
        ),
        GoRoute(
          path: '/pattern-profile',
          builder: (context, state) =>
              const Scaffold(body: Text('Profile screen')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile screen'), findsOneWidget);
  });
}
