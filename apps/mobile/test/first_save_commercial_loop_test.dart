import 'dart:io';

import 'package:archiveme_mobile/features/first_session/two_day_activation_engine.dart';
import 'package:archiveme_mobile/features/onboarding/first_save_loop_state.dart';
import 'package:archiveme_mobile/features/onboarding/first_save_loop_store.dart';
import 'package:archiveme_mobile/features/retention/repeat_recording_nudge_state.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/onboarding/day2_change_bridge_card.dart';
import 'package:archiveme_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:archiveme_mobile/widgets/onboarding/pro_archive_continuity_bridge.dart';
import 'package:archiveme_mobile/widgets/onboarding/tomorrow_return_cue_card.dart';
import 'package:archiveme_research/screens/journal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/first_save_loop/unused.json'));

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
    test('first save evidence card copy is exact', () {
      expect(
        FirstSaveLoopCopy.evidenceTitle,
        RecordReturnProCopy.evidenceTitle,
      );
      expect(FirstSaveLoopCopy.evidenceBody, RecordReturnProCopy.evidenceBody);
      expect(
        FirstSaveLoopCopy.evidenceSecondLine,
        RecordReturnProCopy.evidenceSecondLine,
      );
      expect(
        FirstSaveLoopCopy.evidenceViewArchive,
        RecordReturnProCopy.evidenceViewArchive,
      );
      expect(
        FirstSaveLoopCopy.evidenceRecordAnother,
        RecordReturnProCopy.evidenceRecordAnother,
      );
    });

    test('return cue copy is exact', () {
      expect(FirstSaveLoopCopy.returnTitle, RecordReturnProCopy.returnTitle);
      expect(FirstSaveLoopCopy.returnBody, RecordReturnProCopy.returnBody);
      expect(
        FirstSaveLoopCopy.returnLocalCta,
        RecordReturnProCopy.returnLocalCta,
      );
      expect(
        FirstSaveLoopCopy.returnRemindCta,
        RecordReturnProCopy.returnRemindCta,
      );
    });

    test('archive value card copy is exact', () {
      expect(FirstSaveLoopCopy.archiveTitle, 'Your archive has started');
      expect(
        FirstSaveLoopCopy.archiveBody,
        'Search it, pin what matters, or return tomorrow to compare what '
        'changed.',
      );
    });

    test('Pro bridge copy is exact', () {
      expect(FirstSaveLoopCopy.proTitle, RecordReturnProCopy.proTitle);
      expect(FirstSaveLoopCopy.proBody, RecordReturnProCopy.proBody);
      expect(FirstSaveLoopCopy.proCta, RecordReturnProCopy.proCta);
      expect(FirstSaveLoopCopy.proSecondary, RecordReturnProCopy.proSecondary);
    });

    test('Day 2 bridge copy is exact', () {
      expect(
        RepeatRecordingNudgeCopy.day2Title,
        'This is where the archive starts working',
      );
      expect(
        RepeatRecordingNudgeCopy.day2Body,
        'Record today and ArchiveMe can begin comparing what feels new, '
        'repeated, or quieter.',
      );
      expect(RepeatRecordingNudgeCopy.day2Cta, 'Record today');
    });

    test('first save does not claim a pattern', () {
      final copy = FirstSaveLoopCopy.all.join(' ').toLowerCase();
      expect(copy, isNot(contains('we found a pattern')));
      expect(copy, isNot(contains('pattern found')));
      expect(copy, isNot(contains('your pattern is')));
      expect(copy, isNot(contains('the archive found')));
    });

    test('no VoiceMemory or banned words', () {
      final copy = FirstSaveLoopCopy.all.join(' ').toLowerCase();
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
    test('Day 2 bridge only with one entry on day-two return stage', () {
      expect(
        FirstSaveLoopGates.showDay2Bridge(
          entryCount: 1,
          stage: TwoDayActivationStage.dayTwoReturn,
          hasRealChangeInsight: false,
        ),
        isTrue,
      );
      expect(
        FirstSaveLoopGates.showDay2Bridge(
          entryCount: 1,
          stage: TwoDayActivationStage.dayOneIntro,
          hasRealChangeInsight: false,
        ),
        isFalse,
      );
      expect(
        FirstSaveLoopGates.showDay2Bridge(
          entryCount: 2,
          stage: TwoDayActivationStage.dayTwoReturn,
          hasRealChangeInsight: false,
        ),
        isFalse,
      );
    });

    test('archive value card only for exactly one entry', () {
      expect(FirstSaveLoopGates.showArchiveValue(entryCount: 0), isFalse);
      expect(FirstSaveLoopGates.showArchiveValue(entryCount: 1), isTrue);
      expect(FirstSaveLoopGates.showArchiveValue(entryCount: 2), isFalse);
    });

    test('Pro bridge not before repeat value', () {
      expect(
        FirstSaveLoopGates.showProBridge(
          entryCount: 0,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
      expect(
        FirstSaveLoopGates.showProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
      expect(
        FirstSaveLoopGates.showProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
          hasArchiveProof: false,
        ),
        isFalse,
      );
      expect(
        FirstSaveLoopGates.showProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isTrue,
      );
      expect(
        FirstSaveLoopGates.showProBridge(
          entryCount: 2,
          resolved: true,
          isPro: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
    });
  });

  group('Evidence card widget', () {
    testWidgets('actions fire analytics and callbacks', (tester) async {
      var viewed = false;
      var recorded = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () => viewed = true,
              onRecordAnother: () => recorded = true,
              onDoneForToday: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstSaveEvidenceSeen),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('first_save_view_archive_cta')));
      await tester.pump();
      expect(viewed, isTrue);
      expect(
        eventsNamed(
          ActivationFunnelAnalytics.firstSaveEvidenceViewArchiveTapped,
        ),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('first_save_record_another_cta')));
      await tester.pump();
      expect(recorded, isTrue);
    });

    testWidgets('View archive opens patterns tab not journal route', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/record',
        routes: [
          GoRoute(
            path: '/record',
            builder: (context, state) => Scaffold(
              body: FirstSaveEvidenceCard(
                onViewArchive: () => context.go('/archive-belief'),
                onRecordAnother: () {},
                onDoneForToday: () {},
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
  });

  group('Return cue widget', () {
    testWidgets('reminder CTA only when infrastructure exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TomorrowReturnCueCard(
              reminderAvailable: true,
              onLocalCue: () {},
              onRemind: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('tomorrow_return_remind_cta')),
        findsOneWidget,
      );
      expect(find.text(RecordReturnProCopy.returnLocalCta), findsOneWidget);
    });

    testWidgets('rendering alone never calls onRemind', (tester) async {
      var reminded = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TomorrowReturnCueCard(
              reminderAvailable: true,
              onLocalCue: () {},
              onRemind: () => reminded = true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(reminded, isFalse);
    });
  });

  group('Pro bridge widget', () {
    testWidgets('See Pro and Not now fire events', (tester) async {
      var seePro = false;
      var notNow = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProArchiveContinuityBridge(
              entryCount: 1,
              source: 'record',
              onSeePro: () => seePro = true,
              onNotNow: () => notNow = true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        eventsNamed(ActivationFunnelAnalytics.proArchiveContinuitySeen),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('pro_archive_continuity_see_pro')));
      await tester.pump();
      expect(seePro, isTrue);

      await tester.tap(find.byKey(const Key('pro_archive_continuity_not_now')));
      await tester.pump();
      expect(notNow, isTrue);
    });
  });

  group('Day 2 bridge widget', () {
    testWidgets('does not claim comparison already happened', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: Day2ChangeBridgeCard(onRecord: () {})),
        ),
      );
      await tester.pump();
      expect(find.text(RepeatRecordingNudgeCopy.day2Body), findsOneWidget);
      expect(find.textContaining('already changed'), findsNothing);
      expect(find.textContaining('found a pattern'), findsNothing);
    });
  });

  testWidgets('Pro bridge gate is false at zero entries', (tester) async {
    expect(
      FirstSaveLoopGates.showProBridge(
        entryCount: 0,
        resolved: false,
        isPro: false,
        hasArchiveProof: true,
      ),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  group('First archive view', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync(
        'vm_fsl_journal_${DateTime.now().microsecondsSinceEpoch}_',
      );
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        prefsPath: '${tempDir.path}/prefs.json',
        skipRevenueCat: true,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<void> pumpJournal(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: JournalScreen(key: UniqueKey()),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      for (
        var i = 0;
        i < 40 &&
            find
                .byKey(const Key('first_archive_value_card'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
      }
    }

    testWidgets('appears for one entry with search and pin', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'a'));
      });
      await pumpJournal(tester);
      expect(find.byKey(const Key('first_archive_value_card')), findsOneWidget);
      expect(find.byKey(const Key('first_archive_search_cta')), findsOneWidget);
      expect(find.byKey(const Key('first_archive_pin_cta')), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstArchiveValueCardSeen),
        hasLength(1),
      );
    });

    testWidgets('hidden for zero entries', (tester) async {
      await pumpJournal(tester);
      expect(find.byKey(const Key('first_archive_value_card')), findsNothing);
    });

    test('Pro bridge dismissal persists in store', () async {
      final prefs = _MemoryPrefs();
      final store = FirstSaveLoopStore(prefs: prefs);
      await store.markProBridgeResolved();
      final state = await store.load();
      expect(state.proBridgeResolved, isTrue);
    });
  });

  group('Store', () {
    test('return cue and Pro bridge resolution persist', () async {
      final prefs = _MemoryPrefs();
      final store = FirstSaveLoopStore(prefs: prefs);
      await store.markReturnCueResolved(FirstSaveReturnCueMethod.localCue);
      await store.markProBridgeResolved();
      final state = await store.load();
      expect(state.returnCueResolved, isTrue);
      expect(state.returnCueMethod, 'local_cue');
      expect(state.proBridgeResolved, isTrue);
    });
  });

  group('Analytics guardrails', () {
    test('payloads use only whitelisted keys', () {
      const allowed = {'entry_count', 'source', 'stage', 'memory_scope'};
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.firstSaveEvidenceCardSeen,
        entryCount: 1,
        stage: FirstSaveLoopStage.evidence.id,
        source: 'record',
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.tomorrowReturnCueAccepted,
        entryCount: 1,
        stage: FirstSaveLoopStage.returnCue.id,
        source: 'private journal text!',
      );
      for (final e in captured) {
        for (final key in e.properties.keys) {
          expect(allowed.contains(key), isTrue, reason: 'unexpected $key');
        }
      }
      final dropped = captured
          .where(
            (e) =>
                e.event == ActivationFunnelAnalytics.tomorrowReturnCueAccepted,
          )
          .single;
      expect(dropped.properties.containsKey('source'), isFalse);
    });
  });
}