import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/insights/archive_insight.dart';
import 'package:voicememory_mobile/features/monetization/domain/services/monetization_analytics.dart';
import 'package:voicememory_mobile/features/pattern_recognition/pattern_recognition_dashboard_provider.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/pattern_recognition_dashboard_screen.dart';
import 'package:voicememory_mobile/widgets/value_moment_paywall.dart';

class _RecordingAnalytics implements AnalyticsEngine {
  final events = <String>[];

  @override
  void logEvent(String name, {Map<String, Object>? parameters}) {
    events.add(name);
  }
}

final _entry = JournalEntry(
  id: 'entry-1',
  createdAt: DateTime(2026, 7, 25),
  transcript: 'I protected quiet time before agreeing to another meeting.',
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['boundaries'],
    exactLanguagePattern: '',
    concreteObservation: 'You protected quiet time.',
    repeatedSignal: '',
  ),
);

class _FakeDashboardController extends PatternRecognitionDashboardController {
  @override
  Future<PatternRecognitionDashboardState> build() async =>
      PatternRecognitionDashboardState(
        entries: [_entry],
        insights: ArchiveInsightsSnapshot.empty,
        recurringTopics: const [RecurringTopic(label: 'boundaries', count: 3)],
        moodTrends: const [
          MoodTrend(mood: 'calm', count: 2, averageIntensity: 2),
        ],
        loadedFromLocalFallback: false,
        isPro: true,
      );
}

class _FreeDashboardController extends PatternRecognitionDashboardController {
  @override
  Future<PatternRecognitionDashboardState> build() async =>
      PatternRecognitionDashboardState(
        entries: [_entry],
        insights: ArchiveInsightsSnapshot.empty,
        recurringTopics: const [RecurringTopic(label: 'boundaries', count: 3)],
        moodTrends: const [],
        loadedFromLocalFallback: false,
      );
}

class _BackendRestrictedDashboardController
    extends PatternRecognitionDashboardController {
  @override
  Future<PatternRecognitionDashboardState> build() async =>
      PatternRecognitionDashboardState(
        entries: [_entry],
        insights: ArchiveInsightsSnapshot.empty,
        recurringTopics: const [],
        moodTrends: const [],
        loadedFromLocalFallback: false,
        backendRestricted: true,
      );
}

void main() {
  testWidgets('renders insight cards and opens synchronized memory playback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patternRecognitionDashboardProvider.overrideWith(
            _FakeDashboardController.new,
          ),
        ],
        child: const MaterialApp(home: PatternRecognitionDashboard()),
      ),
    );
    await tester.pump();

    expect(find.text('Recurring topics'), findsOneWidget);
    expect(find.text('boundaries · 3'), findsOneWidget);
    expect(find.text('Mood trends'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('AI-driven insights'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pattern_memory_entry-1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('pattern_memory_entry-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pattern_memory_entry-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rich_memory_playback')), findsOneWidget);
    expect(
      find.text('I protected quiet time before agreeing to another meeting.'),
      findsNWidgets(2),
    );
  });

  testWidgets('free users see insight and playback Pro boundaries', (
    tester,
  ) async {
    final analytics = _RecordingAnalytics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patternRecognitionDashboardProvider.overrideWith(
            _FreeDashboardController.new,
          ),
        ],
        child: MaterialApp(
          home: PatternRecognitionDashboard(analytics: analytics),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('value_moment_paywall_premiumInsights')),
      findsOneWidget,
    );
    final insightPaywall = tester.widget<ValueMomentPaywall>(
      find.byType(ValueMomentPaywall).first,
    );
    insightPaywall.onUpgradeTapped?.call();
    expect(analytics.events, contains('insight_upgrade_cta_clicked'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('pattern_memory_entry-1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('pattern_memory_entry-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('value_moment_paywall_fullHistory')),
      findsNothing,
    );
    expect(find.byKey(const Key('rich_memory_playback')), findsOneWidget);
  });

  testWidgets('Pro safe area at 3.2x keeps insight upgrade reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const media = MediaQueryData(
      size: Size(430, 932),
      padding: EdgeInsets.only(top: 59, bottom: 34),
      textScaler: TextScaler.linear(3.2),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patternRecognitionDashboardProvider.overrideWith(
            _FreeDashboardController.new,
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(data: media, child: child!),
          home: const PatternRecognitionDashboard(),
        ),
      ),
    );
    await tester.pump();

    final paywall = find.byKey(
      const Key('value_moment_paywall_premiumInsights'),
    );
    await tester.scrollUntilVisible(
      paywall,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(paywall, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing backend shows local-vault availability banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patternRecognitionDashboardProvider.overrideWith(
            _BackendRestrictedDashboardController.new,
          ),
        ],
        child: const MaterialApp(home: PatternRecognitionDashboard()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('pattern_dashboard_backend_restricted')),
      findsOneWidget,
    );
    expect(find.text('Cloud features are limited'), findsOneWidget);
    expect(
      find.textContaining('Local vault recording remains available.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('pattern_memory_entry-1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('pattern_memory_entry-1')), findsOneWidget);
  });
}
