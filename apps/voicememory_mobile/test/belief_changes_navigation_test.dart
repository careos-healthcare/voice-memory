import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/belief_changes_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/consumer/consumer_screen_back_header.dart';

void main() {
  testWidgets('BeliefChangesScreen shows back control and title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BeliefChangesScreen(
          previewTimeline: ScreenshotSampleData.changingStories,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ConsumerScreenBackHeader), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.text(ConsumerUiCopy.changesScreenTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.changesScreenLead), findsOneWidget);
  });

  testWidgets('/belief-changes route exposes back button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/belief-changes',
      routes: [
        GoRoute(
          path: '/archive-belief',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('patterns-home'))),
        ),
        GoRoute(
          path: '/belief-changes',
          builder: (context, state) => BeliefChangesScreen(
            previewTimeline: ScreenshotSampleData.changingStories,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.text(ConsumerUiCopy.changesScreenTitle), findsOneWidget);
  });
}
