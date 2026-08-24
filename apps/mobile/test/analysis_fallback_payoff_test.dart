import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/analysis_fallback_payoff.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/features/recording/recording_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/analysis_fallback_payoff_card.dart';
import 'package:archiveme_mobile/widgets/record/post_save_recorded_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/app_services_test_lifecycle.dart';
import 'support/test_storage_sandbox.dart';
import 'support/v1_moment_save_receipt_expectations.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
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

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => _voiceEntry(
  id: id,
  transcript:
      '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
);

const _bannedPatternWords = [
  'pattern found',
  'found a pattern',
  'pressure loop',
  'working hypothesis',
  'repeating loop',
];

const _bannedAiSuccessWords = [
  'ai insight',
  'deep analysis found',
  'analysis complete',
  'insight ready',
];

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

void _expectNoBannedCopy(Iterable<String> visible, List<String> banned) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in banned) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  group('AnalysisFallbackPayoffEngine', () {
    test('returns null when analysis succeeded', () {
      final payoff = AnalysisFallbackPayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
        analysisSucceeded: true,
      );
      expect(payoff, isNull);
    });

    test('returns null for degraded voice capture', () {
      final payoff = AnalysisFallbackPayoffEngine.build(
        entries: [_degradedVoiceEntry()],
        analysisSucceeded: false,
      );
      expect(payoff, isNull);
    });

    test('one entry uses cautious saved payoff copy', () {
      final payoff = AnalysisFallbackPayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
        analysisSucceeded: false,
      );

      expect(payoff, isNotNull);
      expect(payoff!.title, AnalysisFallbackPayoffCopy.title);
      expect(payoff.body, AnalysisFallbackPayoffCopy.bodyOneEntry);
      expect(payoff.evidenceLine, AnalysisFallbackPayoffCopy.evidenceOneEntry);
      expect(
        payoff.nextActionLine,
        AnalysisFallbackPayoffCopy.nextActionOneEntry,
      );
      expect(payoff.footnoteLine, AnalysisFallbackPayoffCopy.deferredFootnote);
      expect(payoff.secondaryLine, isNull);
      _expectNoBannedCopy(
        [payoff.title, payoff.body, payoff.evidenceLine],
        [..._bannedPatternWords, 'repeat', 'loop'],
      );
    });

    test('two entries defers to second-session payoff card', () {
      final payoff = AnalysisFallbackPayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I stayed late finishing slides for tomorrow morning.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript: 'My sister called about planning the weekend trip.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
        analysisSucceeded: false,
      );
      expect(payoff, isNull);
    });

    test('two entries with overlap still defer to second-session payoff', () {
      final payoff = AnalysisFallbackPayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure before saying yes again today at work.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript: 'Pressure showed up again before I said yes at work.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
        analysisSucceeded: false,
      );

      expect(payoff, isNull);
    });

    test('footnote defers analysis without claiming success', () {
      final payoff = AnalysisFallbackPayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
        analysisSucceeded: false,
      );

      expect(payoff!.footnoteLine, VoiceCaptureCopy.analysisUnavailableNote);
      _expectNoBannedCopy([payoff.footnoteLine], _bannedAiSuccessWords);
    });
  });

  group('AnalysisFallbackPayoffCard', () {
    testWidgets('renders local saved payoff copy', (tester) async {
      const payoff = AnalysisFallbackPayoff(
        title: AnalysisFallbackPayoffCopy.title,
        body: AnalysisFallbackPayoffCopy.bodyOneEntry,
        evidenceLine: AnalysisFallbackPayoffCopy.evidenceOneEntry,
        nextActionLine: AnalysisFallbackPayoffCopy.nextActionOneEntry,
        footnoteLine: AnalysisFallbackPayoffCopy.deferredFootnote,
      );

      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: AnalysisFallbackPayoffCard(payoff: payoff)),
        )));
      await tester.pump();

      expect(
        find.byKey(const Key('analysis_fallback_payoff_card')),
        findsOneWidget,
      );
      expect(find.text(AnalysisFallbackPayoffCopy.title), findsOneWidget);
      expect(
        find.text(AnalysisFallbackPayoffCopy.bodyOneEntry),
        findsOneWidget,
      );
      expect(
        find.text(AnalysisFallbackPayoffCopy.evidenceOneEntry),
        findsOneWidget,
      );
      expect(
        find.text(AnalysisFallbackPayoffCopy.nextActionOneEntry),
        findsOneWidget,
      );
      expect(
        find.text(AnalysisFallbackPayoffCopy.deferredFootnote),
        findsOneWidget,
      );
    });
  });

  group('RecordScreen analysis fallback UI', () {
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(
        journalPath: sandbox.journalPath,
        skipRevenueCat: true,
      );
    });

    tearDown(() async {
      await settleAppServicesForTest();
      sandbox.dispose();
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpDoneState(
      WidgetTester tester, {
      required List<JournalEntry> entriesAfterSave,
      bool lastCaptureAnalysisSucceeded = false,
    }) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: entriesAfterSave,
          lastCaptureAnalysisSucceeded: lastCaptureAnalysisSucceeded,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        )));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets(
      'good transcript with analysis unavailable shows local payoff',
      (tester) async {
        await pumpDoneState(
          tester,
          entriesAfterSave: [
            _voiceEntry(
              id: 'e1',
              transcript: 'I felt pressure before saying yes again today.',
            ),
          ],
        );

        V1MomentSaveReceiptExpectations.expectVisible();
        V1MomentSaveReceiptExpectations.expectNoLegacyPostSaveStack();
        _expectNoBannedCopy(_visibleText(tester), _bannedAiSuccessWords);
      },
    );

    testWidgets(
      'good transcript with analysis unavailable skips degraded recovery',
      (tester) async {
        await pumpDoneState(
          tester,
          entriesAfterSave: [
            _voiceEntry(
              id: 'e1',
              transcript: 'I felt pressure before saying yes again today.',
            ),
          ],
        );

        expect(
          find.byKey(const Key('post_save_degraded_transcription_card')),
          findsNothing,
        );
        expect(find.text(PendingTranscriptRecoveryCopy.title), findsNothing);
        expect(find.text(VoiceCaptureCopy.typeWhatYouSaid), findsNothing);
      },
    );

    testWidgets('one entry avoids repeat loop pattern language', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      _expectNoBannedCopy(_visibleText(tester), [
        ..._bannedPatternWords,
        'repeat',
        'loop',
      ]);
    });

    testWidgets('degraded transcript still shows audio recovery card', (
      tester,
    ) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: [_degradedVoiceEntry()],
          degradedVoicePostSave: true,
          lastCaptureAnalysisSucceeded: false,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: _degradedVoiceEntry(),
              allEntries: [_degradedVoiceEntry()],
            ),
          ),
        )));
      await tester.pump();

      expect(
        find.byKey(const Key('post_save_degraded_transcription_card')),
        findsOneWidget,
      );
      expect(find.text(PendingTranscriptRecoveryCopy.postSaveTitle), findsOneWidget);
      expect(
        find.byKey(const Key('analysis_fallback_payoff_card')),
        findsNothing,
      );
    });

    testWidgets(
      'two entries with analysis unavailable stay focused on record screen',
      (tester) async {
        await pumpDoneState(
          tester,
          entriesAfterSave: [
            _voiceEntry(
              id: 'e1',
              transcript:
                  'I stayed late finishing slides for tomorrow morning.',
              createdAt: DateTime(2026, 6, 11, 12),
            ),
            _voiceEntry(
              id: 'e2',
              transcript: 'My sister called about planning the weekend trip.',
              createdAt: DateTime(2026, 6, 12, 12),
            ),
          ],
        );

        expect(
          find.byKey(const Key('post_save_archive_home_nudge_card')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('second_session_payoff_card')),
          findsNothing,
        );
        V1MomentSaveReceiptExpectations.expectVisible();
        V1MomentSaveReceiptExpectations.expectNoLegacyPostSaveStack();
        expect(
          find.byKey(const Key('analysis_fallback_payoff_card')),
          findsNothing,
        );
        _expectNoBannedCopy(_visibleText(tester), _bannedPatternWords);
      },
    );

    testWidgets('analysis succeeded does not show fallback card', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
        lastCaptureAnalysisSucceeded: true,
      );

      expect(
        find.byKey(const Key('analysis_fallback_payoff_card')),
        findsNothing,
      );
    });
  });
}