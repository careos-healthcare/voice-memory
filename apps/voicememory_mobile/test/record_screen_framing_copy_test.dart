import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/daily_return_suggestion_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/personal_return_prompt_model.dart';
import 'package:voicememory_mobile/features/return_changes/archive_return_changes_copy.dart';
import 'package:voicememory_mobile/features/activation/day_two_return_loop_payoff.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_copy.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_gates.dart';
import 'package:voicememory_mobile/features/early_archive/archive_summary_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';
import 'package:voicememory_mobile/features/early_archive/daily_return_reason_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_copy.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_copy.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_copy.dart';
import 'package:voicememory_mobile/features/early_archive/weekly_archive_review_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/one_small_recording_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/record/daily_mirror_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/pressure_retention/one_small_recording_model.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_return_reminder_copy.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/record_screen_close_button.dart';

import 'support/memory_pressure_stores.dart';

JournalEntry _entry({
  required String id,
  DateTime? createdAt,
  String? transcript,
}) =>
    JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
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

List<JournalEntry> _confirmedRepeatJournalEntries(int count) {
  final transcripts = [
    'I had no capacity but I said yes again to the extra meeting today.',
    'Same thing — said yes when I had no capacity for one more thing.',
    'I said yes again even though I had no capacity for one more ask.',
    'I said yes again even though I had no capacity for one more ask today.',
    'Same pressure — said yes again before I checked whether I had capacity.',
  ];
  return List.generate(
    count,
    (i) => _entry(
      id: 'repeat_$i',
      transcript: transcripts[i % transcripts.length],
      createdAt: DateTime(2026, 6, 10 + i, 12),
    ),
  );
}

Future<void> seedConfirmedRepeatEntries(
  WidgetTester tester,
  int count,
) async {
  await tester.runAsync(() async {
    for (final entry in _confirmedRepeatJournalEntries(count)) {
      await AppServices.instance.journalStore.save(entry);
    }
  });
}

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          '[draft] Recording saved locally — transcribe when connected',
      durationSeconds: 20,
      localAudioPath: '/tmp/audio.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

List<PressureCheckInRecord> _workThread3() => [
  PressureCheckInRecord(
    entryId: 'a',
    createdAt: DateTime(2026, 6, 2, 12),
    optionId: 'could_not_stop',
    contextIds: const ['work'],
    transcript: 'pressure moment',
  ),
  PressureCheckInRecord(
    entryId: 'b',
    createdAt: DateTime(2026, 6, 4, 12),
    optionId: 'could_not_stop',
    contextIds: const ['work'],
    fear: 'The deadline slipping',
    transcript: 'pressure moment',
  ),
  PressureCheckInRecord(
    entryId: 'c',
    createdAt: DateTime(2026, 6, 9, 12),
    optionId: 'could_not_stop',
    contextIds: const ['work'],
    fear: 'I kept checking messages after I wanted to stop.',
    transcript: 'pressure moment',
  ),
];

/// Collects user-visible strings from [Text] widgets on screen.
List<String> _visibleTextOnScreen(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final data = widget.data;
    if (data != null && data.isNotEmpty) {
      texts.add(data);
    }
  }
  return texts;
}

void _expectNoBannedFirstImpressionCopy(WidgetTester tester) {
  final visible = _visibleTextOnScreen(tester);
  for (final phrase in RecordScreenFramingCopy.bannedFirstImpressionPhrases) {
    for (final text in visible) {
      expect(
        text.toLowerCase(),
        isNot(contains(phrase.toLowerCase())),
        reason: 'Banned first-impression phrase "$phrase" in "$text"',
      );
    }
  }
  for (final text in visible) {
    expect(
      RegExp(r'\bjourney\b', caseSensitive: false).hasMatch(text),
      isFalse,
      reason: 'Banned word "journey" in "$text"',
    );
    expect(
      RegExp(r'\bprogress\b', caseSensitive: false).hasMatch(text),
      isFalse,
      reason: 'Banned word "progress" in "$text"',
    );
  }
}

