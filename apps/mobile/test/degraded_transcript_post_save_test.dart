import 'package:archiveme_mobile/features/trust/degraded_transcript_post_save_ui_gates.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/post_save_recorded_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';

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
        withAppProviderScope(
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
        withAppProviderScope(
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
}
