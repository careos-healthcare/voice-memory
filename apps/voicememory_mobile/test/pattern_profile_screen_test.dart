import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:voicememory_mobile/features/archive_memory/memory_quality_model.dart';
import 'package:voicememory_mobile/features/pattern_profile/pattern_profile_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/pattern_profile_screen.dart';

PatternProfile _profile() => PatternProfile(
      patternTitle: 'Pressure before yes',
      clarityLabel: 'Clear pattern',
      archiveMemorySummary: const ArchiveMemorySummary(
        id: 's1',
        patternTitle: 'Pressure before yes',
        primaryMemoryLine: 'You often say yes before checking in.',
        basedOnMomentCount: 4,
        basedOnWeekCount: 2,
        clarityLabel: 'Clear pattern',
        nextCheck: 'What happened right before you said yes?',
      ),
      patternMap: const PatternMap(
        patternTitle: 'Pressure before yes',
        seenCount: 4,
        confidenceLabel: 'Clear pattern',
        oftenFeelsLike: 'heavier',
        getsLighterWhen: 'Pausing before replying',
        nextCheck: 'Map check',
      ),
      archiveEvolutionTimeline: ArchiveEvolutionTimeline(
        patternTitle: 'Pressure before yes',
        events: [
          ArchiveEvolutionEvent(
            id: 'e1',
            date: DateTime(2026, 6, 1),
            type: ArchiveEvolutionEventType.showedAgain,
            title: 'Showed up again',
            body: 'It showed up before a work message.',
          ),
        ],
        eventCount: 1,
      ),
      keyMoments: [
        KeyMoment(
          id: 'm1',
          date: DateTime(2026, 6, 2),
          title: 'A heavier moment',
          originalText: 'text',
          shortSummary: 'text',
          patternTitle: 'Pressure before yes',
        ),
      ],
      nextCheck: 'What happened right before you said yes?',
    );

Future<void> _pump(
  WidgetTester tester, {
  PatternProfile? profile,
  Future<void> Function(String nextCheck, String patternTitle)? onUseCheck,
  Future<MemoryQuality> Function()? qualityLoader,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => PatternProfileScreen(
          loader: () async => profile,
          qualityLoader: qualityLoader,
          onUseCheck: onUseCheck,
        ),
      ),
      GoRoute(
        path: '/archive-timeline',
        builder: (context, state) =>
            const Scaffold(body: Text('Timeline screen')),
      ),
      GoRoute(
        path: '/moments',
        builder: (context, state) => const Scaffold(body: Text('Moments screen')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;
  await tester.drag(scrollable, const Offset(0, -800));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders all preview sections', (tester) async {
    await _pump(tester, profile: _profile());

    expect(find.text('Pattern profile'), findsOneWidget);
    expect(find.text('Pressure before yes'), findsOneWidget);
    expect(find.text('Clear pattern'), findsOneWidget);
    expect(find.text('What ArchiveMe remembers'), findsOneWidget);
    expect(find.text('Pattern map'), findsOneWidget);
    expect(find.text('Pattern timeline'), findsOneWidget);
    expect(find.text('Key moments'), findsOneWidget);

    await _scrollToBottom(tester);

    expect(find.text('Next check'), findsOneWidget);
    expect(find.text('Use this check'), findsOneWidget);
    expect(find.text('Open timeline'), findsOneWidget);
    expect(find.text('Find related moments'), findsOneWidget);
  });

  testWidgets('shows quality chip without duplicate clarity label',
      (tester) async {
    await _pump(
      tester,
      profile: _profile(),
      qualityLoader: () async => const MemoryQuality(
        level: MemoryQualityLevel.gettingClearer,
        label: 'Getting clearer',
        helperText: 'This pattern is starting to repeat across days.',
        momentCount: 4,
        checkInCount: 4,
        weekCount: 2,
        hasChangedRecently: false,
      ),
    );

    expect(find.text('Getting clearer'), findsOneWidget);
    expect(find.text('Clear pattern'), findsNothing);
  });

  testWidgets('empty state when no profile', (tester) async {
    await _pump(tester, profile: null);

    expect(
      find.text(
        'Record a few moments and ArchiveMe will build this pattern.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Use this check fires callback', (tester) async {
    String? usedCheck;
    await _pump(
      tester,
      profile: _profile(),
      onUseCheck: (check, title) async {
        usedCheck = check;
      },
    );
    await _scrollToBottom(tester);

    await tester.tap(find.text('Use this check'));
    await tester.pumpAndSettle();

    expect(usedCheck, 'What happened right before you said yes?');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.resultNextCheckConfirmation),
      findsWidgets,
    );
  });

  testWidgets('Find related moments navigates', (tester) async {
    await _pump(tester, profile: _profile());
    await _scrollToBottom(tester);

    await tester.tap(find.text('Find related moments'));
    await tester.pumpAndSettle();

    expect(find.text('Moments screen'), findsOneWidget);
  });

  testWidgets('Open timeline navigates', (tester) async {
    await _pump(tester, profile: _profile());
    await _scrollToBottom(tester);

    await tester.tap(find.text('Open timeline'));
    await tester.pumpAndSettle();

    expect(find.text('Timeline screen'), findsOneWidget);
  });

  testWidgets('shows feedback once at the bottom', (tester) async {
    await _pump(tester, profile: _profile());
    await _scrollToBottom(tester);

    expect(find.text('Was this useful?'), findsOneWidget);
    expect(find.text('Too generic'), findsOneWidget);
  });

  testWidgets('hides feedback when showFeedback is false', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => PatternProfileScreen(
            loader: () async => _profile(),
            showFeedback: false,
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(find.text('Was this useful?'), findsNothing);
  });
}
