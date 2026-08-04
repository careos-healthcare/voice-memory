import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/activation/first_three_journey_engine.dart';
import 'package:voicememory_mobile/features/activation/first_three_journey_coordinator.dart';
import 'package:voicememory_mobile/features/first_session/first_session_coordinator.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/activation/first_three_journey_card.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_come_back_tomorrow_card.dart';
import 'package:voicememory_mobile/widgets/patterns/return_streak_card.dart';
import 'package:voicememory_mobile/widgets/patterns/weekly_pattern_recap_card.dart';

bool _visibleContainsBanned(String visible, String word) {
  if (word == 'archive') {
    return RegExp(r'\barchive\b(?!me)', caseSensitive: false).hasMatch(visible);
  }
  return visible.contains(word);
}

const _bannedVisible = <String>[
  'voicememory',
  'belief',
  'intelligence',
  'evidence',
  'signal',
  'prediction',
  'contradiction',
  'discovery',
  'engine',
  'analysis',
];

String _visibleText(WidgetTester tester) {
  return find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .join('\n')
      .toLowerCase();
}

void main() {
  testWidgets('incomplete CTA routes to /record', (tester) async {
    final model = const FirstThreeJourneyEngine().build(reflectionCount: 0);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  Scaffold(body: FirstThreeJourneyCard(model: model)),
            ),
            GoRoute(
              path: '/record',
              builder: (_, _) => const Scaffold(body: Text('record tab')),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text(model.nextAction));
    await tester.pumpAndSettle();
    expect(find.text('record tab'), findsOneWidget);
  });

  testWidgets('complete CTA routes to /archive-belief', (tester) async {
    final model = const FirstThreeJourneyEngine().build(reflectionCount: 3);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  Scaffold(body: FirstThreeJourneyCard(model: model)),
            ),
            GoRoute(
              path: '/archive-belief',
              builder: (_, _) => const Scaffold(body: Text('patterns tab')),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('View archive'));
    await tester.pumpAndSettle();
    expect(find.text('patterns tab'), findsOneWidget);
  });

  testWidgets('card renders without banned words', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final count in [0, 1, 2, 3]) {
      final model = ScreenshotSampleData.firstThreeJourneyForCount(count);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: FirstThreeJourneyCard(model: model)),
        ),
      );
      await tester.pump();
      final visible = _visibleText(tester);
      for (final word in _bannedVisible) {
        expect(
          _visibleContainsBanned(visible, word),
          isFalse,
          reason: 'count=$count found $word',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('screenshot sample provides each journey step', () {
    for (var step = 0; step <= 3; step++) {
      final m = ScreenshotSampleData.firstThreeJourneyForCount(step);
      if (step < 3) {
        expect(m.completed, isFalse);
        expect(m.completedSteps, step);
      } else {
        expect(m.completed, isTrue);
        expect(m.completedSteps, 3);
      }
    }
  });

  test('shouldShowMinimalPatterns when fewer than 3 reflections', () {
    expect(
      FirstSessionCoordinator.shouldShowMinimalPatterns(
        reflectionCount: 2,
        comparison: null,
        streak: null,
        watchCompleted: null,
        changeSummary: null,
        weeklyRecap: null,
      ),
      isTrue,
    );
    expect(
      FirstSessionCoordinator.shouldShowMinimalPatterns(
        reflectionCount: 3,
        comparison: null,
        streak: null,
        watchCompleted: null,
        changeSummary: null,
        weeklyRecap: null,
      ),
      isFalse,
    );
  });

  test('coordinator hides advanced retention before 3 reflections', () {
    expect(FirstThreeJourneyCoordinator.shouldHideAdvancedRetention(0), isTrue);
    expect(FirstThreeJourneyCoordinator.shouldHideAdvancedRetention(2), isTrue);
    expect(
      FirstThreeJourneyCoordinator.shouldHideAdvancedRetention(3),
      isFalse,
    );
  });

  testWidgets('first-three patterns stack omits streak and weekly recap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final journey = const FirstThreeJourneyEngine().build(reflectionCount: 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              FirstThreeJourneyCard(model: journey),
              const PatternsComeBackTomorrowCard(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ReturnStreakCard), findsNothing);
    expect(find.byType(WeeklyPatternRecapCard), findsNothing);
    expect(find.text(journey.title), findsOneWidget);
  });
}
