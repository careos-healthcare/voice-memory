import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_model.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_analytics.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_copy.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_engine.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_model.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pro/pro_evidence_value_card.dart';
import 'package:voicememory_mobile/widgets/pro/pro_evidence_value_sheet.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
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

List<JournalEntry> _threeRelatedEntries() => [
      _entry(
        id: 'e1',
        transcript: _strongRepeat,
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

ProEvidenceValueContext _context({
  required ProEvidenceValueSurface surface,
  List<JournalEntry> entries = const [],
  int entryCount = 0,
  bool isPro = false,
  bool dismissed = false,
  bool firstProofPayoffVisible = false,
  bool privateReportPreviewVisible = false,
  bool weeklyReviewPreviewVisible = false,
  bool isZeroEntryState = false,
  bool isFirstRecordingState = false,
  bool isDegradedTranscriptState = false,
  bool isPostSaveDegradedState = false,
  bool firstProofTruthQuestionActive = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
}) =>
    ProEvidenceValueContext(
      surface: surface,
      entryCount: entryCount,
      isPro: isPro,
      dismissed: dismissed,
      firstProofPayoffSeen: firstProofPayoffVisible ||
          ProEvidenceValueEngine.firstProofPayoffSeenForEntries(entries),
      hasConfirmedRepeatEvidence:
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
      privateReportPreviewVisible: privateReportPreviewVisible,
      weeklyReviewPreviewVisible: weeklyReviewPreviewVisible,
      isZeroEntryState: isZeroEntryState,
      isFirstRecordingState: isFirstRecordingState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      firstProofTruthQuestionActive: firstProofTruthQuestionActive,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      exportReportsLive: true,
    );

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    ProEvidenceValueAnalytics.resetForTest();
    ProEvidenceValueAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/pro_evidence_value/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/pro_evidence_value/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await ProEvidenceValueDismissStore.resetForTest();
  });

  tearDown(() {
    ProEvidenceValueAnalytics.resetForTest();
    analyticsEvents.clear();
  });

  group('ProEvidenceValueCopy', () {
    test('defines required bridge copy', () {
      expect(ProEvidenceValueCopy.title, 'Keep the longer story');
      expect(
        ProEvidenceValueCopy.body,
        contains('Free shows the first proof'),
      );
      expect(ProEvidenceValueCopy.cta, 'See what Pro keeps');
      expect(ProEvidenceValueCopy.secondary, 'Not now');
      expect(
        ProEvidenceValueCopy.chatGptDifferentiationLine,
        'ChatGPT answers one conversation. ArchiveMe compares what you saved over time.',
      );
      expect(
        ProEvidenceValueCopy.evidenceLine,
        'Pro is for keeping the evidence, not getting generic advice.',
      );
      expect(
        ProEvidenceValueCopy.sheetFooter,
        'ArchiveMe is not trying to answer better than ChatGPT. It remembers differently.',
      );
    });

    test('all visible strings avoid private-content placeholders', () {
      for (final line in ProEvidenceValueCopy.allVisibleStrings(
        exportReportsLive: true,
      )) {
        expect(line.toLowerCase(), isNot(contains('transcript')));
        expect(line.toLowerCase(), isNot(contains('pattern key')));
      }
    });
  });

  group('ProEvidenceValueEngine', () {
    test('does not show at zero entries', () {
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          _context(
            surface: ProEvidenceValueSurface.recordReady,
            isZeroEntryState: true,
          ),
        ),
        isFalse,
      );
    });

    test('does not show before first proof', () {
      final oneEntry = [_entry(id: 'e1', transcript: 'A quiet lunch today.')];
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.recordReady,
            entryCount: 1,
            isPro: false,
            dismissed: false,
            entries: oneEntry,
            isFirstRecordingState: true,
          ),
        ),
        isFalse,
      );
    });

    test('can show after confirmed repeat / first proof', () async {
      await ProEvidenceValueDismissStore.resetForTest();
      final entries = _threeRelatedEntries();
      expect(FirstProofPayoffEngine.build(entries: entries), isNotNull);
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueContext(
            surface: ProEvidenceValueSurface.recordReady,
            entryCount: entries.length,
            isPro: false,
            dismissed: false,
            firstProofPayoffSeen: true,
            hasConfirmedRepeatEvidence: true,
            privateReportPreviewVisible: false,
            weeklyReviewPreviewVisible: false,
            isZeroEntryState: false,
            isFirstRecordingState: false,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: false,
            firstProofTruthQuestionActive: false,
            whatChangedQuestionActive: false,
            patternReviewInboxHasActiveItems: false,
            exportReportsLive: true,
          ),
        ),
        isTrue,
      );
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.recordReady,
            entryCount: entries.length,
            isPro: false,
            dismissed: false,
            entries: entries,
          ),
        ),
        isFalse,
      );
    });

    test('hides during active review question surfaces', () {
      final entries = _threeRelatedEntries();
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          _context(
            surface: ProEvidenceValueSurface.recordPostSaveAfterPayoff,
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
            firstProofTruthQuestionActive: true,
          ),
        ),
        isFalse,
      );
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          _context(
            surface: ProEvidenceValueSurface.recordPostSaveAfterPayoff,
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
            whatChangedQuestionActive: true,
          ),
        ),
        isFalse,
      );
    });

    test('hides when dismissed', () async {
      final entries = _threeRelatedEntries();
      await ProEvidenceValueDismissStore.dismiss();
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.archivePatterns,
            entryCount: entries.length,
            isPro: false,
            dismissed: ProEvidenceValueDismissStore.isDismissed(),
            entries: entries,
          ),
        ),
        isFalse,
      );
    });

    test('hides for Pro users', () {
      final entries = _threeRelatedEntries();
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.archivePatterns,
            entryCount: entries.length,
            isPro: true,
            dismissed: false,
            entries: entries,
          ),
        ),
        isFalse,
      );
    });

    test('hides on degraded transcript state', () {
      final degraded = [
        _entry(id: 'd1', transcript: _placeholder),
        ..._threeRelatedEntries(),
      ];
      expect(
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.recordReady,
            entryCount: degraded.length,
            isPro: false,
            dismissed: false,
            entries: degraded,
            isDegradedTranscriptState:
                VoiceCaptureQuality.isDegradedVoiceCapture(degraded.last),
          ),
        ),
        isFalse,
      );
    });
  });

  group('ProEvidenceValueAnalytics', () {
    test('uses metadata only', () {
      ProEvidenceValueAnalytics.seen(source: 'record_ready', entryCount: 3);
      ProEvidenceValueAnalytics.ctaTapped(
        source: 'record_ready',
        entryCount: 3,
        actionType: 'open_sheet',
      );
      ProEvidenceValueAnalytics.dismissed(source: 'record_ready', entryCount: 3);

      expect(analyticsEvents, hasLength(3));
      for (final captured in analyticsEvents) {
        expect(captured.props.keys, isNot(contains('transcript')));
        expect(captured.props.keys, isNot(contains('pattern_text')));
        expect(captured.props.keys, isNot(contains('phrase')));
        expect(captured.props['entry_count'], 3);
        expect(captured.props['source'], 'record_ready');
      }
    });
  });

  group('ProEvidenceValueCard', () {
    testWidgets('renders copy and opens sheet with ChatGPT differentiation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProEvidenceValueCard(
              surface: ProEvidenceValueSurface.recordReady,
              entryCount: 3,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text(ProEvidenceValueCopy.title), findsOneWidget);
      expect(find.text(ProEvidenceValueCopy.body), findsOneWidget);
      expect(find.text(ProEvidenceValueCopy.cta), findsOneWidget);

      await tester.tap(find.byKey(const Key('pro_evidence_value_cta')));
      await tester.pumpAndSettle();

      expect(find.text(ProEvidenceValueCopy.sheetTitle), findsOneWidget);
      expect(
        find.text(ProEvidenceValueCopy.comparesMomentsLine),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pro_evidence_value_sheet_chatgpt_line')),
        findsOneWidget,
      );
      expect(find.text(ProEvidenceValueCopy.sheetFooter), findsOneWidget);
      expect(find.text(ProEvidenceValueCopy.freeSectionTitle), findsOneWidget);
      expect(find.text(ProEvidenceValueCopy.proSectionTitle), findsOneWidget);
      expect(find.text('First repeat proof'), findsOneWidget);
      expect(find.text('Longer archive memory'), findsOneWidget);
    });

    testWidgets('dismiss fires analytics', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProEvidenceValueCard(
              surface: ProEvidenceValueSurface.archivePatterns,
              entryCount: 3,
              onSeePro: () {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('pro_evidence_value_dismiss')));
      await tester.pump();

      expect(dismissed, isTrue);
      expect(
        analyticsEvents.any((e) => e.event == 'pro_evidence_value_dismissed'),
        isTrue,
      );
    });
  });

  group('ProEvidenceValueSheet', () {
    testWidgets('sheet explains Free vs Pro', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ProEvidenceValueSheet.show(
                  context,
                  surface: ProEvidenceValueSurface.weeklyReviewPreview,
                  entryCount: 4,
                  onSeePro: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Basic correction'), findsOneWidget);
      expect(find.text('Change timeline'), findsOneWidget);
      expect(find.text('Private reports'), findsOneWidget);
      expect(find.text('Exportable reports'), findsOneWidget);
    });
  });

  group('FirstProofTruthStore isolation', () {
    test('answered truth does not leak into analytics props', () async {
      analyticsEvents.clear();
      final entries = _threeRelatedEntries();
      final proofKey = FirstProofTruthStore.proofKeyForFirstProof(entries);
      await FirstProofTruthStore.forPrefs(AppServices.instance.prefs).saveAnswer(
        proofKey: proofKey,
        answer: FirstProofTruthAnswer.yes,
      );

      ProEvidenceValueAnalytics.seen(source: 'record_ready', entryCount: 3);
      final seen = analyticsEvents.single;
      expect(seen.props.containsKey('proof_key'), isFalse);
      expect(seen.props.containsKey('answer'), isFalse);
    });
  });
}
