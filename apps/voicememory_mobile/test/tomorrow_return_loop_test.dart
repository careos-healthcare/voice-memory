import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/archive_explanations/explanation_models.dart';
import 'package:voicememory_mobile/features/daily_discoveries/daily_discovery_models.dart';
import 'package:voicememory_mobile/features/discover/discover_local.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_return_loop_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_return_loop_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_come_back_tomorrow_card.dart';
import 'package:voicememory_mobile/widgets/potential_signals_card.dart';
import 'package:voicememory_mobile/widgets/record/tomorrow_return_card.dart';

bool _visibleContainsBanned(String visible, String word) {
  if (word == 'archive') {
    return RegExp(r'\barchive\b(?!me)', caseSensitive: false).hasMatch(visible);
  }
  return visible.contains(word);
}

const _bannedVisible = <String>[
  'voicememory',
  'archive',
  'belief',
  'beliefs',
  'intelligence',
  'evidence',
  'discover',
  'discovery',
  'signal',
  'signals',
  'analyst',
  'historian',
  'theory',
  'contradiction',
  'prediction',
];

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
  List<String> themes = const ['work'],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — enough spoken detail for pattern detection here.',
    durationSeconds: 40,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 4,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: line,
    ),
  );
}

void main() {
  test('engine fills all three return-loop answers', () {
    final now = DateTime(2026, 5, 12, 14);
    final entries = [
      _entry(
        id: '1',
        at: now.subtract(const Duration(days: 3)),
        line: 'Work pressure keeps building on my shoulders',
        themes: const ['work'],
      ),
      _entry(
        id: '2',
        at: now.subtract(const Duration(days: 1)),
        line: 'I avoid asking for help until exhausted',
        themes: const ['work'],
      ),
      _entry(
        id: '3',
        at: now,
        line: 'I feel guilty when I slow down today',
        themes: const ['work', 'family'],
      ),
    ];

    final feed = DiscoverLocalFeed(
      hasBaseline: true,
      totalChanges: 1,
      strengthened: const [
        DiscoverChangeItem(
          title: 'work',
          detail: 'May be showing up more often since your last visit.',
          kind: 'strengthened',
        ),
      ],
      weakened: const [],
      newItems: const [],
      evidenceMovements: const [],
    );

    final loop = const TomorrowReturnLoopEngine().build(
      entries: entries,
      discoverFeed: feed,
      now: now,
    );

    expect(loop.hasContent, isTrue);
    expect(loop.noticedToday, isNotEmpty);
    expect(loop.comeBackTomorrow, isNotEmpty);
    expect(loop.watchForNextTime, isNotEmpty);
    expect(loop.watchForChips, isNotEmpty);
    expect(loop.tomorrowPrompt, ConsumerUiCopy.tomorrowNoticePrompt);
  });

  test('immediate discovery shapes noticed today', () {
    final now = DateTime(2026, 5, 12, 10);
    final discovery = DailyDiscovery(
      id: 'd1',
      type: DailyDiscoveryType.themeSpike,
      title: 'Work mentions increased',
      summary: 'You spoke about work more than last week.',
      whyItMatters: 'Themes can shift quickly early on.',
      evidenceIds: const ['e1'],
      confidence: 0.8,
      createdAt: now,
      insightRef: ArchiveInsightRef.theme('work'),
    );

    final loop = const TomorrowReturnLoopEngine().build(
      entries: [
        _entry(
          id: 'e1',
          at: now,
          line: 'Career stress reflection today',
        ),
      ],
      immediateDiscovery: discovery,
      now: now,
    );

    expect(loop.noticedToday, contains('Work mentions increased'));
    expect(loop.comeBackTomorrow, isNotEmpty);
    expect(loop.watchForNextTime, isNotEmpty);
  });

  test('store round-trips loop json with chips', () async {
    final dir = await Directory.systemTemp.createTemp('vm_loop_test');
    final store = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final loopStore = TomorrowReturnLoopStore(store);

    final loop = TomorrowReturnLoop(
      noticedToday: 'You named pressure again today.',
      comeBackTomorrow: 'Check Patterns tomorrow after another moment.',
      watchForNextTime: 'Whether guilt when you slow down returns.',
      generatedAt: DateTime(2026, 5, 12),
      watchForChips: const ['feeling responsible', 'doing it alone'],
      tomorrowPrompt: ConsumerUiCopy.tomorrowNoticePrompt,
    );

    await loopStore.write(loop);
    final read = await loopStore.read();

    expect(read?.noticedToday, loop.noticedToday);
    expect(read?.watchForChips, loop.watchForChips);
    expect(read?.tomorrowPrompt, loop.tomorrowPrompt);
  });

  test('screenshot sample return-loop data is available', () {
    expect(
      ScreenshotSampleData.returnLoopTodayNoticed,
      contains('responsibility'),
    );
    expect(ScreenshotSampleData.returnLoopWatchChips.length, 3);
    expect(
      ScreenshotSampleData.returnLoopTomorrowPrompt,
      contains('Tomorrow'),
    );
    final loop = ScreenshotSampleData.tomorrowReturnLoop;
    expect(loop.displayWatchChips, ScreenshotSampleData.returnLoopWatchChips);
  });

  testWidgets('post-save noticed card renders consumer copy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PotentialSignalsCard(
            signals: const [],
            noticedToday: ScreenshotSampleData.returnLoopTodayNoticed,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(ConsumerUiCopy.todayArchiveMeNoticed), findsOneWidget);
    expect(
      find.text(ScreenshotSampleData.returnLoopTodayNoticed),
      findsOneWidget,
    );
  });

  testWidgets('TomorrowReturnCard renders without exceptions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TomorrowReturnCard(
            loop: ScreenshotSampleData.tomorrowReturnLoop,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text(ConsumerUiCopy.oneMoreReflectionMakesClearer),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.viewPatternsCta), findsOneWidget);
    expect(find.text(ConsumerUiCopy.postSaveRecordAnother), findsOneWidget);
    expect(find.text(ConsumerUiCopy.comeBackTomorrowLabel), findsNothing);
    expect(find.text(ConsumerUiCopy.nextTimeWatchFor), findsNothing);
  });

  test('displayWatchChips returns theme chips only without filler', () {
    final sparse = TomorrowReturnLoop(
      noticedToday: 'A moment saved.',
      comeBackTomorrow: 'Come back tomorrow.',
      watchForNextTime: 'Watch your tone.',
      generatedAt: DateTime(2026, 5, 12),
    );
    expect(sparse.displayWatchChips, isEmpty);

    final withChips = TomorrowReturnLoop(
      noticedToday: 'A moment saved.',
      comeBackTomorrow: 'Come back tomorrow.',
      watchForNextTime: 'Watch your tone.',
      generatedAt: DateTime(2026, 5, 12),
      watchForChips: const ['feeling responsible', 'doing it alone'],
    );
    expect(withChips.displayWatchChips, hasLength(2));
  });

  testWidgets('TomorrowReturnCard visible strings avoid banned jargon',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TomorrowReturnCard(
            loop: ScreenshotSampleData.tomorrowReturnLoop,
          ),
        ),
      ),
    );
    await tester.pump();

    final elements = find.byType(Text).evaluate();
    final visible = elements
        .map((e) => (e.widget as Text).data ?? '')
        .join('\n')
        .toLowerCase();

    for (final word in _bannedVisible) {
      expect(
        _visibleContainsBanned(visible, word),
        isFalse,
        reason: 'TomorrowReturnCard should not show "$word"',
      );
    }
  });

  testWidgets('Patterns home includes Why come back tomorrow?', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: PatternsComeBackTomorrowCard(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(ConsumerUiCopy.patternsComeBackTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.patternsComeBackBody), findsOneWidget);
  });

  testWidgets('TomorrowReturnCard CTA routes to Patterns', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/record',
      routes: [
        GoRoute(
          path: '/record',
          builder: (context, state) => Scaffold(
            body: TomorrowReturnCard(
              loop: ScreenshotSampleData.tomorrowReturnLoop,
            ),
          ),
        ),
        GoRoute(
          path: '/archive-belief',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('patterns-tab')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
    await tester.pump();

    await tester.tap(find.text(ConsumerUiCopy.viewPatternsCta));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('patterns-tab'), findsOneWidget);
  });

  testWidgets('Patterns come-back CTA routes to Record', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/archive-belief',
      routes: [
        GoRoute(
          path: '/archive-belief',
          builder: (context, state) => const Scaffold(
            body: PatternsComeBackTomorrowCard(),
          ),
        ),
        GoRoute(
          path: '/record',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('record-tab')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
    await tester.pump();

    await tester.tap(find.text(ConsumerUiCopy.patternsComeBackRecordCta));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('record-tab'), findsOneWidget);
  });
}
