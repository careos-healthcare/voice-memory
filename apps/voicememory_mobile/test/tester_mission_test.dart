import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/archive_proof/low_effort_capture_copy_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_analytics.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_copy.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_engine.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_gates.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_model.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_store.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/tester_mission_card.dart';

import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';

import 'support/memory_pressure_stores.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/tester_mission/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

JournalEntry _entry({
  required String id,
  String? transcript,
}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 1, 12),
      transcript: transcript ??
          'A long enough transcript to count as a saved reflection for tests.',
      durationSeconds: 30,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'You mentioned pressure in this moment.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _relatedPair() => [
      _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
      ),
    ];

List<JournalEntry> _relatedThree() => [
      ..._relatedPair(),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
      ),
    ];

void main() {
  group('TesterMissionGates', () {
    tearDown(ArchiveBetaMissionGate.resetForTest);

    test('hidden when beta mission flag/debug gate is false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        TesterMissionGates.shouldShow(
          dismissed: false,
          ui: RecordUiState.ready,
          entryCountLoaded: true,
          isRecording: false,
          isPostSave: false,
        ),
        isFalse,
      );
    });

    test('shown when beta gate enabled on ready record', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        TesterMissionGates.shouldShow(
          dismissed: false,
          ui: RecordUiState.ready,
          entryCountLoaded: true,
          isRecording: false,
          isPostSave: false,
        ),
        isTrue,
      );
    });

    test('compact at entry zero with first-use simplified record', () {
      expect(
        TesterMissionGates.useCompactPresentation(
          entryCount: 0,
          firstUseSimplifiedRecord: true,
        ),
        isTrue,
      );
      expect(
        TesterMissionGates.useCompactPresentation(
          entryCount: 1,
          firstUseSimplifiedRecord: true,
        ),
        isFalse,
      );
    });
  });

  group('TesterMissionEngine', () {
    test('entry 0 explains 3-moment proof test', () {
      final mission = TesterMissionEngine.build(
        entryCount: 0,
        entries: const [],
        compactAtEntryZero: false,
      );
      expect(mission.body.toLowerCase(), contains('3-moment'));
      expect(mission.body.toLowerCase(), contains('real moment'));
    });

    test('entry 1 tells user to come back with similar moment', () {
      final mission = TesterMissionEngine.build(
        entryCount: 1,
        entries: [_entry(id: 'e1')],
        compactAtEntryZero: false,
      );
      expect(mission.body.toLowerCase(), contains('similar'));
      expect(mission.body.toLowerCase(), contains('moment 2'));
    });

    test('entry 2 related says one more unlocks first proof', () {
      final mission = TesterMissionEngine.build(
        entryCount: 2,
        entries: _relatedPair(),
        compactAtEntryZero: false,
      );
      expect(
        mission.body.toLowerCase(),
        contains('unlocks your first proof'),
      );
    });

    test('entry 2 unrelated reassures without claiming repeat', () {
      final mission = TesterMissionEngine.build(
        entryCount: 2,
        entries: [
          _entry(id: 'e1', transcript: 'Planning the garden layout this week.'),
          _entry(
            id: 'e2',
            transcript: 'Finished a book about ancient history last night.',
          ),
        ],
        compactAtEntryZero: false,
      );
      expect(mission.body.toLowerCase(), contains('okay'));
      expect(mission.body.toLowerCase(), isNot(contains('unlocks')));
      expect(mission.footer, TesterMissionCopy.entry2UnrelatedFooter);
    });

    test('entry 0 shows Step 1 of 3', () {
      final mission = TesterMissionEngine.build(
        entryCount: 0,
        entries: const [],
        compactAtEntryZero: false,
      );
      expect(mission.stepLabel, TesterMissionCopy.entry0StepLabel);
      expect(mission.body, TesterMissionCopy.entry0Body);
      expect(mission.step, TesterMissionStep.step1Of3);
    });

    test('entry 1 shows Step 2 of 3', () {
      final mission = TesterMissionEngine.build(
        entryCount: 1,
        entries: [_entry(id: 'e1')],
        compactAtEntryZero: false,
      );
      expect(mission.stepLabel, TesterMissionCopy.entry1StepLabel);
      expect(mission.body, TesterMissionCopy.entry1Body);
      expect(mission.step, TesterMissionStep.step2Of3);
    });

    test('entry 2 related shows Step 3 of 3', () {
      final mission = TesterMissionEngine.build(
        entryCount: 2,
        entries: _relatedPair(),
        compactAtEntryZero: false,
      );
      expect(mission.stepLabel, TesterMissionCopy.entry2RelatedStepLabel);
      expect(mission.body, TesterMissionCopy.entry2RelatedBody);
      expect(mission.step, TesterMissionStep.step3Of3);
    });

    test('entry 2 unrelated does not claim repeat', () {
      final mission = TesterMissionEngine.build(
        entryCount: 2,
        entries: [
          _entry(id: 'e1', transcript: 'Planning the garden layout this week.'),
          _entry(
            id: 'e2',
            transcript: 'Finished a book about ancient history last night.',
          ),
        ],
        compactAtEntryZero: false,
      );
      expect(mission.stepLabel, TesterMissionCopy.entry2UnrelatedStepLabel);
      expect(mission.body, TesterMissionCopy.entry2UnrelatedBody);
      expect(mission.step, TesterMissionStep.stillLooking);
      expect(mission.body.toLowerCase(), isNot(contains('repeat')));
    });

    test('entry 3 confirmed shows First proof reached', () {
      final mission = TesterMissionEngine.build(
        entryCount: 3,
        entries: _relatedThree(),
        compactAtEntryZero: false,
      );
      expect(mission.stepLabel, TesterMissionCopy.entry3ConfirmedStepLabel);
      expect(mission.body, TesterMissionCopy.entry3ConfirmedBody);
      expect(mission.step, TesterMissionStep.firstProofReached);
    });

    test('entry 3 unconfirmed shows Still looking', () {
      final mission = TesterMissionEngine.build(
        entryCount: 3,
        entries: [
          _entry(id: 'e1', transcript: 'Planning the garden layout this week.'),
          _entry(
            id: 'e2',
            transcript: 'Finished a book about ancient history last night.',
          ),
          _entry(
            id: 'e3',
            transcript: 'Watched a documentary about ocean currents today.',
          ),
        ],
        compactAtEntryZero: false,
      );
      expect(mission.stepLabel, TesterMissionCopy.entry3UnconfirmedStepLabel);
      expect(mission.body, TesterMissionCopy.entry3UnconfirmedBody);
      expect(mission.step, TesterMissionStep.stillLooking);
    });
  });

  group('TesterMissionCopy guard', () {
    test('no transcript or phrase text in analytics copy', () {
      const blocked = [
        'transcript',
        'phrase',
        'therapy',
        'diagnosis',
      ];
      final corpus = [
        TesterMissionCopy.title,
        TesterMissionCopy.entry0Body,
        TesterMissionCopy.entry0Footer,
        TesterMissionCopy.entry1Body,
        TesterMissionCopy.entry1Footer,
        TesterMissionCopy.entry2RelatedBody,
        TesterMissionCopy.entry2RelatedFooter,
        TesterMissionCopy.entry2UnrelatedBody,
        TesterMissionCopy.entry2UnrelatedFooter,
        TesterMissionCopy.entry3ConfirmedBody,
        TesterMissionCopy.entry3ConfirmedFooter,
        TesterMissionCopy.entry3UnconfirmedBody,
        TesterMissionCopy.entry3UnconfirmedFooter,
        TesterMissionAnalytics.seenEvent,
        TesterMissionAnalytics.dismissedEvent,
      ].join('\n').toLowerCase();

      for (final word in blocked) {
        expect(corpus, isNot(contains(word)));
      }
    });

    test('explains 3-moment proof without journaling-forever language', () {
      final joined = [
        TesterMissionCopy.entry0Body,
        TesterMissionCopy.entry0Footer,
        TesterMissionCopy.entry1Body,
      ].join(' ').toLowerCase();

      expect(joined, contains('3-moment'));
      expect(joined, contains('real moment'));
      expect(joined, anyOf(contains('short is fine'), contains('ten seconds')));
      expect(joined, isNot(contains('journal forever')));
      expect(joined, isNot(contains('journal every day')));
    });

    test('avoids chatbot and high-friction capture language', () {
      for (final line in [
        TesterMissionCopy.entry0Body,
        TesterMissionCopy.entry0Footer,
        TesterMissionCopy.entry1Body,
        TesterMissionCopy.entry1Footer,
      ]) {
        for (final violation in LowEffortCaptureCopyGuard.violationsIn(line)) {
          fail('"$line" contains banned friction phrase "$violation"');
        }
      }
    });
  });

  group('TesterMissionStore', () {
    late _MemoryPrefs prefs;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_tester_mission_store_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      prefs = _MemoryPrefs();
      await TesterMissionStore.resetForTest();
    });

    tearDown(() async {
      await TesterMissionStore.resetForTest();
    });

    test('session dismiss hides card', () async {
      final store = TesterMissionStore(prefs);
      expect(TesterMissionStore.isDismissed, isFalse);
      store.dismissForSession();
      expect(TesterMissionStore.isDismissed, isTrue);
    });

    test('day dismiss persists locally', () async {
      final store = TesterMissionStore(prefs);
      await store.dismissForDay();
      expect(TesterMissionStore.isDismissed, isTrue);
      expect(
        prefs.maps[TesterMissionStore.prefsKey]?['dismissedUntilDay'],
        isNotNull,
      );
    });
  });

  group('TesterMissionCard widget', () {
    testWidgets('dismiss hides card', (tester) async {
      final mission = TesterMissionEngine.build(
        entryCount: 1,
        entries: [_entry(id: 'e1')],
        compactAtEntryZero: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TesterMissionCard.test(mission: mission),
          ),
        ),
      );

      expect(find.byKey(const Key('tester_mission_card')), findsOneWidget);
      await tester.tap(find.text(TesterMissionCopy.hideForNowCta));
      await tester.pump();
      expect(find.byKey(const Key('tester_mission_card_hidden')), findsOneWidget);
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_tester_mission_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      await TesterMissionStore.resetForTest();
      ArchiveBetaMissionGate.enabledOverride = true;
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() async {
      ArchiveBetaMissionGate.resetForTest();
      VisualAuditOverrides.setRecordPresentation(null);
      await AppServices.instance.journalStore.clearAll();
    });

    Future<void> pumpRecord(WidgetTester tester, {int entryCount = 0}) async {
      if (entryCount > 0) {
        await tester.runAsync(() async {
          for (var i = 0; i < entryCount; i++) {
            await AppServices.instance.journalStore.save(
              _entry(id: 'e$i'),
            );
          }
        });
      }
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: MemoryPressureCheckInStore(),
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (entryCount == 0 &&
            find.byKey(const Key('record_first_use_capture_section')).evaluate().isNotEmpty) {
          return;
        }
        if (entryCount > 0 &&
            find.byType(CaptureEntryActions).evaluate().isNotEmpty) {
          return;
        }
      }
    }

    testWidgets('hidden when beta gate is false', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await pumpRecord(tester, entryCount: 1);
      expect(find.byKey(const Key('tester_mission_card')), findsNothing);
      expect(find.byKey(const Key('tester_mission_compact_strip')), findsNothing);
    });

    testWidgets('entry 0 uses compact strip near first-use capture', (tester) async {
      await pumpRecord(tester);
      expect(find.byKey(const Key('tester_mission_compact_strip')), findsOneWidget);
      expect(find.byKey(const Key('tester_mission_card')), findsNothing);
      expect(find.text(TesterMissionCopy.entry0StepLabel), findsOneWidget);
      expect(find.text(TesterMissionCopy.entry0Body), findsNothing);
    });

    testWidgets('entry 1 shows Step 2 of 3 without duplicate primary CTA', (
      tester,
    ) async {
      await pumpRecord(tester, entryCount: 1);
      expect(find.byKey(const Key('tester_mission_card')), findsOneWidget);
      expect(find.text(TesterMissionCopy.entry1StepLabel), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
      expect(find.text(TesterMissionCopy.hideForNowCta), findsOneWidget);
      expect(find.text('Start with one moment'), findsNothing);
    });
  });

  group('Billing isolation', () {
    test('billing RevenueCat restore untouched', () {
      final cardSource = File(
        'lib/widgets/beta/tester_mission_card.dart',
      ).readAsStringSync();
      final analyticsSource = File(
        'lib/features/beta/tester_mission_analytics.dart',
      ).readAsStringSync();

      for (final source in [cardSource, analyticsSource]) {
        expect(source.toLowerCase(), isNot(contains('revenuecat')));
        expect(source.toLowerCase(), isNot(contains('billing')));
        expect(source.toLowerCase(), isNot(contains('restore')));
      }
    });
  });
}