void main() {
  group('RecordScreenFramingCopy', () {
    test('uses concrete first-recording guidance', () {
      expect(RecordScreenFramingCopy.title, 'What is on your mind?');
      expect(
        RecordScreenFramingCopy.guidance,
        'Say one small thing from today.',
      );
    });

    test('first-use prompt copy is concrete and not diagnostic', () {
      expect(RecordFirstUsePromptCopy.title, 'Record one real moment');
      expect(
        RecordFirstUsePromptCopy.body,
        contains('what your mind said'),
      );
      expect(RecordFirstUsePromptCopy.examples, hasLength(4));
      expect(RecordFirstUsePromptCopy.footer, contains('Ten seconds'));
      for (final copy in [
        RecordFirstUsePromptCopy.title,
        RecordFirstUsePromptCopy.body,
        RecordFirstUsePromptCopy.footer,
        ...RecordFirstUsePromptCopy.examples,
      ]) {
        expect(copy.toLowerCase(), isNot(contains('therapy')));
        expect(copy.toLowerCase(), isNot(contains('diagnosis')));
      }
    });

    test('empty and started copy match the clean first-load spec', () {
      expect(RecordScreenFramingCopy.emptyArchiveTitle, 'Your archive is empty');
      expect(
        RecordScreenFramingCopy.emptyArchiveBody,
        'Record short moments. ArchiveMe spots what repeats.',
      );
      expect(
        RecordScreenFramingCopy.archiveStartedTitle,
        'Archive started',
      );
      expect(
        RecordScreenFramingCopy.archiveStartedBody,
        'ArchiveMe needs a second moment before it can compare what repeats.',
      );
    });

    test('does not include legacy abstract subheads', () {
      expect(RecordScreenFramingCopy.guidance, isNot(contains('Small things')));
      expect(
        RecordScreenFramingCopy.guidance,
        isNot(contains('ordinary moments')),
      );
      expect(
        RecordScreenFramingCopy.helperLine,
        isNot(contains('ordinary moments')),
      );
    });
  });

  group('RecordScreen framing UI', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_record_framing_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> seedEntries(WidgetTester tester, int count) async {
      if (count == 0) return;
      await tester.runAsync(() async {
        for (var i = 0; i < count; i++) {
          await AppServices.instance.journalStore.save(
            _entry(id: 'e$i', createdAt: DateTime(2026, 6, 1 + i, 12)),
          );
        }
      });
    }

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      int entryCount = 0,
      MemoryPressureCheckInStore? store,
      bool waitForOneSmallRecordingCard = false,
    }) async {
      await seedEntries(tester, entryCount);
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: store,
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
        if (waitForOneSmallRecordingCard &&
            find
                .byKey(const Key('one_small_recording_card'))
                .evaluate()
                .isNotEmpty) {
          return;
        }
      }
    }

    testWidgets('record screen avoids legacy empty framing copy', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(find.text('Small things become patterns.'), findsNothing);
      expect(
        find.text('The archive is built from ordinary moments.'),
        findsNothing,
      );
    });

    testWidgets('entry count 0 shows three-step promise not generic framing', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(find.byKey(const Key('record_top_archive_promise_hero')), findsOneWidget);
      for (final step in VisibleArchiveProofCopy.firstRunPromiseSteps) {
        expect(find.text(step), findsOneWidget);
      }
      expect(find.text(RecordScreenFramingCopy.title), findsNothing);
      expect(find.text(RecordScreenFramingCopy.guidance), findsNothing);
      expect(find.text(RecordScreenFramingCopy.emptyArchiveTitle), findsNothing);
    });

    testWidgets('entry count 0 shows How it works inside capture block', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(
        find.byKey(const Key('record_first_run_privacy_reassurance')),
        findsNothing,
      );
      expect(find.byKey(const Key('capture_how_it_works_link')), findsOneWidget);
      expect(
        find.text(RecordScreenFramingCopy.firstRunPrivacyLink),
        findsOneWidget,
      );
    });

    testWidgets('entry count 1 hides first-run privacy reassurance', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1);

      expect(
        find.text(RecordScreenFramingCopy.firstRunPrivacyTitle),
        findsNothing,
      );
      expect(
        find.textContaining('Nothing is sent unless you choose'),
        findsNothing,
      );
    });

    testWidgets('entry count 0 hides daily map so capture stays the only primary path', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(
        find.byKey(const Key('daily_archive_exercise_record_card')),
        findsNothing,
      );
      expect(find.text("Today's map prompt"), findsNothing);
      expect(find.text("Today's exercise"), findsNothing);
      expect(find.byKey(const Key('todays_one_question_card')), findsNothing);
      expect(find.text("Today's one question"), findsNothing);
    });

    testWidgets('entry count 0 exposes record_empty_gate debug marker when loaded', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(
        find.byKey(const ValueKey('record_empty_gate_0_true')),
        findsOneWidget,
      );
    });

    testWidgets('entry count 0 hides banned first-impression copy', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      _expectNoBannedFirstImpressionCopy(tester);
    });

    testWidgets('does not show progress cards before entry count load completes', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      _expectNoBannedFirstImpressionCopy(tester);
    });

    testWidgets('entry count 0 does not show One small recording', (
      tester,
    ) async {
      await pumpRecordScreen(
        tester,
        store: MemoryPressureCheckInStore(_workThread3()),
      );

      expect(find.text('One small recording'), findsNothing);
      expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
    });

    testWidgets('entry count 1 stays capture-first without daily mirror card', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1);

      expect(find.text(DailyMirrorCopy.heardHeroTitle), findsNothing);
      expect(find.text(DailyMirrorCopy.heardHeroBody), findsNothing);
      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
      expect(find.text(EmptyArchiveCopy.typeInsteadCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
      expect(find.text(ConsumerUiCopy.postSaveRecordAnother), findsNothing);
      _expectNoBannedFirstImpressionCopy(tester);
    });

    testWidgets('entry count 1 hides banned first-impression copy', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1);

      _expectNoBannedFirstImpressionCopy(tester);
    });

    testWidgets('entry count 1 does not show One small recording', (
      tester,
    ) async {
      await pumpRecordScreen(
        tester,
        entryCount: 1,
        store: MemoryPressureCheckInStore(_workThread3()),
      );

      expect(find.text('One small recording'), findsNothing);
      expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
    });

    testWidgets('entry count 2 stays capture-first without daily mirror cards', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 2);

      expect(
        find.text(FirstThreeSessionCopy.session2StartingToNoticeTitle),
        findsNothing,
      );
      expect(find.text(FirstThreeSessionCopy.journeyStep2), findsNothing);
      expect(find.byKey(const Key('early_behavior_loop_card')), findsNothing);
      expect(find.byKey(const Key('early_specific_insight_card')), findsNothing);
      expect(find.byKey(const Key('record_archive_weak_compare_card')), findsNothing);
      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
      expect(find.text(EmptyArchiveCopy.typeInsteadCta), findsOneWidget);
    });

    testWidgets('entry count 2 with shared words hides mirror cards on Record', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'a',
            createdAt: DateTime(2026, 6, 1, 12),
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
        );
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'b',
            createdAt: DateTime(2026, 6, 2, 12),
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'neutral',
              emotionalIntensity: 2,
              recurringThemes: [],
              exactLanguagePattern: '',
              concreteObservation: '',
              repeatedSignal: '',
            ),
          ),
        );
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'c',
            createdAt: DateTime(2026, 6, 3, 12),
            transcript:
                'I said yes again even though I had no capacity for one more ask.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'neutral',
              emotionalIntensity: 2,
              recurringThemes: [],
              exactLanguagePattern: '',
              concreteObservation: '',
              repeatedSignal: '',
            ),
          ),
        );
      });
      await pumpRecordScreen(tester);

      expect(find.byKey(const Key('early_behavior_loop_card')), findsNothing);
      expect(find.byKey(const Key('early_specific_insight_card')), findsNothing);
      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
    });

    testWidgets('entry count 2 with unrelated entries hides weak compare on Record', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'a',
            transcript:
                'Today I went for a long walk in the park near home after lunch.',
          ),
        );
        await AppServices.instance.journalStore.save(
          JournalEntry(
            id: 'b',
            createdAt: DateTime(2026, 6, 2, 12),
            transcript:
                'I cooked pasta for dinner and watched a film alone tonight.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'neutral',
              emotionalIntensity: 2,
              recurringThemes: [],
              exactLanguagePattern: '',
              concreteObservation: '',
              repeatedSignal: '',
            ),
          ),
        );
      });
      await pumpRecordScreen(tester);

      expect(find.byKey(const Key('record_archive_weak_compare_card')), findsNothing);
      expect(find.text(DailyMirrorCopy.weakStartedHeroBody), findsNothing);
      expect(find.text(DailyMirrorCopy.weakStartedFootnote), findsNothing);
      expect(find.byKey(const Key('early_behavior_loop_card')), findsNothing);
      expect(find.byKey(const Key('early_specific_insight_card')), findsNothing);
      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
    });

    testWidgets(
      'entry count 3 hides One small recording on Record ready state',
      (tester) async {
        await pumpRecordScreen(
          tester,
          entryCount: 3,
          store: MemoryPressureCheckInStore(_workThread3()),
          waitForOneSmallRecordingCard: true,
        );

        expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
        expect(find.text('One small recording'), findsNothing);
        expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
      },
    );

    testWidgets('iPad width shows top-right Close on Record screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1366));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpRecordScreen(tester);

      expect(find.byKey(const Key('record_screen_close')), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    });

  });

  group('Record CTA permission policy', () {
    test('main record CTA uses request path before first microphone denial', () {
      expect(
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
        ),
        RecordCtaAction.requestPermission,
      );
    });

    test('loop record CTA uses open settings path when permanently denied', () {
      expect(
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: true,
        ),
        RecordCtaAction.openSettings,
      );
      expect(
        RecordMicrophonePermissionUi.shouldHideCompetingRecordCtas(
          ui: RecordUiState.permissionBlocked,
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: true,
        ),
        isTrue,
      );
    });

    test('moment record CTA starts recording when microphone is granted', () {
      expect(
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: RecordingPhase.ready,
          userDeniedThisSession: false,
        ),
        RecordCtaAction.startRecording,
      );
    });

    test('blocked state keeps Type Instead path via permission panel policy', () {
      expect(
        RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
          ui: RecordUiState.permissionBlocked,
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: true,
        ),
        isTrue,
      );
      expect(
        RecordMicrophonePermissionUi.blockedPanelKind(
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: true,
        ),
        MicrophoneBlockedPanelKind.openSettings,
      );
    });

    test('ready UI keeps primary record copy available before blocked state', () {
      expect(
        RecordMicrophonePermissionUi.shouldHideCompetingRecordCtas(
          ui: RecordUiState.ready,
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
        ),
        isFalse,
      );
      expect(ConsumerUiCopy.recordOneMomentCta, 'Record one moment');
    });
  });

  group('Record screen unified CTA policy', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_record_cta_ui_');
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

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      int entryCount = 0,
      RecordUiState ui = RecordUiState.ready,
      bool degradedVoicePostSave = false,
      RecordingPhase? micPhase,
      bool? userDeniedThisSession,
      MemoryPressureCheckInStore? store,
      bool waitForOneSmallRecordingCard = false,
    }) async {
      if (entryCount > 0) {
        await tester.runAsync(() async {
          for (var i = 0; i < entryCount; i++) {
            await AppServices.instance.journalStore.save(
              degradedVoicePostSave
                  ? _degradedVoiceEntry(id: 'v$i')
                  : _entry(id: 'e$i', createdAt: DateTime(2026, 6, 1 + i, 12)),
            );
          }
        });
      }
      final auditEntriesAfterSave = degradedVoicePostSave && entryCount > 0
          ? List.generate(entryCount, (i) => _degradedVoiceEntry(id: 'v$i'))
          : (ui == RecordUiState.done && entryCount > 0
              ? List.generate(
                  entryCount,
                  (i) => _entry(
                    id: 'e$i',
                    createdAt: DateTime(2026, 6, 1 + i, 12),
                  ),
                )
              : null);
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: ui,
          degradedVoicePostSave: degradedVoicePostSave,
          justSavedFirst:
              ui == RecordUiState.done &&
              entryCount == 1 &&
              !degradedVoicePostSave,
          entriesAfterSave: auditEntriesAfterSave,
          micPhase: micPhase,
          userDeniedThisSession: userDeniedThisSession,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: store,
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
        if (waitForOneSmallRecordingCard &&
            find
                .byKey(const Key('one_small_recording_card'))
                .evaluate()
                .isNotEmpty) {
          return;
        }
      }
    }

    testWidgets('first-use shows one voice-start CTA: Save one moment', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(
        find.byKey(const Key('record_top_archive_promise_hero')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('record_first_use_capture_section')), findsOneWidget);
      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.firstUseCaptureCta), findsOneWidget);
      expect(find.byKey(const Key('daily_archive_exercise_record_primary_button')), findsNothing);
      expect(find.text(ConsumerUiCopy.recordOneMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
      expect(find.text(ConsumerUiCopy.postSaveRecordAnother), findsNothing);
      expect(find.text(CaptureEntryActions.logPressureMomentLabel), findsNothing);
    });

    testWidgets('first-use prompt appears at entryCount 0 with examples', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(find.byKey(const Key('record_first_use_prompt_block')), findsOneWidget);
      expect(find.text(RecordFirstUsePromptCopy.title), findsOneWidget);
      expect(find.text(RecordFirstUsePromptCopy.body), findsOneWidget);
      expect(find.text(RecordFirstUsePromptCopy.examplesHeading), findsOneWidget);
      expect(find.text(RecordFirstUsePromptCopy.footer), findsOneWidget);
      for (final example in RecordFirstUsePromptCopy.examples) {
        expect(find.text(example), findsOneWidget);
      }
      expect(find.byKey(const Key('daily_archive_exercise_record_card')), findsNothing);
    });

    testWidgets('first-use prompt hides after first entry', (tester) async {
      await pumpRecordScreen(tester, entryCount: 1);

      expect(find.byKey(const Key('record_first_use_prompt_block')), findsNothing);
      expect(find.byKey(const Key('record_first_use_capture_section')), findsNothing);
      expect(find.text(RecordFirstUsePromptCopy.title), findsNothing);
    });

    testWidgets('first-use keeps single Record CTA with prompt block', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(find.text(VisibleArchiveProofCopy.firstUseCaptureCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordOneMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
    });

    testWidgets('first-use does not show legacy generic framing copy', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(find.text(RecordScreenFramingCopy.title), findsNothing);
      expect(find.text(RecordScreenFramingCopy.guidance), findsNothing);
      _expectNoBannedFirstImpressionCopy(tester);
    });

    testWidgets('simulator deniedCanAskAgain with recorder access shows Record moment', (
      tester,
    ) async {
      await pumpRecordScreen(
        tester,
        entryCount: 2,
        micPhase: RecordingPhase.permissionDenied,
        userDeniedThisSession: false,
      );

      expect(find.text(MicrophonePermissionCopy.allowMicrophoneCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
    });

    testWidgets('returning user shows one voice-start CTA: Record moment', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 2);

      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordOneMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
      expect(find.text(DailyMirrorCopy.heardPrimaryCta), findsNothing);
    });

    testWidgets('recording shows only Stop recording as voice action', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1, ui: RecordUiState.recording);

      expect(find.text(ConsumerUiCopy.stopRecordingCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordOneMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
    });

    testWidgets('first-entry post-save shows focused receipt and archive card', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1, ui: RecordUiState.done);

      expect(find.text(VoiceCaptureCopy.recordingSavedTitle), findsOneWidget);
      expect(find.text(VoiceCaptureCopy.firstSaveReceiptNote), findsOneWidget);
      expect(find.text(RecordReturnProCopy.evidenceTitle), findsOneWidget);
      expect(find.text(RecordReturnProCopy.evidenceBody), findsOneWidget);
      expect(find.text(RecordReturnProCopy.evidenceSecondLine), findsOneWidget);
      expect(find.text(RecordReturnProCopy.evidenceViewArchive), findsOneWidget);
      expect(find.text('Add one more moment'), findsOneWidget);
      expect(find.text(EarlyArchiveReturnReminderCopy.title), findsNothing);
      expect(find.text(DayTwoReturnLoopPayoffCopy.oneEntryBody), findsNothing);
      expect(find.text(ConsumerUiCopy.makeResultMoreUsefulCta), findsNothing);
      expect(find.byKey(const Key('day_two_return_loop_card')), findsNothing);
      expect(find.byKey(const Key('first_entry_saved_receipt_card')), findsOneWidget);
      expect(find.byKey(const Key('first_save_archive_started_card')), findsOneWidget);
      expect(
        find.byKey(const Key('post_save_return_handoff_card_afterFirstSave')),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveReturnHandoffCopy.afterFirstSaveTitle),
        findsOneWidget,
      );
      expect(find.byKey(const Key('early_repeat_progress_card_oneMoment')), findsNothing);
    });

    testWidgets('entry 1 post-save with phrase shows phrase in handoff', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'e0',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
        );
      });
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          justSavedFirst: true,
          entriesAfterSave: [
            _entry(
              id: 'e0',
              transcript:
                  'I had no capacity but I said yes again to the extra meeting today.',
            ),
          ],
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(find.textContaining('said yes again'), findsOneWidget);
      expect(
        find.text(PostSaveReturnHandoffCopy.afterFirstSaveBodyFallback),
        findsNothing,
      );
    });

    testWidgets('entry 2 related post-save shows first proof handoff', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'a',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
        );
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'b',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
          ),
        );
      });
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: [
            _entry(
              id: 'a',
              transcript:
                  'I had no capacity but I said yes again to the extra meeting today.',
            ),
            _entry(
              id: 'b',
              transcript:
                  'Same thing — said yes when I had no capacity for one more thing.',
            ),
          ],
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(
        find.text(PostSaveReturnHandoffCopy.afterSecondSaveRelatedTitle),
        findsOneWidget,
      );
      expect(find.text(EarlyRepeatProgressCopy.twoRelatedTitle), findsNothing);
    });

    testWidgets('entry 2 unrelated post-save does not claim repeat', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'a',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
        );
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'b',
            transcript: 'Another unrelated note about errands this afternoon.',
          ),
        );
      });
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: [
            _entry(
              id: 'a',
              transcript: 'A quiet moment about lunch with a friend today.',
            ),
            _entry(
              id: 'b',
              transcript: 'Another unrelated note about errands this afternoon.',
            ),
          ],
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(
        find.text(PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedTitle),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveReturnHandoffCopy.afterSecondSaveRelatedTitle),
        findsNothing,
      );
    });

    testWidgets('entry 3 post-save hides return handoff', (tester) async {
      await seedConfirmedRepeatEntries(tester, 3);
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: _confirmedRepeatJournalEntries(3),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(find.byKey(const Key('post_save_return_handoff_card_afterFirstSave')), findsNothing);
      expect(
        find.byKey(const Key('post_save_return_handoff_card_afterSecondSaveRelated')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('post_save_return_handoff_card_afterSecondSaveUnrelated')),
        findsNothing,
      );
      expect(find.byKey(const Key('first_proof_moment_card')), findsOneWidget);
      expect(find.text(FirstProofMomentCopy.title), findsOneWidget);
      expect(find.byKey(const Key('archive_summary_card')), findsNothing);
      expect(find.text(ConsumerUiCopy.doneCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordAnotherCta), findsOneWidget);
    });

    testWidgets('third related post-save shows evidence chips', (tester) async {
      await seedConfirmedRepeatEntries(tester, 3);
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: _confirmedRepeatJournalEntries(3),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(find.byKey(const Key('first_proof_moment_evidence_phrases')), findsOneWidget);
      expect(find.textContaining('said yes'), findsWidgets);
    });

    testWidgets('third unrelated post-save hides first proof moment', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(id: 'a', transcript: 'A quiet moment about lunch with a friend today.'),
        );
        await AppServices.instance.journalStore.save(
          _entry(id: 'b', transcript: 'Another unrelated note about errands this afternoon.'),
        );
        await AppServices.instance.journalStore.save(
          _entry(id: 'c', transcript: 'A calm evening walk before bed tonight.'),
        );
      });
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: [
            _entry(id: 'a', transcript: 'A quiet moment about lunch with a friend today.'),
            _entry(id: 'b', transcript: 'Another unrelated note about errands this afternoon.'),
            _entry(id: 'c', transcript: 'A calm evening walk before bed tonight.'),
          ],
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(find.byKey(const Key('first_proof_moment_card')), findsNothing);
    });

    testWidgets('degraded third save hides first proof moment', (tester) async {
      await pumpRecordScreen(
        tester,
        entryCount: 3,
        ui: RecordUiState.done,
        degradedVoicePostSave: true,
      );

      expect(find.byKey(const Key('first_proof_moment_card')), findsNothing);
    });

    testWidgets('post-save success shows Done and Record another only', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1, ui: RecordUiState.done);

      expect(find.text(ConsumerUiCopy.doneCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordAnotherCta), findsOneWidget);
      expect(find.text('Add one more moment'), findsOneWidget);
      expect(find.text(DayTwoReturnLoopPayoffCopy.oneEntryBody), findsNothing);
      expect(find.text(ConsumerUiCopy.viewPatternsCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
    });

    testWidgets(
      'deniedCanAskAgain promotes capture CTAs without starter card on Record',
      (tester) async {
        await pumpRecordScreen(
          tester,
          entryCount: 3,
          store: MemoryPressureCheckInStore(_workThread3()),
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
          waitForOneSmallRecordingCard: true,
        );

        expect(find.byKey(const Key('one_small_recording_card')), findsNothing);
        expect(find.text(OneSmallRecording.recordCtaLabel), findsNothing);
        expect(find.text(MicrophonePermissionCopy.allowMicrophoneCta), findsNothing);
        expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
        expect(find.text(EmptyArchiveCopy.typeInsteadCta), findsOneWidget);
      },
    );

    testWidgets('Allow microphone CTA forwards tap to record handler', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CaptureEntryActions(
              recordButtonKey: const Key('capture_entry_record_cta'),
              recordButtonLabel: MicrophonePermissionCopy.allowMicrophoneCta,
              onRecord: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text(MicrophonePermissionCopy.allowMicrophoneCta), findsOneWidget);
      await tester.tap(find.byKey(const Key('capture_entry_record_cta')));
      expect(tapped, isTrue);
    });

    test('deniedCanAskAgain policy action requests permission', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.ready,
        entryCount: 2,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: false,
        micPhase: RecordingPhase.permissionDenied,
        micPermissionState: MicrophonePermissionState.deniedCanAskAgain,
      );
      expect(policy.primaryLabel, MicrophonePermissionCopy.allowMicrophoneCta);
      expect(policy.action, RecordCtaAction.requestPermission);
    });

    testWidgets('simulator permanently denied with recorder access shows Record moment', (
      tester,
    ) async {
      await pumpRecordScreen(
        tester,
        entryCount: 2,
        micPhase: RecordingPhase.permissionPermanentlyDenied,
        userDeniedThisSession: false,
      );

      expect(find.text(MicrophonePermissionCopy.openSettingsCta), findsNothing);
      expect(find.text(OneSmallRecording.recordCtaLabel), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
      expect(find.text(EmptyArchiveCopy.typeInsteadCta), findsOneWidget);
    });

    testWidgets('degraded post-save shows typed fallback without duplicate record CTAs', (
      tester,
    ) async {
      await pumpRecordScreen(
        tester,
        entryCount: 1,
        ui: RecordUiState.done,
        degradedVoicePostSave: true,
      );

      expect(find.text(VoiceCaptureCopy.degradedRecoveryTitle), findsOneWidget);
      expect(find.text(VoiceCaptureCopy.degradedRecoveryBody), findsOneWidget);
      expect(find.text(VoiceCaptureCopy.typeWhatYouSaid), findsOneWidget);
      expect(find.text(VoiceCaptureCopy.recordAgainCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.doneCta), findsOneWidget);
      expect(find.byKey(const Key('post_save_return_handoff_card_afterFirstSave')), findsNothing);
      expect(find.text(RecordReturnProCopy.evidenceTitle), findsNothing);
      expect(find.text(ConsumerUiCopy.viewPatternsCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
    });

    testWidgets('degraded first save does not show archive started payoff', (
      tester,
    ) async {
      await pumpRecordScreen(
        tester,
        entryCount: 1,
        ui: RecordUiState.done,
        degradedVoicePostSave: true,
      );

      expect(find.byKey(const Key('first_save_archive_started_card')), findsNothing);
      expect(
        VoiceCaptureQuality.isDegradedVoiceCapture(_degradedVoiceEntry()),
        isTrue,
      );
    });

    testWidgets('zero entries hides returning-user Today card', (tester) async {
      await pumpRecordScreen(tester);

      expect(find.byKey(const Key('returning_user_today_card')), findsNothing);
      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.firstUseCaptureCta), findsOneWidget);
    });

    testWidgets('one entry ready shows retention prompt without map clutter', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1);

      expect(find.byKey(const Key('returning_user_today_card')), findsNothing);
      expect(find.byKey(const Key('daily_archive_exercise_record_card')), findsNothing);
      expect(
        find.byKey(const Key('early_repeat_progress_card_oneMoment')),
        findsOneWidget,
      );
      expect(find.text(EarlyRepeatProgressCopy.oneMomentTitle), findsOneWidget);
      expect(find.text(EarlyRepeatProgressCopy.oneMomentBody), findsOneWidget);
      expect(
        find.text(EarlyRepeatProgressCopy.oneMomentProgress),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('early_first_signal_card_oneEntryReceipt')),
        findsNothing,
      );
      expect(find.text(EarlyFirstSignalCopy.oneEntryTitle), findsNothing);
      expect(
        find.byKey(const Key('early_repeat_progress_next_moment_cue_label')),
        findsOneWidget,
      );
      expect(find.text(EarlyRepeatProgressCopy.oneMomentCueLabel), findsOneWidget);
      expect(find.text(EarlyRepeatProgressCopy.oneMomentCueFooter), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
      expect(find.text(EarlyFirstSignalCopy.confirmRepeatCta), findsNothing);
    });

    testWidgets('post-save done state hides returning-user Today card', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1, ui: RecordUiState.done);

      expect(find.byKey(const Key('returning_user_today_card')), findsNothing);
    });

    testWidgets('zero entries hides next-moment prompt card', (tester) async {
      await pumpRecordScreen(tester);

      expect(find.byKey(const Key('next_moment_prompt_card')), findsNothing);
    });

    testWidgets('one entry ready hides next-moment prompt card', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1);

      expect(find.byKey(const Key('next_moment_prompt_card')), findsNothing);
      expect(find.byKey(const Key('daily_archive_exercise_record_card')), findsNothing);
      expect(
        find.byKey(const Key('early_repeat_progress_card_oneMoment')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('early_first_signal_card_oneEntryReceipt')),
        findsNothing,
      );
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
    });

    testWidgets('two related entries show repeat progress without extra CTA', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'a',
            createdAt: DateTime(2026, 6, 1, 12),
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
        );
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'b',
            createdAt: DateTime(2026, 6, 2, 12),
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
          ),
        );
      });
      await pumpRecordScreen(tester);

      expect(
        find.byKey(const Key('early_repeat_progress_card_twoRelated')),
        findsOneWidget,
      );
      expect(
        find.text(EarlyRepeatProgressCopy.twoRelatedProgress),
        findsOneWidget,
      );
      expect(find.text(EarlyRepeatProgressCopy.twoRelatedCueLabel), findsOneWidget);
      expect(find.text(EarlyRepeatProgressCopy.twoRelatedCueFooter), findsOneWidget);
      expect(find.text(EarlyFirstSignalCopy.confirmRepeatCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
    });

    testWidgets('two unrelated entries do not claim repeat forming', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'a',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
        );
        await AppServices.instance.journalStore.save(
          _entry(
            id: 'b',
            transcript: 'Another unrelated note about errands this afternoon.',
          ),
        );
      });
      await pumpRecordScreen(tester);

      expect(
        find.byKey(const Key('early_repeat_progress_card_twoUnrelated')),
        findsOneWidget,
      );
      expect(
        find.text(EarlyRepeatProgressCopy.twoUnrelatedTitle),
        findsOneWidget,
      );
      expect(
        find.text(EarlyRepeatProgressCopy.twoRelatedTitle),
        findsNothing,
      );
      expect(
        find.text(EarlyRepeatProgressCopy.twoRelatedProgress),
        findsNothing,
      );
      expect(find.text(EarlyRepeatProgressCopy.twoUnrelatedCueLabel), findsOneWidget);
      expect(find.text(EarlyRepeatProgressCopy.twoUnrelatedCueFooter), findsOneWidget);
    });

    testWidgets('three confirmed-repeat entries hide early progress card', (
      tester,
    ) async {
      await seedConfirmedRepeatEntries(tester, 3);
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(find.byKey(const Key('early_repeat_progress_card_oneMoment')), findsNothing);
      expect(find.byKey(const Key('early_repeat_progress_card_twoRelated')), findsNothing);
      expect(find.byKey(const Key('early_repeat_progress_card_twoUnrelated')), findsNothing);
      expect(find.byKey(const Key('archive_summary_card')), findsOneWidget);
    });

    testWidgets('three confirmed-repeat ready state shows first week loop', (
      tester,
    ) async {
      await seedConfirmedRepeatEntries(tester, 3);
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(find.byKey(const Key('first_week_loop_card')), findsOneWidget);
      expect(find.text(FirstWeekLoopCopy.title), findsOneWidget);
    });

    testWidgets('first proof post-save does not show first week loop card', (
      tester,
    ) async {
      await seedConfirmedRepeatEntries(tester, 3);
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: _confirmedRepeatJournalEntries(3),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(find.byKey(const Key('first_proof_moment_card')), findsOneWidget);
      expect(find.byKey(const Key('first_week_loop_card')), findsNothing);
    });

    testWidgets('fourth related post-save shows return check answer question', (
      tester,
    ) async {
      await seedConfirmedRepeatEntries(tester, 4);
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: _confirmedRepeatJournalEntries(4),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      expect(
        find.byKey(const Key('post_save_return_check_answer_card')),
        findsOneWidget,
      );
      expect(
        find.text(PostSaveReturnCheckAnswerCopy.title),
        findsOneWidget,
      );
      expect(find.byKey(const Key('return_check_payoff_card_unknown')), findsNothing);
      expect(find.byKey(const Key('repeat_return_check_card')), findsNothing);
      expect(find.byKey(const Key('archive_summary_card')), findsNothing);
      expect(find.text(ConsumerUiCopy.doneCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordAnotherCta), findsOneWidget);
    });

    testWidgets('tapping softer on return check answer shows softer payoff', (
      tester,
    ) async {
      await seedConfirmedRepeatEntries(tester, 4);
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: _confirmedRepeatJournalEntries(4),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
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

      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(const Key('post_save_return_check_answer_softer')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byKey(const Key('post_save_return_check_answer_card')), findsNothing);
      expect(find.byKey(const Key('return_check_payoff_card_softer')), findsOneWidget);
      expect(find.text(ReturnCheckPayoffCopy.softerTitle), findsOneWidget);
    });

    testWidgets('post-save done state hides next-moment prompt card', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 2, ui: RecordUiState.done);

      expect(find.byKey(const Key('next_moment_prompt_card')), findsNothing);
    });

    testWidgets('five entries show map prompt without archive review stack', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 5);

      expect(find.byKey(const Key('daily_archive_exercise_record_card')), findsOneWidget);
      expect(find.text("Today's map prompt"), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.returningUserFivePlusTitle), findsNothing);
      expect(find.byKey(const Key('returning_user_today_card')), findsNothing);
      expect(find.byKey(const Key('next_moment_prompt_card')), findsNothing);
      expect(find.text(VisibleArchiveProofCopy.nextMomentPromptSectionLabel), findsNothing);
      expect(find.byKey(const Key('todays_one_question_card')), findsNothing);
      expect(find.text("Today's one question"), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
    });

    testWidgets('ready state never stacks archive review with todays question', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 5);

      final hasArchiveReview =
          find.text(VisibleArchiveProofCopy.returningUserFivePlusTitle).evaluate().isNotEmpty;
      final hasTodaysQuestion = find.byKey(const Key('todays_one_question_card')).evaluate().isNotEmpty;

      expect(hasArchiveReview && hasTodaysQuestion, isFalse);
    });

    testWidgets('ten plus entries stay capture-first with at most one guidance card', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 12);

      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
      expect(find.text('Type instead'), findsOneWidget);

      expect(find.text(DailyReturnSuggestionSet.heading), findsNothing);
      expect(find.text(ConsumerUiCopy.trySayingOneOfThese), findsNothing);
      expect(
        find.text(PersonalReturnPromptSet.personalizedLabel),
        findsNothing,
      );
      expect(
        find.text(ArchiveReturnChangesCopy.weeklyReviewTitle),
        findsNothing,
      );
      expect(find.text(ArchiveDepthCopy.cardTitle), findsNothing);
      expect(find.text(ArchiveReturnChangesCopy.reviewChangesButton), findsNothing);
      expect(find.text(ArchiveReturnChangesCopy.viewEvidenceMapButton), findsNothing);
      expect(find.text(ArchiveReturnChangesCopy.markSeenButton), findsNothing);
      expect(
        find.text(ArchiveReturnChangesCopy.proPreviewLink),
        findsNothing,
      );
      expect(find.byKey(const Key('early_behavior_loop_card')), findsNothing);

      final guidanceCards = [
        find.byKey(const Key('daily_archive_exercise_record_card')),
        find.byKey(const Key('returning_user_today_card')),
        find.byKey(const Key('todays_one_question_card')),
        find.byKey(const Key('start_here_today_card')),
      ].map((f) => f.evaluate().length).fold<int>(0, (a, b) => a + b);

      expect(guidanceCards, lessThanOrEqualTo(1));
    });

    testWidgets('five confirmed-repeat entries show archive summary only', (
      tester,
    ) async {
      await seedConfirmedRepeatEntries(tester, 5);
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

      expect(find.byKey(const Key('archive_summary_card')), findsOneWidget);
      expect(find.text(ArchiveSummaryCopy.title), findsOneWidget);
      expect(
        find.byKey(const Key('confirmed_repeat_thought_map_card')),
        findsNothing,
      );
      expect(find.text(ConfirmedRepeatThoughtMapCopy.title), findsNothing);
      expect(
        find.byKey(const Key('weekly_archive_week_review_card')),
        findsNothing,
      );
      expect(find.text(WeeklyArchiveWeekReviewCopy.title), findsNothing);
      expect(find.byKey(const Key('private_archive_report_card')), findsNothing);
      expect(find.text(PrivateArchiveReportCopy.title), findsNothing);
      expect(
        find.text(EarlyFirstSignalCopy.threeEntrySeenThreeTimes),
        findsNothing,
      );
    });

    testWidgets('five confirmed-repeat entries cap proof cards below recorder', (
      tester,
    ) async {
      await seedConfirmedRepeatEntries(tester, 5);
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

      final proofCards = [
        find.byKey(const Key('archive_summary_card')),
        find.byKey(const Key('daily_return_reason_card')),
        find.byKey(const Key('pattern_changed_card')),
        find.byKey(const Key('repeat_return_check_change_proof_card')),
        find.byKey(const Key('confirmed_repeat_thought_map_card')),
        find.byKey(const Key('positive_reinforcement_card')),
        find.byKey(const Key('weekly_archive_week_review_card')),
        find.byKey(const Key('private_archive_report_card')),
        find.byKey(const Key('early_evidence_timeline_card')),
        find.byKey(const Key('early_first_signal_card_threeEntryConfirmedRepeat')),
      ]
          .map((finder) => finder.evaluate().length)
          .fold<int>(0, (total, count) => total + count);

      expect(proofCards, lessThanOrEqualTo(3));
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
    });
  });
}
