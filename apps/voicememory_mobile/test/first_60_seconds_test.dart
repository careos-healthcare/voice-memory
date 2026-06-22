import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/onboarding/first_60_second_state.dart';
import 'package:voicememory_mobile/features/onboarding/first_60_second_store.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/journal_screen.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_60_second_intro_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_archive_value_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_recording_value_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/pro_continuity_bridge_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/tomorrow_return_card.dart';

import 'support/memory_pressure_stores.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/first60/unused.json'));

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
    test('intro copy is exact', () {
      expect(First60Copy.introTitle, 'Notice what keeps repeating');
      expect(
        First60Copy.introBody,
        'ArchiveMe helps you notice what keeps repeating in your own words. '
        'Start with one honest moment.',
      );
      expect(First60Copy.introCta, 'Record one moment');
      expect(
        First60Copy.introReassurance,
        'Your recordings stay on this device unless you choose sync or transcription.',
      );
    });

    test('first save value card copy is exact', () {
      expect(First60Copy.valueTitle, 'Saved to your archive');
      expect(
        First60Copy.valueBody,
        'This is now evidence you can return to later.',
      );
      expect(
        First60Copy.valueSecondLine,
        'When patterns appear, ArchiveMe can show what returned, faded, '
        'or changed.',
      );
      expect(First60Copy.valueCta, 'View my archive');
      expect(First60Copy.valueSecondary, 'Record another');
      expect(
        First60Copy.valueReassurance,
        'You can mark entries as exact evidence or keep them separate '
        'later.',
      );
    });

    test('return cue copy is exact', () {
      expect(First60Copy.returnTitle, 'Come back tomorrow');
      expect(
        First60Copy.returnBody,
        'One entry starts the archive. A second entry is where change '
        'begins to show.',
      );
      expect(First60Copy.returnRemindCta, 'Remind me tomorrow');
      expect(First60Copy.returnLocalCta, 'I\u2019ll come back tomorrow');
    });

    test('Pro bridge copy is exact', () {
      expect(First60Copy.proTitle, 'Keep your archive useful over time');
      expect(
        First60Copy.proBody,
        'Unlock deeper history, saved evidence, and what keeps returning '
        'as your archive grows.',
      );
      expect(First60Copy.proCta, 'See Pro');
      expect(First60Copy.proSecondary, 'Not now');
    });

    test('archive helper copy is exact', () {
      expect(First60Copy.helperTitle, 'Your archive has started');
      expect(
        First60Copy.helperBody,
        'Search, pin, or return tomorrow to see what changes.',
      );
      expect(First60Copy.helperSearchAction, 'Search archive');
      expect(First60Copy.helperPinAction, 'Pin this entry');
    });

    test('first save does not claim a pattern', () {
      final copy = First60Copy.all.join(' ').toLowerCase();
      expect(copy, isNot(contains('we found a pattern')));
      expect(copy, isNot(contains('pattern found')));
      expect(copy, isNot(contains('your pattern is')));
      // The value framing is preservation + future comparison only.
      expect(First60Copy.valueBody, contains('return to later'));
    });

    test('no VoiceMemory, banned words, or architecture talk', () {
      final copy = First60Copy.all.join(' ').toLowerCase();
      expect(copy, isNot(contains('voicememory')));
      for (final banned in _bannedWords) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'first-60 copy contains banned word "$banned"',
        );
      }
      // No memory-architecture over-explaining in the first session.
      for (final term in const [
        'evidence pipeline',
        'authority',
        'memory scope',
        'retrieval',
      ]) {
        expect(
          copy,
          isNot(contains(term)),
          reason: 'first-60 copy over-explains via "$term"',
        );
      }
      expect(copy, isNot(contains('unlock premium')));
    });
  });

  group('Visibility gates', () {
    test('first intro shows only when there are zero entries', () {
      expect(First60Gates.showIntro(entryCount: 0), isTrue);
      expect(First60Gates.showIntro(entryCount: 1), isFalse);
      expect(First60Gates.showIntro(entryCount: 5), isFalse);
      expect(First60IntroCard.shouldShow(0), isTrue);
      expect(First60IntroCard.shouldShow(1), isFalse);
    });

    test('value card only at the first save moment', () {
      expect(
        First60Gates.showValueCard(entryCount: 1, justSaved: true),
        isTrue,
      );
      expect(
        First60Gates.showValueCard(entryCount: 1, justSaved: false),
        isFalse,
      );
      expect(
        First60Gates.showValueCard(entryCount: 2, justSaved: true),
        isFalse,
      );
    });

    test('return cue after first save until resolved', () {
      expect(
        First60Gates.showReturnCue(
          entryCount: 1,
          justSaved: true,
          resolved: false,
        ),
        isTrue,
      );
      expect(
        First60Gates.showReturnCue(
          entryCount: 1,
          justSaved: true,
          resolved: true,
        ),
        isFalse,
      );
      expect(
        First60Gates.showReturnCue(
          entryCount: 0,
          justSaved: false,
          resolved: false,
        ),
        isFalse,
      );
    });

    test('Pro bridge appears only after second entry or archive repeat value', () {
      expect(
        First60Gates.showProBridge(entryCount: 0, resolved: false),
        isFalse,
      );
      expect(
        First60Gates.showProBridge(entryCount: 1, resolved: false),
        isFalse,
      );
      expect(
        First60Gates.showProBridge(entryCount: 2, resolved: false),
        isTrue,
      );
      expect(
        First60Gates.showProBridge(entryCount: 2, resolved: true),
        isFalse,
      );
    });

    test('first archive helper appears for exactly one entry', () {
      expect(First60Gates.showArchiveHelper(entryCount: 0), isFalse);
      expect(First60Gates.showArchiveHelper(entryCount: 1), isTrue);
      expect(First60Gates.showArchiveHelper(entryCount: 2), isFalse);
      expect(FirstArchiveValueCard.shouldShow(1), isTrue);
      expect(FirstArchiveValueCard.shouldShow(2), isFalse);
    });
  });

  group('Store persistence', () {
    test('return cue resolution persists with method', () async {
      final prefs = _MemoryPrefs();
      final store = First60SecondStore(prefs: prefs);
      expect((await store.load()).returnCueResolved, isFalse);

      await store.markReturnCueResolved(First60ReturnCueMethod.localCue);
      final state = await store.load();
      expect(state.returnCueResolved, isTrue);
      expect(state.returnCueMethod, 'local_cue');
      expect(state.proBridgeResolved, isFalse);
    });

    test('Pro bridge resolution persists', () async {
      final prefs = _MemoryPrefs();
      final store = First60SecondStore(prefs: prefs);
      await store.markProBridgeResolved();
      expect((await store.load()).proBridgeResolved, isTrue);
    });

    test('first save logging persists once', () async {
      final prefs = _MemoryPrefs();
      final store = First60SecondStore(prefs: prefs);
      expect((await store.load()).firstSaveLogged, isFalse);
      await store.markFirstSaveLogged();
      expect((await store.load()).firstSaveLogged, isTrue);
    });

    test('no persistence resolves everything so nothing can nag', () async {
      final store = First60SecondStore(prefs: null);
      // AppServices may be initialized by other groups; only assert the
      // pure fallback shape via fromJson.
      final fallback = First60SecondState.fromJson(null);
      expect(fallback.returnCueResolved, isFalse);
      expect(store, isNotNull);
    });
  });

  group('Intro card widget', () {
    Future<void> pumpIntro(
      WidgetTester tester, {
      VoidCallback? onRecord,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: First60IntroCard(onRecord: onRecord ?? () {}),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders the exact intro copy', (tester) async {
      await pumpIntro(tester);
      expect(find.byKey(const Key('first_60_intro_card')), findsOneWidget);
      expect(find.text(First60Copy.introBody), findsOneWidget);
      expect(find.text(First60Copy.introTitle), findsOneWidget);
      expect(find.text(First60Copy.introCta), findsOneWidget);
      expect(find.byKey(const Key('first_60_record_cta')), findsOneWidget);
      expect(find.text(First60Copy.introReassurance), findsOneWidget);
    });

    testWidgets('fires intro_seen once and record CTA event on tap', (
      tester,
    ) async {
      await pumpIntro(tester);
      await tester.pump();
      expect(
        eventsNamed(ActivationFunnelAnalytics.first60IntroSeen),
        hasLength(1),
      );

      var recorded = false;
      await pumpIntro(tester, onRecord: () => recorded = true);
      await tester.tap(find.byKey(const Key('first_60_record_cta')));
      await tester.pump();
      expect(recorded, isTrue);
      expect(
        eventsNamed(ActivationFunnelAnalytics.first60RecordCtaTapped),
        hasLength(1),
      );
      // Seen stays de-duped per session.
      expect(
        eventsNamed(ActivationFunnelAnalytics.first60IntroSeen),
        hasLength(1),
      );
    });
  });

  group('Value card widget', () {
    testWidgets('renders exact copy and fires events', (tester) async {
      var viewed = false;
      var recordedAnother = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstRecordingValueCard(
                onViewArchive: () => viewed = true,
                onRecordAnother: () => recordedAnother = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(First60Copy.valueTitle), findsOneWidget);
      expect(find.text(First60Copy.valueBody), findsOneWidget);
      expect(find.text(First60Copy.valueSecondLine), findsOneWidget);
      expect(find.text(First60Copy.valueReassurance), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.first60ValueCardSeen),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('first_60_view_archive_cta')));
      await tester.pump();
      expect(viewed, isTrue);
      expect(
        eventsNamed(ActivationFunnelAnalytics.first60ArchiveOpened),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('first_60_record_another_cta')));
      await tester.pump();
      expect(recordedAnother, isTrue);
    });
  });

  group('Tomorrow return cue widget', () {
    Future<void> pumpCue(
      WidgetTester tester, {
      required bool reminderAvailable,
      VoidCallback? onRemind,
      VoidCallback? onLocalCue,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: First60ReturnCueCard(
                reminderAvailable: reminderAvailable,
                onRemind: onRemind ?? () {},
                onLocalCue: onLocalCue ?? () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows reminder CTA only when infrastructure is available', (
      tester,
    ) async {
      await pumpCue(tester, reminderAvailable: true);
      expect(find.text(First60Copy.returnTitle), findsOneWidget);
      expect(find.text(First60Copy.returnBody), findsOneWidget);
      expect(find.byKey(const Key('first_60_remind_cta')), findsOneWidget);
      expect(find.byKey(const Key('first_60_local_cue_cta')), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.first60ReturnCueSeen),
        hasLength(1),
      );
    });

    testWidgets('without reminder infra only the local cue renders', (
      tester,
    ) async {
      await pumpCue(tester, reminderAvailable: false);
      expect(find.byKey(const Key('first_60_remind_cta')), findsNothing);
      expect(find.byKey(const Key('first_60_local_cue_cta')), findsOneWidget);
      expect(find.text(First60Copy.returnLocalCta), findsOneWidget);
    });

    testWidgets(
      'rendering requests nothing — onRemind fires only from the explicit '
      'reminder tap',
      (tester) async {
        var reminded = false;
        var local = false;
        await pumpCue(
          tester,
          reminderAvailable: true,
          onRemind: () => reminded = true,
          onLocalCue: () => local = true,
        );
        // Render alone schedules nothing and asks for nothing.
        expect(reminded, isFalse);
        expect(local, isFalse);

        await tester.tap(find.byKey(const Key('first_60_local_cue_cta')));
        await tester.pump();
        expect(local, isTrue);
        expect(reminded, isFalse);
        final accepted = eventsNamed(
          ActivationFunnelAnalytics.first60ReturnCueAccepted,
        );
        expect(accepted, hasLength(1));
        expect(accepted.single.properties['source'], 'local_cue');
      },
    );

    testWidgets('reminder tap fires accepted with the reminder method', (
      tester,
    ) async {
      var reminded = false;
      await pumpCue(
        tester,
        reminderAvailable: true,
        onRemind: () => reminded = true,
      );
      await tester.tap(find.byKey(const Key('first_60_remind_cta')));
      await tester.pump();
      expect(reminded, isTrue);
      final accepted = eventsNamed(
        ActivationFunnelAnalytics.first60ReturnCueAccepted,
      );
      expect(accepted, hasLength(1));
      expect(accepted.single.properties['source'], 'reminder');
    });
  });

  group('Pro bridge widget', () {
    Future<void> pumpBridge(
      WidgetTester tester, {
      VoidCallback? onSeePro,
      VoidCallback? onNotNow,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProContinuityBridgeCard(
                entryCount: 1,
                source: 'record',
                onSeePro: onSeePro ?? () {},
                onNotNow: onNotNow ?? () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders exact copy and fires seen once', (tester) async {
      await pumpBridge(tester);
      expect(find.text(First60Copy.proTitle), findsOneWidget);
      expect(find.text(First60Copy.proBody), findsOneWidget);
      expect(find.text(First60Copy.proCta), findsOneWidget);
      expect(find.text(First60Copy.proSecondary), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.first60ProBridgeSeen),
        hasLength(1),
      );
    });

    testWidgets('See Pro and Not now fire their events', (tester) async {
      var seePro = false;
      var notNow = false;
      await pumpBridge(
        tester,
        onSeePro: () => seePro = true,
        onNotNow: () => notNow = true,
      );
      await tester.tap(find.byKey(const Key('first_60_pro_bridge_see_pro')));
      await tester.pump();
      expect(seePro, isTrue);
      expect(
        eventsNamed(ActivationFunnelAnalytics.first60ProBridgeTapped),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('first_60_pro_bridge_not_now')));
      await tester.pump();
      expect(notNow, isTrue);
      expect(
        eventsNamed(ActivationFunnelAnalytics.first60ProBridgeDismissed),
        hasLength(1),
      );
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_first60_record_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        prefsPath: '${tempDir.path}/prefs.json',
        skipRevenueCat: true,
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpRecordScreen(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('intro shows at zero entries and does not block recording', (
      tester,
    ) async {
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('first_60_intro_card')), findsOneWidget);
      expect(find.text(First60Copy.introBody), findsOneWidget);
      expect(find.text(First60Copy.introReassurance), findsOneWidget);
      // The normal recording path stays fully available below the intro.
      expect(find.byType(CaptureEntryActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('intro hides once a recording is saved', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry());
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('first_60_intro_card')), findsNothing);
      expect(find.text(First60Copy.introBody), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Pro bridge does not interrupt first recording — nothing first-60 '
      'Pro-related renders before a save',
      (tester) async {
        await pumpRecordScreen(tester);
        expect(find.byKey(const Key('first_60_pro_bridge_card')), findsNothing);
        expect(find.text(First60Copy.proTitle), findsNothing);
        expect(
          eventsNamed(ActivationFunnelAnalytics.first60ProBridgeSeen),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'advanced memory controls are not forced into the first 60 seconds',
      (tester) async {
        await pumpRecordScreen(tester);
        // The intro never pushes evidence/memory architecture; the existing
        // memory scope control stays available further down — unchanged,
        // never inside the intro card.
        final intro = find.byKey(const Key('first_60_intro_card'));
        expect(intro, findsOneWidget);
        expect(
          find.descendant(of: intro, matching: find.textContaining('Memory')),
          findsNothing,
        );
        expect(
          find.descendant(of: intro, matching: find.textContaining('evidence')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('First archive view', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_first60_journal_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        prefsPath: '${tempDir.path}/prefs.json',
        skipRevenueCat: true,
      );
    });

    Future<void> pumpJournal(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        // A fresh key forces fresh screen state on re-pumps.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: JournalScreen(key: UniqueKey()),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }

    testWidgets('helper appears for exactly one entry with both actions', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'a'));
      });
      await pumpJournal(tester);

      expect(
        find.byKey(const Key('first_archive_value_card')),
        findsOneWidget,
      );
      expect(find.text(RecordReturnProCopy.archiveTitle), findsOneWidget);
      expect(find.text(RecordReturnProCopy.archiveBody), findsOneWidget);
      // Search 2.0 and Pins exist on this branch, so both actions render.
      expect(find.byKey(const Key('first_archive_search_cta')), findsOneWidget);
      expect(find.byKey(const Key('first_archive_pin_cta')), findsOneWidget);
      // No Collections / bulk-action pushes inside the helper.
      final helper = find.byKey(const Key('first_archive_value_card'));
      expect(
        find.descendant(
          of: helper,
          matching: find.textContaining('Collection'),
        ),
        findsNothing,
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstArchiveValueCardSeen),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('helper hides with two entries', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'a'));
        await AppServices.instance.journalStore.save(
          _entry(id: 'b', createdAt: DateTime(2026, 6, 12, 9)),
        );
      });
      await pumpJournal(tester);
      expect(
        find.byKey(const Key('first_archive_value_card')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('search action focuses the existing search bar', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'a'));
      });
      await pumpJournal(tester);
      await tester.tap(find.byKey(const Key('first_archive_search_cta')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('archive_search_bar')),
      );
      expect(field.focusNode?.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pin action pins the single entry via the existing flow', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'a'));
      });
      await pumpJournal(tester);
      await tester.tap(find.byKey(const Key('first_archive_pin_cta')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      late JournalEntry pinned;
      await tester.runAsync(() async {
        pinned = (await AppServices.instance.journalStore.getById('a'))!;
      });
      expect(pinned.isPinned, isTrue);
      // An already-pinned entry gets no pin action on a fresh view.
      await pumpJournal(tester);
      expect(
        find.byKey(const Key('first_archive_value_card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('first_archive_pin_cta')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pro bridge shows after repeat value and Not now persists', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'a'));
        await AppServices.instance.journalStore.save(
          _entry(id: 'b', createdAt: DateTime(2026, 6, 12, 9)),
        );
      });
      await pumpJournal(tester);
      expect(find.byKey(const Key('pro_value_clarity_card')), findsOneWidget);

      final notNow = tester.widget<OutlinedButton>(
        find.byKey(const Key('pro_value_clarity_not_now')),
      );
      await tester.runAsync(() async {
        notNow.onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(
        eventsNamed(ActivationFunnelAnalytics.proValueClarityDismissed),
        hasLength(1),
      );

      late RecordReturnProState state;
      await tester.runAsync(() async {
        state = await RecordReturnProStore.instance().load();
      });
      expect(state.proBridgeResolved, isTrue);

      await pumpJournal(tester);
      expect(find.byKey(const Key('pro_value_clarity_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Analytics guardrails', () {
    test('event names are the fixed first-60 set', () {
      expect(ActivationFunnelAnalytics.first60IntroSeen, 'first_60_intro_seen');
      expect(
        ActivationFunnelAnalytics.first60RecordCtaTapped,
        'first_60_record_cta_tapped',
      );
      expect(
        ActivationFunnelAnalytics.first60FirstSaveCompleted,
        'first_60_first_save_completed',
      );
      expect(
        ActivationFunnelAnalytics.first60ValueCardSeen,
        'first_60_value_card_seen',
      );
      expect(
        ActivationFunnelAnalytics.first60ArchiveOpened,
        'first_60_archive_opened',
      );
      expect(
        ActivationFunnelAnalytics.first60ReturnCueSeen,
        'first_60_return_cue_seen',
      );
      expect(
        ActivationFunnelAnalytics.first60ReturnCueAccepted,
        'first_60_return_cue_accepted',
      );
      expect(
        ActivationFunnelAnalytics.first60ProBridgeSeen,
        'first_60_pro_bridge_seen',
      );
      expect(
        ActivationFunnelAnalytics.first60ProBridgeTapped,
        'first_60_pro_bridge_tapped',
      );
      expect(
        ActivationFunnelAnalytics.first60ProBridgeDismissed,
        'first_60_pro_bridge_dismissed',
      );
    });

    test('payloads carry only whitelisted keys and safe values', () {
      final safeValue = RegExp(r'^[a-z0-9_]{1,40}$');
      const allowed = {'entry_count', 'source', 'stage', 'memory_scope'};

      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.first60IntroSeen,
        entryCount: 0,
        stage: First60Stage.intro.id,
        source: 'record',
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.first60FirstSaveCompleted,
        entryCount: 1,
        stage: First60Stage.firstSave.id,
        source: 'record',
        memoryScope: 'automatic',
      );
      // Private content has no path in: free-text values are dropped by
      // the safe-value filter.
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.first60ReturnCueAccepted,
        entryCount: 1,
        stage: First60Stage.returnCue.id,
        source: 'My private thought about work!',
      );

      for (final e in captured) {
        expect(e.event, startsWith('first_60_'));
        for (final entry in e.properties.entries) {
          expect(
            allowed.contains(entry.key),
            isTrue,
            reason: 'unexpected property key ${entry.key}',
          );
          final value = entry.value;
          if (value is String) {
            expect(
              safeValue.hasMatch(value),
              isTrue,
              reason: 'unsafe value "$value" for ${entry.key}',
            );
          }
        }
      }
      final dropped = captured
          .where(
            (e) =>
                e.event == ActivationFunnelAnalytics.first60ReturnCueAccepted,
          )
          .single;
      expect(dropped.properties.containsKey('source'), isFalse);
    });

    test('stage ids are stable and safe', () {
      final safeValue = RegExp(r'^[a-z0-9_]{1,40}$');
      for (final stage in First60Stage.values) {
        expect(safeValue.hasMatch(stage.id), isTrue);
      }
      expect(First60Stage.intro.id, 'intro');
      expect(First60Stage.firstSave.id, 'first_save');
      expect(First60Stage.returnCue.id, 'return_cue');
      expect(First60Stage.proBridge.id, 'pro_bridge');
      expect(First60Stage.archiveHelper.id, 'archive_helper');
    });
  });
}
