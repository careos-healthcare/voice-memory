import 'package:archiveme_mobile/features/post_save/moment_save_receipt_copy.dart';
import 'package:archiveme_mobile/features/post_save/moment_save_receipt_model.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/moment_save_receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({String transcript = 'I said yes again today.'}) =>
    JournalEntry(
      id: 'e1',
      createdAt: DateTime(2026, 8, 12),
      transcript: transcript,
      durationSeconds: 12,
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

JournalEntry _degradedEntry() => JournalEntry(
  id: 'd1',
  createdAt: DateTime(2026, 8, 12),
  transcript:
      '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
  durationSeconds: 12,
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

void main() {
  group('MomentSaveReceiptCard', () {
    testWidgets('first save shows one receipt with expected actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MomentSaveReceiptCard(
              entry: _entry(),
              entryCount: 1,
              onRecordAnother: () {},
              onViewArchive: () {},
              onCorrectText: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('moment_save_receipt_card')), findsOneWidget);
      expect(
        find.text(MomentSaveReceiptCopy.savedOnDeviceTitle),
        findsOneWidget,
      );
      expect(find.text('I said yes again today.'), findsOneWidget);
      expect(find.text(MomentSaveReceiptCopy.correctText), findsOneWidget);
      expect(find.text(MomentSaveReceiptCopy.recordAnother), findsOneWidget);
      expect(find.text(MomentSaveReceiptCopy.viewArchive), findsOneWidget);

      expect(find.textContaining('pattern'), findsNothing);
      expect(find.textContaining('proof'), findsNothing);
      expect(find.textContaining('confidence'), findsNothing);
    });

    testWidgets('remote failure shows retryable status without blocking save', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MomentSaveReceiptCard(
              entry: _entry(),
              entryCount: 1,
              remoteStatus: MomentSaveRemoteStatus.failedRetryable,
              onRecordAnother: () {},
              onViewArchive: () {},
              onRetryRemote: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(MomentSaveReceiptCopy.savedOnDeviceTitle),
        findsOneWidget,
      );
      expect(
        find.text(MomentSaveReceiptCopy.remoteProcessingFailed),
        findsOneWidget,
      );
      expect(
        find.text(MomentSaveReceiptCopy.remoteProcessingRetry),
        findsOneWidget,
      );
    });

    testWidgets(
      'degraded voice capture shows recovery body + type CTA, not transcript',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MomentSaveReceiptCard(
                entry: _degradedEntry(),
                entryCount: 1,
                onRecordAnother: () {},
                onViewArchive: () {},
                onTypeWhatYouSaid: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('moment_save_receipt_degraded_body')),
          findsOneWidget,
        );
        expect(
          find.text(PendingTranscriptRecoveryCopy.postSaveBody),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('moment_save_receipt_type_what_you_said')),
          findsOneWidget,
        );
        expect(find.text(VoiceCaptureCopy.typeWhatYouSaid), findsOneWidget);
        expect(
          find.byKey(const Key('moment_save_receipt_transcript')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'degraded voice capture hides type CTA when no handler is provided',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MomentSaveReceiptCard(
                entry: _degradedEntry(),
                entryCount: 1,
                onRecordAnother: () {},
                onViewArchive: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('moment_save_receipt_degraded_body')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('moment_save_receipt_type_what_you_said')),
          findsNothing,
        );
      },
    );

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no overflow at text scale $scale', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MomentSaveReceiptCard(
                    entry: _entry(
                      transcript:
                          'A longer moment about work pressure and saying yes '
                          'when I had no capacity left for one more thing.',
                    ),
                    entryCount: 1,
                    remoteStatus: MomentSaveRemoteStatus.failedRetryable,
                    onRecordAnother: () {},
                    onViewArchive: () {},
                    onRetryRemote: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('title is exposed for screen readers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MomentSaveReceiptCard(
              entry: _entry(),
              entryCount: 1,
              onRecordAnother: () {},
              onViewArchive: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const Key('moment_save_receipt_title')),
      );
      expect(semantics.hasFlag(SemanticsFlag.isHeader), isTrue);
    });
  });

  group('resolveMomentSaveRemoteStatus', () {
    test('local-only consent is not a failure state', () {
      expect(
        resolveMomentSaveRemoteStatus(
          analysisSucceeded: false,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
        ),
        MomentSaveRemoteStatus.none,
      );
    });

    test('analysis unavailable after consent is retryable', () {
      expect(
        resolveMomentSaveRemoteStatus(
          analysisSucceeded: false,
          syncNote: VoiceCaptureCopy.analysisUnavailableNote,
        ),
        MomentSaveRemoteStatus.failedRetryable,
      );
    });
  });
}
