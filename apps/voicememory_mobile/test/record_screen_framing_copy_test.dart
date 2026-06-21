import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_copy.dart';
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
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
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

    test('empty and started copy match the clean first-load spec', () {
      expect(RecordScreenFramingCopy.emptyArchiveTitle, 'Your archive is empty');
      expect(
        RecordScreenFramingCopy.emptyArchiveBody,
        'Record one moment to begin.',
      );
      expect(
        RecordScreenFramingCopy.archiveStartedTitle,
        'Archive started',
      );
      expect(
        RecordScreenFramingCopy.archiveStartedBody,
        'Add one more moment so ArchiveMe can begin comparing.',
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

    testWidgets('entry count 0 shows Your archive is empty', (tester) async {
      await pumpRecordScreen(tester);

      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
      expect(find.text(RecordScreenFramingCopy.guidance), findsOneWidget);
      expect(find.text(RecordScreenFramingCopy.emptyArchiveTitle), findsOneWidget);
      expect(find.text(RecordScreenFramingCopy.emptyArchiveBody), findsOneWidget);
      expect(
        find.text(RecordScreenFramingCopy.emptyArchiveFootnote),
        findsOneWidget,
      );
    });

    testWidgets('entry count 0 shows first-run privacy reassurance', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(
        find.text(RecordScreenFramingCopy.firstRunPrivacyTitle),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nothing is sent unless you choose'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('record_first_run_privacy_reassurance')),
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

    testWidgets('entry count 1 shows Archive started without duplicate record CTA', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1);

      expect(find.text(DailyMirrorCopy.heardHeroTitle), findsOneWidget);
      expect(find.text(DailyMirrorCopy.heardHeroBody), findsOneWidget);
      expect(find.text(DailyMirrorCopy.heardPrimaryCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
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

    testWidgets('entry count 2 shows early compare not starting to notice', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 2);

      expect(
        find.text(FirstThreeSessionCopy.session2StartingToNoticeTitle),
        findsNothing,
      );
      expect(find.text(FirstThreeSessionCopy.journeyStep2), findsNothing);
      expect(
        find.byKey(const Key('early_behavior_loop_card')).evaluate().isNotEmpty ||
            find.byKey(const Key('early_specific_insight_card')).evaluate().isNotEmpty ||
            find
                .byKey(const Key('record_archive_weak_compare_card'))
                .evaluate()
                .isNotEmpty,
        isTrue,
      );
    });

    testWidgets('entry count 2 with shared words prefers behaviour loop card', (
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
      });
      await pumpRecordScreen(tester);

      expect(find.byKey(const Key('early_behavior_loop_card')), findsOneWidget);
      expect(find.text('This looks like a capacity loop'), findsOneWidget);
      expect(
        find.text(
          'Pressure shows up, then you say yes before checking your capacity.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('early_specific_insight_card')), findsNothing);
    });

    testWidgets('entry count 2 with unrelated entries shows weak compare', (
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

      expect(find.byKey(const Key('record_archive_weak_compare_card')), findsOneWidget);
      expect(find.text(DailyMirrorCopy.weakStartedHeroBody), findsOneWidget);
      expect(find.text(DailyMirrorCopy.weakStartedFootnote), findsOneWidget);
      expect(find.byKey(const Key('early_behavior_loop_card')), findsNothing);
      expect(find.byKey(const Key('early_specific_insight_card')), findsNothing);
    });

    testWidgets(
      'entry count 3 can still show One small recording when evidence exists',
      (tester) async {
        await pumpRecordScreen(
          tester,
          entryCount: 3,
          store: MemoryPressureCheckInStore(_workThread3()),
          waitForOneSmallRecordingCard: true,
        );

        expect(find.byKey(const Key('one_small_recording_card')), findsOneWidget);
        expect(find.text('One small recording'), findsOneWidget);
        final expectedPrompt = const OneSmallRecordingEngine().build(
          _workThread3(),
          entryCount: 3,
        ).prompt;
        expect(find.text(expectedPrompt), findsOneWidget);
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

    test('loop record CTA uses blocked panel path when permanently denied', () {
      expect(
        RecordMicrophonePermissionUi.recordCtaAction(
          micPhase: RecordingPhase.permissionPermanentlyDenied,
          userDeniedThisSession: true,
        ),
        RecordCtaAction.routeToBlockedPanel,
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
              _entry(id: 'e$i', createdAt: DateTime(2026, 6, 1 + i, 12)),
            );
          }
        });
      }
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: ui,
          degradedVoicePostSave: degradedVoicePostSave,
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

    testWidgets('first-use shows one voice-start CTA: Record one moment', (
      tester,
    ) async {
      await pumpRecordScreen(tester);

      expect(find.text(ConsumerUiCopy.recordOneMomentCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
      expect(find.text(ConsumerUiCopy.postSaveRecordAnother), findsNothing);
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

    testWidgets('post-save success shows Done and Record another only', (
      tester,
    ) async {
      await pumpRecordScreen(tester, entryCount: 1, ui: RecordUiState.done);

      expect(find.text(ConsumerUiCopy.doneCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordAnotherCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.viewPatternsCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
    });

    testWidgets(
      'deniedCanAskAgain hides Record this on starter card and promotes Allow microphone',
      (tester) async {
        await pumpRecordScreen(
          tester,
          entryCount: 3,
          store: MemoryPressureCheckInStore(_workThread3()),
          micPhase: RecordingPhase.permissionDenied,
          userDeniedThisSession: false,
          waitForOneSmallRecordingCard: true,
        );

        expect(find.byKey(const Key('one_small_recording_card')), findsOneWidget);
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

      expect(find.text(VoiceCaptureCopy.typeWhatYouSaid), findsOneWidget);
      expect(find.text(VoiceCaptureCopy.recordAgainCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.doneCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.viewPatternsCta), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
      expect(find.text(ConsumerUiCopy.startRecording), findsNothing);
    });
  });
}
