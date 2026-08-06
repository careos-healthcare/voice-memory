import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/archive_proof/low_effort_capture_copy_guard.dart';
import 'package:voicememory_mobile/features/app_review/archive_app_review_access_gate.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta/core_value_feedback_copy.dart';
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
import 'package:archiveme_research/screens/testing_archiveme_screen.dart';
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

JournalEntry _entry({required String id, String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 1, 12),
  transcript:
      transcript ??
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
  group('TesterMissionCopy canonical onboarding', () {
    test('title mission steps and feedback question match brief', () {
      expect(TesterMissionCopy.title, 'Testing ArchiveMe?');
      expect(TesterMissionCopy.mission, 'Reach first proof.');
      expect(TesterMissionCopy.steps, [
        'Record one real moment.',
        'Come back when this shows up again.',
        'Record a third related moment.',
        'Check whether first proof feels specific to your own words.',
      ]);
      expect(
        TesterMissionCopy.feedbackQuestion,
        CoreValueFeedbackCopy.question,
      );
      expect(
        TesterMissionCopy.feedbackSavedBody,
        CoreValueFeedbackCopy.savedMessage,
      );
    });
  });

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

    test('hidden when App Review access is enabled', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      ArchiveAppReviewAccessGate.enabledOverride = true;
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
      ArchiveAppReviewAccessGate.resetForTest();
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
    test('entry 0 uses step 1 progress copy', () {
      final mission = TesterMissionEngine.build(
        entryCount: 0,
        entries: const [],
        compactAtEntryZero: false,
      );
      expect(mission.body, 'Step 1: record one real moment.');
      expect(mission.footer, isEmpty);
    });

    test('entry 1 uses step 1 complete copy', () {
      final mission = TesterMissionEngine.build(
        entryCount: 1,
        entries: [_entry(id: 'e1')],
        compactAtEntryZero: false,
      );
      expect(mission.body, 'Step 1 complete. Next: record something similar.');
      expect(mission.footer, isEmpty);
    });

    test('entry 2 related uses step 2 complete copy', () {
      final mission = TesterMissionEngine.build(
        entryCount: 2,
        entries: _relatedPair(),
        compactAtEntryZero: false,
      );
      expect(
        mission.body,
        'Step 2 complete. One more related moment unlocks first proof.',
      );
      expect(mission.footer, isEmpty);
    });

    test('entry 2 unrelated shows still forming copy', () {
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
      expect(
        mission.body,
        'Step 2 still forming. Record the next real moment.',
      );
      expect(mission.footer, isEmpty);
      expect(mission.body.toLowerCase(), isNot(contains('repeat')));
    });

    test('entry 0 shows step 1 at zero entries', () {
      final mission = TesterMissionEngine.build(
        entryCount: 0,
        entries: const [],
        compactAtEntryZero: false,
      );
      expect(mission.body, TesterMissionCopy.entry0Body);
      expect(mission.step, TesterMissionStep.step1Of3);
    });

    test('entry 1 shows step 1 complete at one entry', () {
      final mission = TesterMissionEngine.build(
        entryCount: 1,
        entries: [_entry(id: 'e1')],
        compactAtEntryZero: false,
      );
      expect(mission.body, TesterMissionCopy.entry1Body);
      expect(mission.step, TesterMissionStep.step2Of3);
    });

    test('entry 2 related shows one more unlocks first proof', () {
      final mission = TesterMissionEngine.build(
        entryCount: 2,
        entries: _relatedPair(),
        compactAtEntryZero: false,
      );
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
      expect(mission.body, TesterMissionCopy.entry2UnrelatedBody);
      expect(mission.step, TesterMissionStep.stillLooking);
    });

    test('entry 3 confirmed asks if first proof felt specific', () {
      final mission = TesterMissionEngine.build(
        entryCount: 3,
        entries: _relatedThree(),
        compactAtEntryZero: false,
      );
      expect(mission.body, TesterMissionCopy.entry3ConfirmedBody);
      expect(mission.body, contains('Did it feel specific to your own words?'));
      expect(mission.step, TesterMissionStep.firstProofReached);
    });

    test('entry 3 unconfirmed shows still looking', () {
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
      expect(mission.body, TesterMissionCopy.entry3UnconfirmedBody);
      expect(mission.step, TesterMissionStep.stillLooking);
    });

    test('feedback answered shows saved thank you', () {
      final mission = TesterMissionEngine.build(
        entryCount: 3,
        entries: _relatedThree(),
        compactAtEntryZero: false,
        feedbackAnswered: true,
      );
      expect(mission.body, TesterMissionCopy.feedbackSavedBody);
      expect(mission.step, TesterMissionStep.feedbackSaved);
    });
  });

  group('TesterMissionCopy guard', () {
    test('no transcript or phrase text in analytics copy', () {
      const blocked = ['transcript', 'phrase', 'therapy', 'diagnosis'];
      final corpus = [
        TesterMissionCopy.title,
        TesterMissionCopy.mission,
        ...TesterMissionCopy.steps,
        TesterMissionCopy.feedbackQuestion,
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
        TesterMissionCopy.feedbackSavedBody,
        TesterMissionAnalytics.seenEvent,
        TesterMissionAnalytics.dismissedEvent,
      ].join('\n').toLowerCase();

      for (final word in blocked) {
        expect(corpus, isNot(contains(word)));
      }
    });

    test('mission steps stay ordered and distinct from journaling forever', () {
      expect(TesterMissionCopy.steps, hasLength(4));
      expect(TesterMissionCopy.steps.first, TesterMissionCopy.step1);
      expect(TesterMissionCopy.steps.last, TesterMissionCopy.step4);

      final joined = TesterMissionCopy.steps.join(' ').toLowerCase();
      expect(joined, contains('real moment'));
      expect(joined, isNot(contains('journal forever')));
      expect(joined, isNot(contains('journal every day')));
    });

    test('progress states stay distinct from guide steps', () {
      expect(
        TesterMissionCopy.entry0Body,
        isNot(equals(TesterMissionCopy.step1)),
      );
      expect(TesterMissionCopy.entry1Body, contains('Step 1 complete'));
      expect(TesterMissionCopy.entry2RelatedBody, contains('Step 2 complete'));
      expect(
        TesterMissionCopy.entry3ConfirmedBody,
        contains('First proof reached'),
      );
    });

    test('avoids chatbot and high-friction capture language', () {
      for (final line in [
        TesterMissionCopy.mission,
        ...TesterMissionCopy.steps,
        TesterMissionCopy.entry0Body,
        TesterMissionCopy.entry1Body,
        TesterMissionCopy.entry2RelatedBody,
        TesterMissionCopy.entry2UnrelatedBody,
        TesterMissionCopy.entry3ConfirmedBody,
        TesterMissionCopy.feedbackSavedBody,
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
          home: Scaffold(body: TesterMissionCard.test(mission: mission)),
        ),
      );

      expect(find.byKey(const Key('tester_mission_card')), findsOneWidget);
      expect(find.text(TesterMissionCopy.mission), findsOneWidget);
      await tester.tap(find.text(TesterMissionCopy.hideForNowCta));
      await tester.pump();
      expect(
        find.byKey(const Key('tester_mission_card_hidden')),
        findsOneWidget,
      );
    });
  });

  group('TestingArchiveMeScreen', () {
    tearDown(ArchiveBetaMissionGate.resetForTest);

    testWidgets('mission steps render in order with feedback question', (
      tester,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = true;

      await tester.pumpWidget(
        const MaterialApp(home: TestingArchiveMeScreen()),
      );

      expect(find.byKey(const Key('testing_archiveme_screen')), findsOneWidget);
      expect(find.text(TesterMissionCopy.mission), findsOneWidget);
      for (var i = 0; i < TesterMissionCopy.steps.length; i++) {
        expect(
          find.text('${i + 1}. ${TesterMissionCopy.steps[i]}'),
          findsOneWidget,
        );
      }
      expect(find.text(TesterMissionCopy.feedbackQuestion), findsOneWidget);
      expect(find.text(TesterMissionCopy.hideForNowCta), findsNothing);
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
            await AppServices.instance.journalStore.save(_entry(id: 'e$i'));
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
            find
                .byKey(const Key('record_first_run_screen_card'))
                .evaluate()
                .isNotEmpty) {
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
      expect(
        find.byKey(const Key('tester_mission_compact_strip')),
        findsNothing,
      );
    });

    testWidgets('entry 0 first-use simplified hides tester mission', (
      tester,
    ) async {
      await pumpRecord(tester);
      expect(
        find.byKey(const Key('tester_mission_compact_strip')),
        findsNothing,
      );
      expect(find.byKey(const Key('tester_mission_card')), findsNothing);
      expect(
        find.byKey(const Key('record_first_run_screen_card')),
        findsOneWidget,
      );
    });

    testWidgets('entry 1 shows mission when beta gate enabled', (tester) async {
      await pumpRecord(tester, entryCount: 1);
      expect(find.byKey(const Key('tester_mission_card')), findsOneWidget);
      expect(find.text(TesterMissionCopy.entry1Body), findsOneWidget);
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
