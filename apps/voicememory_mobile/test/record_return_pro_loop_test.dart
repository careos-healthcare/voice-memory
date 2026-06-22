import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/journal_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/onboarding/change_starts_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_archive_value_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/pro_archive_continuity_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/record_once_intro_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/tomorrow_return_cue_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/record_return_pro/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

JournalEntry _entry({String id = 'e1', DateTime? createdAt}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 11, 12),
    transcript: 'A long enough transcript to count as a saved reflection.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
  );
}

const _bannedWords = [
  'always',
  'never',
  'proves',
  'definitely',
  'diagnosis',
  'diagnose',
  'therapy',
  'treatment',
  'fixed',
  'broken',
  'problem',
  'failure',
  'lazy',
  'weak',
  'must',
  'should',
  'surveillance',
  'spying',
  'tracking',
  'unlock premium',
];

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<({String event, Map<String, Object> properties})> eventsNamed(
    String name,
  ) => captured.where((e) => e.event == name).toList();

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('Copy guardrails', () {
    test('record once copy is exact', () {
      expect(RecordReturnProCopy.recordOnceCta, 'Record one moment');
      expect(
        RecordReturnProCopy.recordOnceSupporting,
        'ArchiveMe helps you notice what keeps repeating in your own words.',
      );
    });

    test('first save evidence card copy is exact', () {
      expect(RecordReturnProCopy.evidenceTitle, 'Your archive has started.');
      expect(
        RecordReturnProCopy.evidenceBody,
        contains('first piece of evidence'),
      );
      expect(
        RecordReturnProCopy.evidenceSecondLine,
        contains('No conclusion yet'),
      );
      expect(
        RecordReturnProCopy.evidenceThirdLine,
        contains('No conclusion yet'),
      );
      expect(RecordReturnProCopy.evidenceViewArchive, 'View archive');
      expect(RecordReturnProCopy.evidenceRecordAnother, 'Record another');
    });

    test('return cue copy is exact', () {
      expect(RecordReturnProCopy.returnTitle, 'Return tomorrow');
      expect(
        RecordReturnProCopy.returnBody,
        contains('No conclusion yet'),
      );
      expect(
        RecordReturnProCopy.returnLocalCta,
        'I\u2019ll come back tomorrow',
      );
      expect(RecordReturnProCopy.returnRemindCta, 'Remind me tomorrow');
    });

    test('change can begin copy is exact', () {
      expect(RecordReturnProCopy.changeTitle, 'Now change can begin to show');
      expect(
        RecordReturnProCopy.changeBody,
        'With more than one entry, ArchiveMe can start comparing what feels '
        'new, repeated, or quieter.',
      );
    });

    test('Pro bridge copy is exact', () {
      expect(
        RecordReturnProCopy.proTitle,
        'Keep your archive useful over time.',
      );
      expect(
        RecordReturnProCopy.proBody,
        'See deeper history and saved evidence.',
      );
      expect(
        RecordReturnProCopy.proContinuityLine,
        'Free keeps today\u2019s save. Pro keeps the thread connected over time.',
      );
      expect(RecordReturnProCopy.proCta, 'See Pro');
      expect(RecordReturnProCopy.proSecondary, 'Not now');
    });

    test('first save does not claim a pattern', () {
      final copy = RecordReturnProCopy.all.join(' ').toLowerCase();
      expect(copy, isNot(contains('we found a pattern')));
      expect(copy, isNot(contains('pattern found')));
      expect(copy, isNot(contains('your pattern is')));
      expect(copy, isNot(contains('the archive found')));
    });

    test('no VoiceMemory or banned words', () {
      final copy = RecordReturnProCopy.all.join(' ').toLowerCase();
      expect(copy, isNot(contains('voicememory')));
      for (final banned in _bannedWords) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'copy contains banned "$banned"',
        );
      }
    });
  });

  group('Visibility gates', () {
    test('record once intro only at zero entries', () {
      expect(RecordReturnProGates.showRecordOnceIntro(entryCount: 0), isTrue);
      expect(RecordReturnProGates.showRecordOnceIntro(entryCount: 1), isFalse);
    });

    test('change can begin only with two entries and no real insight', () {
      expect(
        RecordReturnProGates.showChangeCanBegin(
          entryCount: 2,
          changeStartSeen: false,
          hasRealChangeInsight: false,
        ),
        isTrue,
      );
      expect(
        RecordReturnProGates.showChangeCanBegin(
          entryCount: 2,
          changeStartSeen: false,
          hasRealChangeInsight: true,
        ),
        isFalse,
      );
      expect(
        RecordReturnProGates.showChangeCanBegin(
          entryCount: 2,
          changeStartSeen: true,
          hasRealChangeInsight: false,
        ),
        isFalse,
      );
      expect(
        RecordReturnProGates.showChangeCanBegin(
          entryCount: 1,
          changeStartSeen: false,
          hasRealChangeInsight: false,
        ),
        isFalse,
      );
    });

    test('real insight suppresses generic change card', () {
      expect(
        RecordReturnProGates.hasRealChangeInsight(
          hasReturnComparison: true,
          hasTomorrowReturnLoopContent: false,
          hasThreadReturnEvidence: false,
        ),
        isTrue,
      );
      expect(
        RecordReturnProGates.hasRealChangeInsight(
          hasReturnComparison: false,
          hasTomorrowReturnLoopContent: true,
          hasThreadReturnEvidence: false,
        ),
        isTrue,
      );
      expect(
        RecordReturnProGates.hasRealChangeInsight(
          hasReturnComparison: false,
          hasTomorrowReturnLoopContent: false,
          hasThreadReturnEvidence: true,
        ),
        isTrue,
      );
    });

    test('Pro bridge never at zero entries and not for Pro users', () {
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 0,
          resolved: false,
          isPro: false,
        ),
        isFalse,
      );
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 1,
          resolved: false,
          isPro: true,
        ),
        isFalse,
      );
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
        ),
        isFalse,
      );
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
        ),
        isTrue,
      );
    });
  });

  group('Widgets', () {
    testWidgets('zero-entry user sees Record one moment CTA', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: RecordOnceIntroCard(onRecord: () {})),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('record_once_intro_card')), findsOneWidget);
      expect(find.text('Record one moment'), findsOneWidget);
      expect(
        find.text(
          'ArchiveMe helps you notice what keeps repeating in your own words.',
        ),
        findsOneWidget,
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.recordReturnLoopStarted),
        isNotEmpty,
      );
    });

    testWidgets('first save shows Saved as evidence card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () {},
              onRecordAnother: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Your archive has started.'), findsOneWidget);
      expect(
        find.textContaining('first piece of evidence'),
        findsOneWidget,
      );
      expect(find.textContaining('No conclusion yet'), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstSaveEvidenceSeen),
        isNotEmpty,
      );
    });

    testWidgets('View archive routes to patterns tab', (tester) async {
      final router = GoRouter(
        initialLocation: '/record',
        routes: [
          GoRoute(
            path: '/record',
            builder: (context, state) => Scaffold(
              body: FirstSaveEvidenceCard(
                onViewArchive: () => context.go('/archive-belief'),
                onRecordAnother: () {},
              ),
            ),
          ),
          GoRoute(
            path: '/archive-belief',
            builder: (context, state) =>
                const Scaffold(body: Text('PATTERNS_TAB')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('first_save_view_archive_cta')));
      await tester.pumpAndSettle();

      expect(find.text('PATTERNS_TAB'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/archive-belief');
    });

    testWidgets('first save card does not claim pattern or change', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () {},
              onRecordAnother: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .join(' ')
          .toLowerCase();
      expect(text, isNot(contains('pattern')));
      expect(text, isNot(contains('changed')));
      expect(text, isNot(contains('returned')));
      expect(text, isNot(contains('faded')));
    });

    testWidgets('return tomorrow cue appears with exact copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TomorrowReturnCueCard(
              reminderAvailable: false,
              onLocalCue: () {},
              onRemind: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Return tomorrow'), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.returnTomorrowSeen),
        isNotEmpty,
      );
    });

    testWidgets('return cue local path does not call onRemind', (tester) async {
      var reminded = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TomorrowReturnCueCard(
              reminderAvailable: false,
              onLocalCue: () {},
              onRemind: () => reminded = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('tomorrow_return_local_cta')));
      await tester.pump();
      expect(reminded, isFalse);
      expect(
        eventsNamed(ActivationFunnelAnalytics.returnTomorrowAccepted),
        isNotEmpty,
      );
    });

    testWidgets('change can begin card renders when built', (tester) async {
      var seen = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ChangeStartsCard(
              entryCount: 2,
              onViewArchive: () {},
              onSearchArchive: () {},
              onSeen: () => seen = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Now change can begin to show'), findsOneWidget);
      expect(seen, isTrue);
      expect(
        eventsNamed(ActivationFunnelAnalytics.changeCanBeginSeen),
        isNotEmpty,
      );
    });

    testWidgets('Pro bridge copy is exact', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProArchiveContinuityCard(
              entryCount: 1,
              source: 'record',
              onSeePro: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Keep your archive useful over time.'), findsOneWidget);
      expect(
        find.text('See deeper history and saved evidence.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Free keeps today\u2019s save. Pro keeps the thread connected over time.',
        ),
        findsOneWidget,
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.proArchiveContinuitySeen),
        isNotEmpty,
      );
    });
  });

  group('Persistence', () {
    test('card state persists and avoids repeated spam', () async {
      final prefs = _MemoryPrefs();
      final store = RecordReturnProStore(prefs: prefs);

      await store.markProBridgeResolved();
      await store.markChangeStartSeen();
      await store.markReturnCueResolved(
        RecordReturnProReturnCueMethod.localCue,
      );

      final loaded = await store.load();
      expect(loaded.proBridgeResolved, isTrue);
      expect(loaded.changeStartSeen, isTrue);
      expect(loaded.returnCueResolved, isTrue);
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 1,
          resolved: loaded.proBridgeResolved,
          isPro: false,
        ),
        isFalse,
      );
    });
  });

  group('Analytics privacy', () {
    testWidgets('analytics payload contains no private content', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () {},
              onRecordAnother: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('first_save_view_archive_cta')));
      await tester.pump();

      for (final e in captured) {
        final payload = '${e.event} ${e.properties}'.toLowerCase();
        expect(payload, isNot(contains('transcript')));
        expect(payload, isNot(contains('concreteobservation')));
        for (final banned in _bannedWords) {
          expect(payload, isNot(contains(banned)));
        }
      }
    });
  });
}
