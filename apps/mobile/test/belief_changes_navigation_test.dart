import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/features/belief_changes/screens/belief_changes_screen.dart';
import 'package:archiveme_mobile/features/archive/screens/belief_detail_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/consumer/consumer_screen_back_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('BeliefDetailScreen back pops to patterns home', (tester) async {
    const belief = ArchiveBeliefCardModel(
      id: 'belief-nav',
      statement: 'Work pressure keeps showing up before you agree.',
      confidencePercent: 72,
      evidenceSummary: 'Appeared in 3 reflections.',
      whyExplanation:
          'ArchiveMe noticed this topic repeating across months of reflections.',
      section: ArchiveBeliefSection.hiddenPattern,
    );

    final router = GoRouter(
      initialLocation: '/archive-belief',
      routes: [
        GoRoute(
          path: '/archive-belief',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('patterns-home'))),
        ),
        GoRoute(
          path: '/belief-detail',
          builder: (context, state) => BeliefDetailScreen(
            belief: state.extra! as ArchiveBeliefCardModel,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump();
    router.push('/belief-detail', extra: belief);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(belief.statement), findsOneWidget);
    await tester.tap(find.byKey(const Key('consumer_screen_back_header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('patterns-home'), findsOneWidget);
    expect(find.text(belief.statement), findsNothing);
  });
}