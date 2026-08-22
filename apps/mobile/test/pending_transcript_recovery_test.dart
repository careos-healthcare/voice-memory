import 'dart:io';

import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_repeat_progress_model.dart';
import 'package:archiveme_mobile/features/early_archive/early_saved_moments_engine.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_analytics.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_gate.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/screens/record_screen.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/patterns/patterns_evidence_quality_fallback_view.dart';
import 'package:archiveme_mobile/widgets/patterns/patterns_transcript_pending_view.dart';
import 'package:archiveme_mobile/widgets/record/pending_transcript_recovery_sheet.dart';
import 'package:archiveme_mobile/widgets/record/post_save_recorded_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _typedCorrection =
    'I said yes when I had no capacity left today at work.';

JournalEntry _degradedVoiceEntry({
  String id = 'v1',
  String transcript = _placeholder,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: transcript,
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
  syncStatus: SyncStatus.pendingUpload,
);

void main() {
  late Directory tempDir;
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_pending_recovery_');
    await AppServices.resetForTest(journalPath: '${tempDir.path}/journal.json');
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest((event, props) {
      analyticsEvents.add((event: event, props: props));
    });
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    analyticsEvents.clear();
  });

  group('PendingTranscriptRecoveryCopy', () {
    test('spec copy is stable', () {
      expect(PendingTranscriptRecoveryCopy.title, 'Transcript pending');
      expect(
        PendingTranscriptRecoveryCopy.body,
        'This moment is saved, but ArchiveMe cannot compare it yet.',
      );
      expect(PendingTranscriptRecoveryCopy.primaryAction, 'Add what you said');
      expect(PendingTranscriptRecoveryCopy.saveButton, 'Save text');
    });
  });

  group('PendingTranscriptRecoveryGate', () {
    test('flags degraded voice without typed correction', () {
      expect(
        PendingTranscriptRecoveryGate.entryNeedsRecovery(_degradedVoiceEntry()),
        isTrue,
      );
    });

    test('clears after typed correction', () async {
      final degraded = _degradedVoiceEntry();
      await AppServices.instance.journalStore.save(degraded);
      final result = await AppServices.instance.pipeline
          .attachTypedTextToVoiceEntry(
            entry: degraded,
            transcript: _typedCorrection,
          );
      expect(
        PendingTranscriptRecoveryGate.entryNeedsRecovery(result.entry),
        isFalse,
      );
    });
  });

  group('PostSaveRecordedSummaryCard recovery', () {
    testWidgets('pending transcript post-save shows recovery copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _degradedVoiceEntry(),
              onAddWhatYouSaid: () {},
              onBackToRecord: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('post_save_degraded_transcription_card')),
        findsOneWidget,
      );
      expect(
        find.text(PendingTranscriptRecoveryCopy.postSaveTitle),
        findsOneWidget,
      );
      expect(
        find.text(PendingTranscriptRecoveryCopy.postSaveBody),
        findsOneWidget,
      );
      expect(
        find.text(PendingTranscriptRecoveryCopy.primaryAction),
        findsOneWidget,
      );
    });

    testWidgets('recovery sheet shows text input when opened', (tester) async {
      final entry = _degradedVoiceEntry();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PendingTranscriptRecoverySheet(
              entry: entry,
              source: 'test_post_save',
              entryCount: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pending_transcript_recovery_sheet')),
        findsOneWidget,
      );
      expect(
        find.text(PendingTranscriptRecoveryCopy.inputTitle),
        findsOneWidget,
      );
      expect(
        find.text(PendingTranscriptRecoveryCopy.inputHelper),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pending_transcript_recovery_input')),
        findsOneWidget,
      );
    });
  });

  group('PendingTranscriptRecoverySheet save', () {
    test('save failure copy is defined for sheet error state', () {
      expect(
        PendingTranscriptRecoveryCopy.saveFailed,
        'That text was not saved. Please try again.',
      );
    });
  });

  group('attachTypedTextToVoiceEntry recovery', () {
    test('attaches typed correction to existing pending entry', () async {
      final degraded = _degradedVoiceEntry();
      await AppServices.instance.journalStore.save(degraded);

      final result = await AppServices.instance.pipeline
          .attachTypedTextToVoiceEntry(
            entry: degraded,
            transcript: _typedCorrection,
          );

      expect(result.entry.id, 'v1');
      expect(result.entry.transcript, _typedCorrection);
      expect(result.entry.localAudioPath, '/tmp/audio.m4a');
      expect(result.attachedTypedTextToVoiceEntry, isTrue);
    });

    test(
      'typed correction makes entry comparable when quality gate allows',
      () async {
        final degraded = _degradedVoiceEntry();
        await AppServices.instance.journalStore.save(degraded);

        final result = await AppServices.instance.pipeline
            .attachTypedTextToVoiceEntry(
              entry: degraded,
              transcript: _typedCorrection,
            );

        final verdict = ArchiveEvidenceQuality.assess(result.entry);
        expect(verdict.allowsInsights, isTrue);
        expect(ArchiveEvidenceQualityGate.usableCount([result.entry]), 1);
      },
    );

    test(
      'placeholder draft alone stays blocked; corrected entry is usable',
      () {
        expect(
          ArchiveEvidenceQuality.assess(_degradedVoiceEntry()).allowsInsights,
          isFalse,
        );
        final corrected = _degradedVoiceEntry(transcript: _typedCorrection);
        expect(ArchiveEvidenceQuality.assess(corrected).allowsInsights, isTrue);
        expect(corrected.transcript, isNot(contains('[draft]')));
      },
    );

    test('repeated save does not create duplicate entry', () async {
      final degraded = _degradedVoiceEntry();
      await AppServices.instance.journalStore.save(degraded);

      await AppServices.instance.pipeline.attachTypedTextToVoiceEntry(
        entry: degraded,
        transcript: _typedCorrection,
      );
      final stored = await AppServices.instance.journalStore.getById('v1');
      await AppServices.instance.pipeline.attachTypedTextToVoiceEntry(
        entry: stored!,
        transcript: 'I updated what I said with more detail today.',
      );

      final all = await AppServices.instance.journalStore.loadAll();
      expect(all.length, 1);
      expect(all.single.id, 'v1');
    });

    test(
      'real typed correction enables early signal when gate allows',
      () async {
        final degraded = _degradedVoiceEntry();
        await AppServices.instance.journalStore.save(degraded);
        final result = await AppServices.instance.pipeline
            .attachTypedTextToVoiceEntry(
              entry: degraded,
              transcript: _typedCorrection,
            );

        final signal = EarlyFirstSignalEngine.build(entries: [result.entry]);
        expect(signal, isNotNull);
      },
    );
  });

  group('Patterns fallback recovery', () {
    testWidgets('pending transcript view offers recovery action', (
      tester,
    ) async {
      final entry = _degradedVoiceEntry();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternsTranscriptPendingView(
              recoverableEntry: entry,
              savedEntryId: entry.id,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(PendingTranscriptRecoveryCopy.title), findsOneWidget);
      expect(
        find.text(PendingTranscriptRecoveryCopy.primaryAction),
        findsOneWidget,
      );
    });

    testWidgets('weak evidence fallback offers recovery when pending exists', (
      tester,
    ) async {
      final entry = _degradedVoiceEntry();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternsEvidenceQualityFallbackView(
              recoverableEntry: entry,
              savedEntryId: entry.id,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(PendingTranscriptRecoveryCopy.primaryAction),
        findsOneWidget,
      );
    });
  });

  group('EarlySavedMomentsSheet recovery', () {
    test('engine marks pending entries for recovery in sheet content', () {
      final entry = _degradedVoiceEntry();
      const progress = EarlyRepeatProgressResult(
        kind: EarlyRepeatProgressKind.oneMoment,
        title: 'One moment saved',
        body: 'Body',
        progressLabel: '1 of 3',
        nextMomentCue: EarlyRepeatNextMomentCue(
          label: 'Next',
          body: 'Body',
          footer: 'Footer',
        ),
      );
      final content = EarlySavedMomentsEngine.build(
        entries: [entry],
        progress: progress,
      )!;

      expect(content.moments, hasLength(1));
      expect(content.moments.single.isPendingTranscript, isTrue);
      expect(content.moments.single.entryId, 'v1');
      expect(
        content.moments.single.previewText,
        PendingTranscriptRecoveryCopy.body,
      );
    });
  });

  group('RecordCtaPolicy recovery', () {
    test('degraded post-save uses Add what you said primary label', () {
      final policy = RecordCtaPolicy.resolve(
        ui: RecordUiState.done,
        entryCount: 1,
        entryCountLoaded: true,
        showPostSaveLoop: false,
        isDegradedVoiceSave: true,
        lastSavedEntry: _degradedVoiceEntry(),
      );

      expect(policy.state, RecordCtaPolicyState.postSaveDegraded);
      expect(policy.primaryLabel, PendingTranscriptRecoveryCopy.primaryAction);
    });
  });

  group('PendingTranscriptRecoveryAnalytics', () {
    test('tracks safe fields only — no user text', () {
      analyticsEvents.clear();

      PendingTranscriptRecoveryAnalytics.opened(
        source: 'test_source',
        entryCount: 1,
        hasParentEntry: true,
      );
      PendingTranscriptRecoveryAnalytics.saved(
        source: 'test_source',
        entryCount: 1,
        hasParentEntry: true,
      );

      final recoveryEvents = analyticsEvents
          .where(
            (e) =>
                e.event == PendingTranscriptRecoveryAnalytics.openedEvent ||
                e.event == PendingTranscriptRecoveryAnalytics.savedEvent,
          )
          .toList();

      expect(recoveryEvents.length, 2);
      for (final captured in recoveryEvents) {
        expect(
          captured.props.keys.every(
            ActivationFunnelAnalytics.allowedPropertyKeys.contains,
          ),
          isTrue,
        );
        expect(captured.props.containsKey('transcript'), isFalse);
        expect(captured.props.containsKey('text'), isFalse);
        expect(captured.props.containsKey('phrase'), isFalse);
        expect(captured.props['reason'], 'pending_transcript');
        expect(captured.props['source'], 'test_source');
        expect(captured.props['entry_count'], 1);
        expect(captured.props['has_parent_entry'], 1);
      }
      expect(recoveryEvents.map((e) => e.event), [
        PendingTranscriptRecoveryAnalytics.openedEvent,
        PendingTranscriptRecoveryAnalytics.savedEvent,
      ]);
    });
  });
}