import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/first_session/first_save_rescue.dart';
import 'package:voicememory_mobile/features/onboarding/first_session_onboarding_copy.dart';
import 'package:voicememory_mobile/features/onboarding/first_session_onboarding_store.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/features/low_evidence/low_evidence_copy.dart';
import 'package:voicememory_mobile/features/record/daily_mirror_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/record/record_empty_archive_gates.dart';
import 'package:voicememory_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
import 'package:voicememory_mobile/features/first_session/two_day_activation_engine.dart';
import 'package:voicememory_mobile/features/referral/invite_attribution.dart';
import 'package:voicememory_mobile/features/referral/invite_funnel_metrics.dart';
import 'package:voicememory_mobile/features/referral/invited_day_two_return.dart';
import 'package:voicememory_mobile/features/referral/invited_user_welcome.dart';
import 'package:voicememory_mobile/features/pressure_retention/done_for_today_receipt_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/pressure_check_in_screen.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';
import 'package:voicememory_mobile/widgets/first_session/first_save_rescue_card.dart';
import 'package:voicememory_mobile/widgets/first_session/first_session_explanation_card.dart';
import 'package:voicememory_mobile/widgets/first_session/two_day_activation_card.dart';
import 'package:voicememory_mobile/widgets/record/done_for_today_receipt_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_first_week_nudge.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_first_win_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_insights_empty_state.dart';
import 'package:voicememory_mobile/widgets/referral/invited_day_two_return_card.dart';
import 'package:voicememory_mobile/widgets/referral/invited_user_welcome_card.dart';

import 'support/memory_pressure_stores.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/invited_welcome/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

PressureCheckInRecord _record({String id = 'a'}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 8, 12),
    optionId: 'did_more_to_not_feel_behind',
    contextIds: const ['work'],
    fear: null,
    choseToStop: false,
    transcript: 'I did more so I wouldn\'t feel behind.',
  );
}

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

