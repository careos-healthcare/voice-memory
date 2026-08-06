import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/trust/degraded_transcript_post_save_ui_gates.dart';
import 'package:voicememory_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/post_save_recorded_summary_card.dart';

JournalEntry _degradedVoiceEntry({
  String id = 'v1',
  String? localAudioPath = '/tmp/audio.m4a',
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
  durationSeconds: 20,
  localAudioPath: localAudioPath,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

void main() {
  group('DegradedTranscriptPostSaveUiGates', () {
    test('focused surface only for degraded post-save', () {
      expect(
        DegradedTranscriptPostSaveUiGates.showFocusedRecoverySurface(
          isDegradedPostSave: true,
        ),
        isTrue,
      );
      expect(
        DegradedTranscriptPostSaveUiGates.showFocusedRecoverySurface(
          isDegradedPostSave: false,
        ),
        isFalse,
      );
      expect(
        DegradedTranscriptPostSaveUiGates.suppressCompetingPostSaveCards(
          showFocusedRecoverySurface: true,
        ),
        isTrue,
      );
    });
  });

  group('Degraded transcript post-save card', () {
    testWidgets('shows one focused recovery card with required copy', (
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
      expect(find.text(VoiceCaptureCopy.recordAgainCta), findsOneWidget);
      expect(
        find.text(PendingTranscriptRecoveryCopy.moreOptionsLabel),
        findsOneWidget,
      );
      expect(find.text(PendingTranscriptRecoveryCopy.title), findsNothing);
      expect(find.text(PendingTranscriptRecoveryCopy.body), findsNothing);
    });

    testWidgets('audio tools and bluetooth note stay behind More options', (
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

      expect(find.text('Play recording'), findsNothing);
      expect(find.text('Share audio file'), findsNothing);
      expect(
        find.text(PendingTranscriptRecoveryCopy.bluetoothAccessoryNote),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('post_save_degraded_more_options')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post_save_play_recording')), findsOneWidget);
      expect(find.byKey(const Key('post_save_share_audio')), findsOneWidget);
      expect(
        find.text(PendingTranscriptRecoveryCopy.bluetoothAccessoryNote),
        findsOneWidget,
      );
    });
  });

  group('Record screen degraded transcript post-save', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_degraded_post_save_');
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

    Future<void> pumpDegradedPostSave(WidgetTester tester) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          degradedVoicePostSave: true,
          justSavedFirst: false,
          entriesAfterSave: [_degradedVoiceEntry()],
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: RecordScreen()),
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

    testWidgets('hides evidence, thought map, and done-for-today essay card', (
      tester,
    ) async {
      await pumpDegradedPostSave(tester);

      expect(
        find.text(PendingTranscriptRecoveryCopy.postSaveTitle),
        findsOneWidget,
      );
      expect(
        find.text(PendingTranscriptRecoveryCopy.primaryAction),
        findsOneWidget,
      );
      expect(find.text(VoiceCaptureCopy.recordAgainCta), findsOneWidget);
      expect(find.text(ConsumerUiCopy.doneCta), findsOneWidget);
      expect(
        find.byKey(const Key('post_save_view_evidence_cta')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('post_save_view_patterns_cta')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('post_save_add_one_more_moment_cta')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('done_for_today_receipt_card')),
        findsNothing,
      );
      expect(find.text('Done for today'), findsNothing);
    });
  });
}