Future<void> _pumpInsights(
  WidgetTester tester, {
  required List<PressureCheckInRecord> records,
  bool pro = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PressureInsightsScreen(
        entitlementReader: FakeArchiveEntitlementReader(pro: pro),
        // In-memory stores: AppServices may be initialized by earlier tests
        // in this file, and live stores would do file IO in the widget zone.
        microExperimentStore: MemoryExperimentStore(),
        returnTriggerStore: MemoryReturnTriggerStore(),
        records: records,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('First-session explanation card', () {
    test('shows only for a brand-new user', () {
      expect(FirstSessionExplanationCard.shouldShow(0), isTrue);
      expect(FirstSessionExplanationCard.shouldShow(1), isFalse);
      expect(FirstSessionExplanationCard.shouldShow(5), isFalse);
    });

    testWidgets('renders the exact loop copy and both actions', (tester) async {
      var logged = 0;
      var recorded = 0;
      await _pumpCard(
        tester,
        FirstSessionExplanationCard(
          onLogPressure: () => logged++,
          onRecord: () => recorded++,
        ),
      );

      expect(find.text('How ArchiveMe works'), findsOneWidget);
      expect(find.text('Record one small thing.'), findsOneWidget);
      expect(find.text('After a second moment, ArchiveMe can start comparing your own words.'), findsOneWidget);
      expect(
        find.text('Tomorrow, check whether it returned, faded, or changed.'),
        findsOneWidget,
      );
      expect(find.text('That is enough for today.'), findsOneWidget);
      expect(
        find.text(FirstSessionExplanationCard.primaryLabel),
        findsOneWidget,
      );
      expect(
        find.text(FirstSessionExplanationCard.secondaryLabel),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('first_session_log_pressure_cta')));
      await tester.tap(find.byKey(const Key('first_session_record_cta')));
      expect(logged, 1);
      expect(recorded, 1);
    });

    testWidgets('adds no extra choices beyond the two existing starts', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        FirstSessionExplanationCard(onLogPressure: () {}, onRecord: () {}),
      );
      // Exactly the two pre-existing CTAs — no new prompt choices.
      expect(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        findsNWidgets(2),
      );
      expect(
        find.byKey(const Key('first_session_log_pressure_cta')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('first_session_record_cta')), findsOneWidget);
      expect(find.text('Record this'), findsNothing);
    });

    test('no banned or pressure wording in the loop copy', () {
      final copy = [
        FirstSessionExplanationCard.title,
        ...FirstSessionExplanationCard.steps,
        FirstSessionExplanationCard.footer,
        FirstSessionExplanationCard.primaryLabel,
        FirstSessionExplanationCard.secondaryLabel,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'task',
        'homework',
        'must',
        'should',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnos',
        'definitely',
        'therapy',
        'treatment',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'copy must not contain "$banned"',
        );
      }
      expect(copy, isNot(contains('voicememory')));
    });
  });

  group('First save rescue card', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
      FirstSaveRescue.resetForTest();
    });

    tearDown(() {
      ActivationFunnelAnalytics.resetForTest();
      FirstSaveRescue.resetForTest();
    });

    test('shows only at zero entries', () {
      expect(FirstSaveRescueCard.shouldShow(0), isTrue);
      expect(FirstSaveRescueCard.shouldShow(1), isFalse);
      expect(FirstSaveRescueCard.shouldShow(5), isFalse);
    });

    testWidgets('renders the exact copy with a single CTA', (tester) async {
      await _pumpCard(tester, FirstSaveRescueCard(onStart: () {}));

      expect(find.byKey(const Key('first_save_rescue_card')), findsOneWidget);
      expect(find.text('Try a 10-second test'), findsOneWidget);
      expect(
        find.text(
          'Say one sentence: \u201cWhat has been repeating lately?\u201d',
        ),
        findsOneWidget,
      );
      expect(find.text('You can delete it after.'), findsOneWidget);
      expect(
        find.text('This can be short, private, and deleted anytime.'),
        findsOneWidget,
      );
      expect(find.text('Start test recording'), findsOneWidget);
      // Exactly one new CTA — nothing else to choose.
      expect(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        findsOneWidget,
      );
    });

    testWidgets('confidence seen fires once per session across surfaces', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        Column(
          children: [
            FirstSaveRescueCard(onStart: () {}),
            CaptureEntryActions(
              onRecord: () {},
              underRecordHelper: FirstSaveRescueCard.oneSentenceLine,
            ),
          ],
        ),
      );
      await tester.pump();

      // Both confidence surfaces rendered, the event logged exactly once.
      expect(
        find.byKey(const Key('first_save_confidence_line')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('first_save_one_sentence_helper')),
        findsOneWidget,
      );
      final seen = captured
          .where(
            (e) => e.event == ActivationFunnelAnalytics.firstSaveConfidenceSeen,
          )
          .toList();
      expect(seen, hasLength(1));
      expect(seen.single.properties, {'entry_count': 0});
      // Plain text only — the helper adds no new CTA.
      expect(
        find.widgetWithText(ButtonStyleButton, 'One sentence is enough.'),
        findsNothing,
      );
    });

    testWidgets('seen event fires once with counts only', (tester) async {
      await _pumpCard(tester, FirstSaveRescueCard(onStart: () {}));
      final seen = captured
          .where(
            (e) => e.event == ActivationFunnelAnalytics.firstSaveRescueSeen,
          )
          .toList();
      expect(seen, hasLength(1));
      expect(seen.single.properties, {'entry_count': 0});
    });

    testWidgets('CTA starts the existing recording flow and logs the tap', (
      tester,
    ) async {
      var started = 0;
      await _pumpCard(tester, FirstSaveRescueCard(onStart: () => started++));

      await tester.tap(find.byKey(const Key('first_save_rescue_cta')));
      expect(started, 1);
      expect(FirstSaveRescue.startedFromRescueThisSession, isTrue);

      final tapped = captured
          .where(
            (e) => e.event == ActivationFunnelAnalytics.firstSaveRescueTapped,
          )
          .toList();
      expect(tapped, hasLength(1));
      expect(tapped.single.properties, {'entry_count': 0});
    });

    testWidgets('no private content in any rescue payload', (tester) async {
      await _pumpCard(tester, FirstSaveRescueCard(onStart: () {}));
      await tester.tap(find.byKey(const Key('first_save_rescue_cta')));

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(
          e.properties.keys.toSet().difference(
            ActivationFunnelAnalytics.allowedPropertyKeys,
          ),
          isEmpty,
        );
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        expect(flat, isNot(contains('repeating lately')));
        expect(flat, isNot(contains('voicememory')));
      }
    });

    test('no banned words or VoiceMemory in the rescue copy', () {
      final copy = [
        FirstSaveRescueCard.title,
        FirstSaveRescueCard.body,
        FirstSaveRescueCard.reassurance,
        FirstSaveRescueCard.ctaLabel,
        FirstSaveRescueCard.confidenceLine,
        FirstSaveRescueCard.oneSentenceLine,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'task',
        'homework',
        'must',
        'should',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnos',
        'definitely',
        'therapy',
        'treatment',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'rescue copy must not contain "$banned"',
        );
      }
      expect(copy, isNot(contains('voicememory')));
    });
  });

  group('First pressure win', () {
    testWidgets('first-win card renders its copy and CTA', (tester) async {
      var tapped = 0;
      await _pumpCard(
        tester,
        PressureFirstWinCard(onSeeMeaning: () => tapped++),
      );

      expect(find.text(PressureFirstWinCard.title), findsOneWidget);
      expect(find.text(PressureFirstWinCard.body), findsOneWidget);
      expect(find.text(PressureFirstWinCard.ctaLabel), findsOneWidget);

      await tester.tap(find.byKey(const Key('pressure_first_win_cta')));
      expect(tapped, 1);
    });

    testWidgets('first check-in shows first-win and CTA opens insights', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final dir = Directory('test/tmp/first_session_pressure_win');
        if (!await dir.exists()) await dir.create(recursive: true);
        final journalPath = '${dir.path}/journal.json';
        final prefsPath = '${dir.path}/prefs.json';
        for (final path in [
          journalPath,
          prefsPath,
          JournalStore.encryptedPathFor(journalPath),
        ]) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        await AppServices.resetForTest(
          journalPath: journalPath,
          prefsPath: prefsPath,
          skipRevenueCat: true,
        );
      });

      await tester.binding.setSurfaceSize(const Size(390, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PressureCheckInScreen(),
          ),
          GoRoute(
            path: '/pressure-insights',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('INSIGHTS_MARKER'))),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      await tester.tap(find.text("I couldn't stop even though I wanted to"));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pressure_quick_save_cta')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // First win replaces the generic quick-save success.
      expect(find.byKey(const Key('pressure_first_win_card')), findsOneWidget);
      expect(find.text(PressureFirstWinCard.title), findsOneWidget);
      expect(
        find.byKey(const Key('pressure_quick_save_success')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('pressure_first_win_cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('INSIGHTS_MARKER'), findsOneWidget);
    });
  });

  group('Pressure insights activation copy', () {
    testWidgets('empty state shows improved copy and CTA', (tester) async {
      await _pumpInsights(tester, records: const []);

      expect(
        find.byKey(const Key('pressure_insights_empty_state')),
        findsOneWidget,
      );
      expect(find.text(PressureInsightsEmptyState.title), findsOneWidget);
      expect(find.text(PressureInsightsEmptyState.body), findsOneWidget);
      expect(find.text(PressureInsightsEmptyState.ctaLabel), findsOneWidget);
      // The full insight cards are not shown without data.
      expect(
        find.byKey(const Key('pressure_loop_visibility_card')),
        findsNothing,
      );
    });

    testWidgets('early-signal nudge appears for one entry', (tester) async {
      await _pumpInsights(tester, records: [_record(id: 'a')]);

      expect(
        find.byKey(const Key('pressure_first_week_nudge')),
        findsOneWidget,
      );
      expect(find.text(PressureFirstWeekNudge.title), findsOneWidget);
      expect(find.text(PressureFirstWeekNudge.body), findsOneWidget);
    });

    testWidgets('early-signal nudge appears for two entries', (tester) async {
      await _pumpInsights(
        tester,
        records: [
          _record(id: 'a'),
          _record(id: 'b'),
        ],
      );
      expect(
        find.byKey(const Key('pressure_first_week_nudge')),
        findsOneWidget,
      );
    });

    testWidgets('nudge is gone once there are three or more entries', (
      tester,
    ) async {
      await _pumpInsights(
        tester,
        records: [
          _record(id: 'a'),
          _record(id: 'b'),
          _record(id: 'c'),
        ],
      );
      expect(find.byKey(const Key('pressure_first_week_nudge')), findsNothing);
    });
  });

  group('Record screen first-session ladder', () {
    late Directory tempDir;

    JournalEntry _usableEntry({String id = 'e1'}) => JournalEntry(
          id: id,
          createdAt: DateTime(2026, 6, 12, 12),
          transcript:
              'I felt pressure before saying yes again even when I was tired.',
          durationSeconds: 30,
          localAudioPath: '/tmp/$id.m4a',
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 2,
            recurringThemes: ['work'],
            exactLanguagePattern: '',
            concreteObservation: 'Work pressure showed up in this moment.',
            repeatedSignal: '',
          ),
        );

    JournalEntry _degradedEntry({String id = 'v1'}) => JournalEntry(
          id: id,
          createdAt: DateTime(2026, 6, 12, 12),
          transcript:
              '[draft] Recording saved locally — transcribe when connected',
          durationSeconds: 20,
          localAudioPath: '/tmp/$id.m4a',
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 0,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        );

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_first_session_ladder_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      await FirstSessionOnboardingStore.resetForTest();
      VisualAuditOverrides.setRecordPresentation(null);
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> seedEntries(WidgetTester tester, int count) async {
      if (count == 0) return;
      await tester.runAsync(() async {
        for (var i = 0; i < count; i++) {
          await AppServices.instance.journalStore.save(
            _usableEntry(id: 'seed_$i'),
          );
        }
      });
    }

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      int entryCount = 0,
    }) async {
      await seedEntries(tester, entryCount);
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
      await tester.binding.setSurfaceSize(const Size(390, 3200));
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
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    test('empty-archive gates hide competing Record cards at count 0', () {
      expect(
        RecordEmptyArchiveGates.showFirstUseSimplifiedRecord(
          loaded: true,
          entryCount: 0,
        ),
        isTrue,
      );
      expect(
        RecordEmptyArchiveGates.showDailyArchiveExerciseOnRecord(
          loaded: true,
          entryCount: 0,
        ),
        isFalse,
      );
      expect(
        RecordEmptyArchiveGates.showDailyArchiveExerciseOnRecord(
          loaded: true,
          entryCount: 4,
        ),
        isTrue,
      );
      expect(
        RecordEmptyArchiveGates.showTodaysQuestionOnRecord(
          loaded: true,
          entryCount: 0,
        ),
        isFalse,
      );
      expect(
        RecordEmptyArchiveGates.showDailyArchiveExerciseOnRecord(
          loaded: true,
          entryCount: 1,
        ),
        isFalse,
      );
      expect(
        RecordEmptyArchiveGates.showDailyArchiveExerciseOnRecord(
          loaded: true,
          entryCount: 4,
        ),
        isTrue,
      );
    });

    test('empty-archive gates retire legacy onboarding on the record screen', () {
      expect(
        RecordEmptyArchiveGates.showLegacyEmptyOnboarding(
          loaded: true,
          entryCount: 0,
        ),
        isFalse,
      );
      expect(
        RecordEmptyArchiveGates.showTwoDayActivationCard(
          loaded: true,
          entryCount: 0,
        ),
        isFalse,
      );
      expect(
        RecordEmptyArchiveGates.showBottomRetentionCards(
          loaded: true,
          entryCount: 0,
        ),
        isFalse,
      );
    });

    testWidgets('zero entries show simplified capture-first layout', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(find.byKey(const Key('record_first_run_screen_card')), findsOneWidget);
      expect(find.text(RecordFirstRunPromiseCopy.title), findsOneWidget);
      expect(find.byKey(const Key('first_session_onboarding_card')), findsNothing);
      expect(find.byKey(const Key('record_top_archive_promise_hero')), findsNothing);
      expect(find.byKey(const Key('record_first_use_capture_section')), findsNothing);
      expect(find.byKey(const Key('daily_archive_exercise_record_card')), findsNothing);
      expect(find.text("Today's map prompt"), findsNothing);
      expect(find.textContaining('private mind map'), findsNothing);
      expect(find.byKey(const Key('todays_one_question_card')), findsNothing);
      expect(find.text("Today's exercise"), findsNothing);
      expect(find.text("Today's one question"), findsNothing);
      expect(find.byKey(const Key('first_session_explanation_card')), findsNothing);
      expect(find.byKey(const Key('first_save_rescue_card')), findsNothing);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
      expect(find.byType(CaptureEntryActions), findsOneWidget);
      expect(find.text(MicrophonePermissionCopy.requestMicrophoneCta), findsOneWidget);
      expect(find.text(CaptureEntryActions.logPressureMomentLabel), findsNothing);
      expect(find.text(EmptyArchiveCopy.typeInsteadCta), findsOneWidget);
      expect(find.byKey(const Key('capture_how_it_works_link')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one entry ready stays capture-first without daily mirror card', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1);

      expect(find.text(DailyMirrorCopy.heardHeroTitle), findsNothing);
      expect(find.byKey(const Key('first_session_explanation_card')), findsNothing);
      expect(find.byKey(const Key('first_save_rescue_card')), findsNothing);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
      expect(find.byKey(const Key('daily_archive_exercise_record_card')), findsNothing);
      expect(
        find.byKey(const Key('low_evidence_guidance_card_oneRealEntry')),
        findsOneWidget,
      );
      expect(find.text(LowEvidenceCopy.oneEntryTitle), findsOneWidget);
      expect(find.text(LowEvidenceCopy.oneEntryBody), findsOneWidget);
      expect(find.byKey(const Key('early_first_signal_card_oneEntryReceipt')), findsNothing);
      expect(find.text(EarlyFirstSignalCopy.oneEntryTitle), findsNothing);
      expect(find.text(EarlyFirstSignalCopy.addMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    Future<void> pumpDoneState(
      WidgetTester tester, {
      required List<JournalEntry> entriesAfterSave,
      bool degradedVoicePostSave = false,
    }) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: entriesAfterSave,
          justSavedFirst:
              entriesAfterSave.length == 1 &&
              !VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.first),
          degradedVoicePostSave: degradedVoicePostSave,
          lastCaptureAnalysisSucceeded: !degradedVoicePostSave,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 3200));
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
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('first save post-save shows focused archive started stack', (
      tester,
    ) async {
      await pumpDoneState(tester, entriesAfterSave: [_usableEntry()]);

      expect(find.byKey(const Key('first_entry_saved_receipt_card')), findsOneWidget);
      expect(find.byKey(const Key('first_save_archive_started_card')), findsOneWidget);
      expect(find.text(RecordReturnProCopy.evidenceTitle), findsOneWidget);
      expect(find.text('Add one more moment'), findsOneWidget);
      expect(find.byKey(const Key('day_two_return_loop_card')), findsNothing);
      expect(find.byKey(const Key('day_two_return_preview_card')), findsNothing);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
      expect(find.text(ConsumerUiCopy.doneCta), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('degraded first save shows recovery not return loop', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: [_degradedEntry()],
        degradedVoicePostSave: true,
      );

      expect(find.text(PendingTranscriptRecoveryCopy.title), findsOneWidget);
      expect(find.text(PendingTranscriptRecoveryCopy.primaryAction), findsNWidgets(2));
      expect(find.byKey(const Key('day_two_return_loop_card')), findsNothing);
      expect(find.byKey(const Key('first_save_archive_started_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('good transcript post-save hides degraded recovery', (
      tester,
    ) async {
      await pumpDoneState(tester, entriesAfterSave: [_usableEntry()]);

      expect(find.text(PendingTranscriptRecoveryCopy.title), findsNothing);
      expect(find.byKey(const Key('first_save_archive_started_card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Two-day activation engine', () {
    const engine = TwoDayActivationEngine();
    final now = DateTime(2026, 6, 11, 9);
    final yesterday = DateTime(2026, 6, 10, 18);
    final threeDaysAgo = DateTime(2026, 6, 8, 18);
    final today = DateTime(2026, 6, 11, 8);

    test('day 1 plan for a brand-new user', () {
      final path = engine.build(entryCount: 0, now: now);
      expect(path.stage, TwoDayActivationStage.dayOneIntro);
      expect(path.title, 'Try ArchiveMe for 2 days');
      expect(path.lines, const [
        'Today: record one small thing.',
        'Tomorrow: check whether it returned, faded, or changed.',
        'That is enough.',
      ]);
    });

    test('day 1 complete only after the very first save', () {
      final first = engine.buildPostSave(entryCount: 1);
      expect(first.stage, TwoDayActivationStage.dayOneComplete);
      expect(first.title, 'Day 1 complete');
      expect(first.lines, const [
        'Tomorrow, ArchiveMe can compare this with what shows up next.',
        'Tomorrow\u2019s check is simple: did this return, fade, or change?',
      ]);
      expect(engine.buildPostSave(entryCount: 0).show, isFalse);
      expect(engine.buildPostSave(entryCount: 2).show, isFalse);
    });

    test('the return reason exists only in the day-1 closure stage', () {
      const reason = TwoDayActivationPath.dayOneReturnReasonLine;
      // Not before the first save.
      expect(
        engine.build(entryCount: 0, now: now).lines,
        isNot(contains(reason)),
      );
      // Not in the day-2 return moment.
      expect(
        engine.build(entryCount: 1, entryDates: [yesterday], now: now).lines,
        isNot(contains(reason)),
      );
      // Gone after the return moment and at 3+ entries.
      expect(
        engine
            .build(entryCount: 2, entryDates: [yesterday, today], now: now)
            .show,
        isFalse,
      );
      expect(
        engine
            .build(
              entryCount: 3,
              entryDates: [threeDaysAgo, yesterday, today],
              now: now,
            )
            .show,
        isFalse,
      );
    });

    test('day 2 return moment when yesterday holds the only save', () {
      final path = engine.build(
        entryCount: 1,
        entryDates: [yesterday],
        now: now,
      );
      expect(path.stage, TwoDayActivationStage.dayTwoReturn);
      expect(path.title, 'Day 2: check what changed');
      expect(path.lines, const [
        'See whether yesterday\u2019s thread returned, faded, or changed.',
      ]);
    });

    test('missed days get cautious copy, never guilt', () {
      final path = engine.build(
        entryCount: 1,
        entryDates: [threeDaysAgo],
        now: now,
      );
      expect(path.stage, TwoDayActivationStage.dayTwoReturn);
      expect(path.lines, const [
        'See whether an earlier recording returned, faded, or changed.',
      ]);
    });

    test('nothing on the day of the first save itself', () {
      final path = engine.build(entryCount: 1, entryDates: [today], now: now);
      expect(path.show, isFalse);
    });

    test('hides after the second-day return moment is complete', () {
      final path = engine.build(
        entryCount: 2,
        entryDates: [yesterday, today],
        now: now,
      );
      expect(path.show, isFalse);
    });

    test('hides at three or more entries', () {
      final path = engine.build(
        entryCount: 3,
        entryDates: [threeDaysAgo, yesterday, today],
        now: now,
      );
      expect(path.show, isFalse);
    });

    test('unreliable dates fall back to count-only cautious copy', () {
      final futureDate = now.add(const Duration(days: 2));
      for (final dates in [
        <DateTime>[],
        [futureDate],
      ]) {
        final path = engine.build(entryCount: 1, entryDates: dates, now: now);
        expect(path.stage, TwoDayActivationStage.dayTwoReturn);
        expect(path.lines, const [
          'See whether an earlier recording returned, faded, or changed.',
        ]);
      }
    });

    test('no streak, guilt, banned words, or VoiceMemory in the copy', () {
      final copy = [
        TwoDayActivationPath.dayOneTitle,
        ...TwoDayActivationPath.dayOneLines,
        TwoDayActivationPath.dayOneCompleteTitle,
        TwoDayActivationPath.dayOneCompleteLine,
        TwoDayActivationPath.dayOneReturnReasonLine,
        TwoDayActivationPath.dayTwoTitle,
        TwoDayActivationPath.dayTwoLine,
        TwoDayActivationPath.dayTwoCautiousLine,
      ].join(' ');
      final lower = copy.toLowerCase();
      for (final banned in const [
        'streak',
        'daily',
        'habit',
        'behind',
        'must',
        'should',
        'task',
        'homework',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnos',
        'definitely',
        'missed',
        'guilt',
        'come back',
        'every day',
        'don\u2019t break',
      ]) {
        expect(
          lower,
          isNot(contains(banned)),
          reason: '2-day path copy must not contain "$banned"',
        );
      }
      expect(copy, isNot(contains('VoiceMemory')));
    });
  });

  group('Two-day activation card', () {
    testWidgets('renders the day 1 plan with no buttons', (tester) async {
      const engine = TwoDayActivationEngine();
      await _pumpCard(
        tester,
        TwoDayActivationCard(
          path: engine.build(entryCount: 0, now: DateTime(2026, 6, 11)),
        ),
      );

      expect(find.byKey(const Key('two_day_activation_card')), findsOneWidget);
      expect(find.text('Try ArchiveMe for 2 days'), findsOneWidget);
      expect(find.text('Today: record one small thing.'), findsOneWidget);
      expect(
        find.text('Tomorrow: check whether it returned, faded, or changed.'),
        findsOneWidget,
      );
      expect(find.text('That is enough.'), findsOneWidget);
      // Passive card — no buttons, nothing to block or require.
      expect(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        findsNothing,
      );
    });

    testWidgets('renders nothing without a stage', (tester) async {
      await _pumpCard(
        tester,
        TwoDayActivationCard(path: TwoDayActivationPath.none()),
      );
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
    });

    testWidgets('day 1 closure coexists with the Done for today receipt', (
      tester,
    ) async {
      const twoDay = TwoDayActivationEngine();
      final receipt = const DoneForTodayReceiptEngine().build(
        saved: true,
        entryCount: 1,
        now: DateTime(2026, 6, 11, 12),
      );
      await _pumpCard(
        tester,
        Column(
          children: [
            DoneForTodayReceiptCard(receipt: receipt),
            const SizedBox(height: 16),
            TwoDayActivationCard(path: twoDay.buildPostSave(entryCount: 1)),
          ],
        ),
      );

      // Done for today still appears — the 2-day closure sits below it.
      final doneCard = find.byKey(const Key('done_for_today_receipt_card'));
      final twoDayCard = find.byKey(const Key('two_day_activation_card'));
      expect(doneCard, findsOneWidget);
      expect(find.text('Done for today'), findsOneWidget);
      expect(twoDayCard, findsOneWidget);
      expect(find.text('Day 1 complete'), findsOneWidget);
      expect(
        find.text(
          'Tomorrow, ArchiveMe can compare this with what shows up next.',
        ),
        findsOneWidget,
      );
      // The concrete return reason renders with day-1 closure, below the
      // Done for today receipt — never instead of it.
      expect(
        find.text(
          'Tomorrow\u2019s check is simple: did this return, fade, or change?',
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(doneCard).dy,
        lessThan(tester.getTopLeft(twoDayCard).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Record screen return-path gates', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_return_path_gates_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> seedEntries(List<DateTime> dates) async {
      for (var i = 0; i < dates.length; i++) {
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'seed_$i',
            createdAt: dates[i],
            transcript:
                'A long enough transcript to count as a saved reflection.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'Work pressure showed up again today.',
              repeatedSignal: 'signal',
            ),
          ),
        );
      }
    }

    Future<void> pumpRecordScreen(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3200));
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
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    test('two-day activation card gate opens only after comparison seed', () {
      expect(
        RecordEmptyArchiveGates.showTwoDayActivationCard(
          loaded: true,
          entryCount: 0,
        ),
        isFalse,
      );
      expect(
        RecordEmptyArchiveGates.showTwoDayActivationCard(
          loaded: true,
          entryCount: 1,
        ),
        isFalse,
      );
      expect(
        RecordEmptyArchiveGates.showTwoDayActivationCard(
          loaded: true,
          entryCount: 2,
        ),
        isTrue,
      );
    });

    testWidgets('zero and one entry ready screens hide two-day activation card', (
      tester,
    ) async {
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);

      await tester.runAsync(() async {
        await seedEntries([DateTime.now()]);
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
      expect(find.byType(CaptureEntryActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides once the archive holds three or more entries', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedEntries([
          DateTime.now().subtract(const Duration(days: 3)),
          DateTime.now().subtract(const Duration(days: 2)),
          DateTime.now().subtract(const Duration(days: 1)),
        ]);
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides after the second-day return moment is complete', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedEntries([
          DateTime.now().subtract(const Duration(days: 1)),
          DateTime.now(),
        ]);
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Invited user welcome', () {
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
      InvitedUserWelcome.resetSessionForTest();
    });

    tearDown(() {
      ActivationFunnelAnalytics.resetForTest();
      InvitedUserWelcome.resetSessionForTest();
    });

    test('source-specific copy is exact', () {
      expect(
        InvitedUserWelcome.titleFor('weekly_review'),
        'You were invited after a weekly review',
      );
      expect(
        InvitedUserWelcome.bodyFor('weekly_review'),
        'Start with one small recording. Later, ArchiveMe can compare what '
        'returned, faded, or changed.',
      );
      expect(
        InvitedUserWelcome.titleFor('thread_return'),
        'You were invited because a thread came back',
      );
      expect(
        InvitedUserWelcome.bodyFor('thread_return'),
        'Start with one small recording. ArchiveMe can help notice what '
        'keeps returning.',
      );
      expect(
        InvitedUserWelcome.titleFor('belief_distance'),
        'You were invited because something kept showing up',
      );
      expect(
        InvitedUserWelcome.bodyFor('belief_distance'),
        'Start with one small recording. ArchiveMe can help notice repeated '
        'phrases over time.',
      );
      expect(
        InvitedUserWelcome.titleFor('proof_counter'),
        'You were invited after recordings started connecting',
      );
      expect(
        InvitedUserWelcome.bodyFor('proof_counter'),
        'Start with one small recording. ArchiveMe can help connect '
        'evidence over time.',
      );
      expect(
        InvitedUserWelcome.titleFor('pro_retention_yes'),
        'You were invited by someone using ArchiveMe',
      );
      expect(
        InvitedUserWelcome.bodyFor('pro_retention_yes'),
        'Start with one small recording. ArchiveMe helps keep track of what '
        'returns, fades, or changes.',
      );
      // Unknown and default sources get the default copy.
      for (final source in const ['default', 'something_else', '']) {
        expect(
          InvitedUserWelcome.titleFor(source),
          'You were invited to try ArchiveMe',
        );
        expect(
          InvitedUserWelcome.bodyFor(source),
          'Start with one small recording. ArchiveMe helps notice what '
          'keeps returning, fading, or changing.',
        );
      }
      expect(InvitedUserWelcome.ctaLabel, 'Record one small thing');
      expect(InvitedUserWelcome.dismissLabel, 'Not now');
    });

    test('no banned words, promises, or VoiceMemory in any welcome copy', () {
      final copy = [
        InvitedUserWelcome.defaultTitle,
        InvitedUserWelcome.defaultBody,
        InvitedUserWelcome.weeklyReviewTitle,
        InvitedUserWelcome.weeklyReviewBody,
        InvitedUserWelcome.threadReturnTitle,
        InvitedUserWelcome.threadReturnBody,
        InvitedUserWelcome.beliefDistanceTitle,
        InvitedUserWelcome.beliefDistanceBody,
        InvitedUserWelcome.proofCounterTitle,
        InvitedUserWelcome.proofCounterBody,
        InvitedUserWelcome.proRetentionTitle,
        InvitedUserWelcome.proRetentionBody,
        InvitedUserWelcome.ctaLabel,
        InvitedUserWelcome.dismissLabel,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'streak',
        'daily',
        'habit',
        'guilt',
        'missed',
        'must',
        'should',
        'task',
        'homework',
        'diagnos',
        'therapy',
        'treatment',
        'problem',
        'fix',
        'failure',
        'lazy',
        'weak',
        // Never a promise of results.
        'definitely',
        'will find',
        'voicememory',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'welcome copy must not contain "$banned"',
        );
      }
    });

    test('shows only before the first save and once per session', () {
      expect(InvitedUserWelcome.shouldShow(entryCount: 0), isTrue);
      expect(InvitedUserWelcome.shouldShow(entryCount: 1), isFalse);
      expect(InvitedUserWelcome.shouldShow(entryCount: 5), isFalse);
      InvitedUserWelcome.shownThisSession = true;
      expect(InvitedUserWelcome.shouldShow(entryCount: 0), isFalse);
    });

    testWidgets('card renders copy with CTA into the existing flow', (
      tester,
    ) async {
      var recorded = 0;
      await _pumpCard(
        tester,
        InvitedUserWelcomeCard(
          source: 'thread_return',
          onRecord: () => recorded++,
          onDismiss: () {},
        ),
      );

      expect(
        find.text('You were invited because a thread came back'),
        findsOneWidget,
      );
      expect(find.text(InvitedUserWelcome.ctaLabel), findsOneWidget);
      expect(find.text(InvitedUserWelcome.dismissLabel), findsOneWidget);

      await tester.tap(find.byKey(const Key('invited_user_welcome_cta')));
      expect(recorded, 1);
      expect(InvitedUserWelcome.startedFromWelcomeThisSession, isTrue);
      expect(InvitedUserWelcome.sessionSource, 'thread_return');

      final seen = eventsNamed(
        ActivationFunnelAnalytics.invitedUserWelcomeSeen,
      );
      expect(seen, hasLength(1));
      expect(seen.single.properties, {
        'source': 'thread_return',
        'entry_count': 0,
      });
      final tapped = eventsNamed(
        ActivationFunnelAnalytics.invitedUserWelcomeTapped,
      );
      expect(tapped, hasLength(1));
      expect(tapped.single.properties, {
        'source': 'thread_return',
        'entry_count': 0,
      });
    });

    testWidgets('payloads carry source and entry_count only — no referrer', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        InvitedUserWelcomeCard(
          source: 'weekly_review',
          onRecord: () {},
          onDismiss: () {},
        ),
      );
      await tester.tap(find.byKey(const Key('invited_user_welcome_cta')));

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(e.properties.keys.toSet(), {'source', 'entry_count'});
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        expect(flat, isNot(contains('voicememory')));
        expect(flat, isNot(contains('@')));
      }
    });

    testWidgets(
      'first save attribution fires only when the welcome CTA started it',
      (tester) async {
        final dir = Directory.systemTemp.createTempSync('vm_invited_save_');
        await tester.runAsync(() async {
          await AppServices.resetForTest(
            journalPath: '${dir.path}/journal.json',
          );
        });

        JournalEntry entry(String id) => JournalEntry(
          id: id,
          createdAt: DateTime(2026, 6, 11, 12),
          transcript:
              'A long enough transcript to count as a saved reflection.',
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

        // First save without the welcome flag: no attribution event.
        await tester.runAsync(
          () => AppServices.instance.journalStore.save(entry('e1')),
        );
        expect(
          eventsNamed(ActivationFunnelAnalytics.invitedUserFirstSave),
          isEmpty,
        );

        // Reset to an empty archive; flag set by the welcome CTA → fires.
        await tester.runAsync(() async {
          final dir2 = Directory.systemTemp.createTempSync('vm_invited_save2_');
          await AppServices.resetForTest(
            journalPath: '${dir2.path}/journal.json',
          );
        });
        InvitedUserWelcome.startedFromWelcomeThisSession = true;
        InvitedUserWelcome.sessionSource = 'proof_counter';
        await tester.runAsync(
          () => AppServices.instance.journalStore.save(entry('e2')),
        );
        final fired = eventsNamed(
          ActivationFunnelAnalytics.invitedUserFirstSave,
        );
        expect(fired, hasLength(1));
        expect(fired.single.properties, {
          'source': 'proof_counter',
          'entry_count': 1,
        });
        expect(InvitedUserWelcome.startedFromWelcomeThisSession, isFalse);
      },
    );
  });

  group('Invited user welcome on the record screen', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_invited_welcome_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      await FirstSessionOnboardingStore.resetForTest();
      ActivationFunnelAnalytics.resetForTest();
      InvitedUserWelcome.resetSessionForTest();
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
      ActivationFunnelAnalytics.resetForTest();
      InvitedUserWelcome.resetSessionForTest();
    });

    InviteAttributionStore storeWith({String? source}) {
      final prefs = _MemoryPrefs();
      if (source != null) {
        prefs.maps[InviteAttributionStore.prefsKey] = {
          'ref': 'archive_invite',
          'source': source,
        };
      }
      return InviteAttributionStore(prefs: prefs);
    }

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      required InviteAttributionStore store,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
              inviteAttributionStore: store,
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
      }
    }

    testWidgets(
      'empty archive uses simplified promise — invited welcome stays off record screen',
      (tester) async {
        await pumpRecordScreen(tester, store: storeWith(source: 'weekly_review'));

        expect(find.byKey(const Key('invited_user_welcome_card')), findsNothing);
        expect(find.byKey(const Key('first_session_explanation_card')), findsNothing);
        expect(find.byKey(const Key('record_first_run_screen_card')), findsOneWidget);
        expect(find.byType(CaptureEntryActions), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('hidden without attribution — simplified promise only', (tester) async {
      await pumpRecordScreen(tester, store: storeWith());

      expect(find.byKey(const Key('invited_user_welcome_card')), findsNothing);
      expect(find.byKey(const Key('first_session_explanation_card')), findsNothing);
      expect(find.byKey(const Key('record_first_run_screen_card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hidden after the first save', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'e1',
            createdAt: DateTime(2026, 6, 1, 12),
            transcript:
                'A long enough transcript to count as a saved reflection.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'Work pressure showed up again today.',
              repeatedSignal: 'signal',
            ),
          ),
        );
      });
      await pumpRecordScreen(tester, store: storeWith(source: 'weekly_review'));

      expect(find.byKey(const Key('invited_user_welcome_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Invited Day 2 return copy', () {
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
      InvitedUserWelcome.resetSessionForTest();
      InviteFunnelMetrics.resetForTest();
    });

    tearDown(() {
      ActivationFunnelAnalytics.resetForTest();
      InvitedUserWelcome.resetSessionForTest();
      InviteFunnelMetrics.resetForTest();
    });

    test('source-specific copy is exact', () {
      expect(
        InvitedDayTwoReturn.titleFor('weekly_review'),
        'Start your own weekly thread',
      );
      expect(
        InvitedDayTwoReturn.bodyFor('weekly_review'),
        'See whether your first recording is beginning to return, fade, or '
        'change.',
      );
      expect(
        InvitedDayTwoReturn.titleFor('thread_return'),
        'Check whether it came back',
      );
      expect(
        InvitedDayTwoReturn.bodyFor('thread_return'),
        'ArchiveMe can help notice whether the same thread is showing up '
        'again.',
      );
      expect(
        InvitedDayTwoReturn.titleFor('belief_distance'),
        'Check what keeps showing up',
      );
      expect(
        InvitedDayTwoReturn.bodyFor('belief_distance'),
        'See whether a phrase or feeling from your first recording is '
        'appearing again.',
      );
      expect(
        InvitedDayTwoReturn.titleFor('proof_counter'),
        'Start connecting evidence',
      );
      expect(
        InvitedDayTwoReturn.bodyFor('proof_counter'),
        'A second recording can help ArchiveMe compare what is beginning to '
        'connect.',
      );
      expect(
        InvitedDayTwoReturn.titleFor('pro_retention_yes'),
        'Build your own archive',
      );
      expect(
        InvitedDayTwoReturn.bodyFor('pro_retention_yes'),
        'See whether your first recording returned, faded, or changed.',
      );
      // Unknown and default sources fall back to the default copy.
      for (final source in const ['default', 'something_else', '']) {
        expect(InvitedDayTwoReturn.titleFor(source), 'Your second check');
        expect(
          InvitedDayTwoReturn.bodyFor(source),
          'See whether your first recording returned, faded, or changed.',
        );
      }
      expect(InvitedDayTwoReturn.ctaLabel, 'Check now');
    });

    test('no banned words, referrer identity, or VoiceMemory in any copy', () {
      final copy = [
        InvitedDayTwoReturn.defaultTitle,
        InvitedDayTwoReturn.defaultBody,
        InvitedDayTwoReturn.weeklyReviewTitle,
        InvitedDayTwoReturn.weeklyReviewBody,
        InvitedDayTwoReturn.threadReturnTitle,
        InvitedDayTwoReturn.threadReturnBody,
        InvitedDayTwoReturn.beliefDistanceTitle,
        InvitedDayTwoReturn.beliefDistanceBody,
        InvitedDayTwoReturn.proofCounterTitle,
        InvitedDayTwoReturn.proofCounterBody,
        InvitedDayTwoReturn.proRetentionYesTitle,
        InvitedDayTwoReturn.proRetentionYesBody,
        InvitedDayTwoReturn.ctaLabel,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'streak',
        'daily',
        'habit',
        'guilt',
        'missed',
        'behind',
        'must',
        'should',
        'task',
        'homework',
        'diagnos',
        'therapy',
        'treatment',
        'problem',
        'fix',
        'failure',
        'lazy',
        'weak',
        // Never a referrer identity or old branding.
        'friend',
        'invited by',
        'voicememory',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'Day 2 copy must not contain "$banned"',
        );
      }
    });

    test('shows only with attribution and only in the Day 2 return stage', () {
      expect(
        InvitedDayTwoReturn.shouldShow(
          inviteSource: 'weekly_review',
          stage: TwoDayActivationStage.dayTwoReturn,
        ),
        isTrue,
      );
      // Non-invited users never see it.
      expect(
        InvitedDayTwoReturn.shouldShow(
          inviteSource: null,
          stage: TwoDayActivationStage.dayTwoReturn,
        ),
        isFalse,
      );
      // Never before the first save or after Day 2 is complete.
      for (final stage in const [
        TwoDayActivationStage.dayOneIntro,
        TwoDayActivationStage.dayOneComplete,
        TwoDayActivationStage.none,
      ]) {
        expect(
          InvitedDayTwoReturn.shouldShow(
            inviteSource: 'weekly_review',
            stage: stage,
          ),
          isFalse,
          reason: 'must not show in $stage',
        );
      }
    });

    test(
      'engine stages pin the gate: pre-first-save and post-Day-2 hide it',
      () {
        const engine = TwoDayActivationEngine();
        final now = DateTime(2026, 6, 11, 9);
        // Before the first save: day-one intro stage → hidden.
        expect(
          engine.build(entryCount: 0, now: now).stage,
          TwoDayActivationStage.dayOneIntro,
        );
        // Day 2 complete (entries on two distinct days) → hidden.
        expect(
          engine
              .build(
                entryCount: 2,
                entryDates: [
                  DateTime(2026, 6, 9, 18),
                  DateTime(2026, 6, 10, 18),
                ],
                now: now,
              )
              .stage,
          TwoDayActivationStage.none,
        );
        // The Day 2 return moment is the only visible stage.
        expect(
          engine
              .build(
                entryCount: 1,
                entryDates: [DateTime(2026, 6, 10, 18)],
                now: now,
              )
              .stage,
          TwoDayActivationStage.dayTwoReturn,
        );
      },
    );

    testWidgets('card renders exact copy and the CTA uses the existing flow', (
      tester,
    ) async {
      var checked = 0;
      await _pumpCard(
        tester,
        InvitedDayTwoReturnCard(
          source: 'thread_return',
          entryCount: 1,
          onCheck: () => checked++,
        ),
      );

      expect(find.text('Check whether it came back'), findsOneWidget);
      expect(
        find.text(
          'ArchiveMe can help notice whether the same thread is showing up '
          'again.',
        ),
        findsOneWidget,
      );
      expect(find.text(InvitedDayTwoReturn.ctaLabel), findsOneWidget);

      await tester.tap(find.byKey(const Key('invited_day_two_return_cta')));
      expect(checked, 1);

      final seen = eventsNamed(ActivationFunnelAnalytics.invitedDay2CopySeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties, {
        'source': 'thread_return',
        'entry_count': 1,
        'stage': 'day_2',
      });
      final tapped = eventsNamed(
        ActivationFunnelAnalytics.invitedDay2CopyTapped,
      );
      expect(tapped, hasLength(1));
      expect(tapped.single.properties, {
        'source': 'thread_return',
        'entry_count': 1,
        'stage': 'day_2',
      });
      // The normal Day 2 funnel keeps firing when this card replaces the
      // generic one.
      expect(
        eventsNamed(ActivationFunnelAnalytics.day2ReturnSeen),
        hasLength(1),
      );
    });

    testWidgets('analytics payloads are safe', (tester) async {
      await _pumpCard(
        tester,
        InvitedDayTwoReturnCard(
          source: 'proof_counter',
          entryCount: 2,
          onCheck: () {},
        ),
      );
      await tester.tap(find.byKey(const Key('invited_day_two_return_cta')));

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(
          e.properties.keys.toSet().difference(const {
            'source',
            'entry_count',
            'stage',
          }),
          isEmpty,
          reason: '${e.event} carries a non-whitelisted key',
        );
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        expect(flat, isNot(contains('https://')));
        expect(flat, isNot(contains('@')));
        expect(flat, isNot(contains('voicememory')));
      }
    });
  });

  group('Invited Day 2 return copy on the record screen', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_invited_day2_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      await FirstSessionOnboardingStore.resetForTest();
      ActivationFunnelAnalytics.resetForTest();
      InvitedUserWelcome.resetSessionForTest();
      InviteFunnelMetrics.resetForTest();
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
      ActivationFunnelAnalytics.resetForTest();
      InvitedUserWelcome.resetSessionForTest();
      InviteFunnelMetrics.resetForTest();
    });

    InviteAttributionStore storeWith({String? source}) {
      final prefs = _MemoryPrefs();
      if (source != null) {
        prefs.maps[InviteAttributionStore.prefsKey] = {
          'ref': 'archive_invite',
          'source': source,
        };
      }
      return InviteAttributionStore(prefs: prefs);
    }

    Future<void> saveEntry(
      WidgetTester tester, {
      required String id,
      required DateTime createdAt,
    }) {
      return tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: id,
            createdAt: createdAt,
            transcript:
                'A long enough transcript to count as a saved reflection.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'Work pressure showed up again today.',
              repeatedSignal: 'signal',
            ),
          ),
        );
      });
    }

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      required InviteAttributionStore store,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
              inviteAttributionStore: store,
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
      }
    }

    testWidgets(
      'one entry ready hides invited and generic day-two cards on record screen',
      (tester) async {
        await saveEntry(
          tester,
          id: 'e1',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        await pumpRecordScreen(tester, store: storeWith(source: 'weekly_review'));

        expect(find.byKey(const Key('invited_day_two_return_card')), findsNothing);
        expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
        expect(find.byType(CaptureEntryActions), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('non-invited users also hide generic Day 2 card before two entries', (
      tester,
    ) async {
      await saveEntry(
        tester,
        id: 'e1',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await pumpRecordScreen(tester, store: storeWith());

      expect(find.byKey(const Key('invited_day_two_return_card')), findsNothing);
      expect(find.byKey(const Key('two_day_activation_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hidden before the first save', (tester) async {
      await pumpRecordScreen(tester, store: storeWith(source: 'weekly_review'));

      expect(find.byKey(const Key('invited_day_two_return_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hidden after Day 2 is complete', (tester) async {
      await saveEntry(
        tester,
        id: 'e1',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await saveEntry(
        tester,
        id: 'e2',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await pumpRecordScreen(tester, store: storeWith(source: 'weekly_review'));

      expect(find.byKey(const Key('invited_day_two_return_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('No VoiceMemory consumer copy', () {
    testWidgets('first-session surfaces never show VoiceMemory', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        Column(
          children: [
            FirstSessionExplanationCard(onLogPressure: () {}, onRecord: () {}),
            PressureFirstWinCard(onSeeMeaning: () {}),
            PressureInsightsEmptyState(onLogPressure: () {}),
            const PressureFirstWeekNudge(),
          ],
        ),
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });
}
