import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_analytics.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_copy.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_engine.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_model.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/beta/beta_feedback_intelligence_card.dart';
import 'package:archiveme_mobile/widgets/beta/beta_feedback_intelligence_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
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

BetaFeedbackIntelligenceContext _context({
  required BetaFeedbackIntelligenceSurface surface,
  List<JournalEntry> entries = const [],
  int entryCount = 0,
  bool isZeroEntryState = false,
  bool isRecordingState = false,
  bool isPostSaveDegradedState = false,
  bool firstProofTruthQuestionActive = false,
  bool whatChangedQuestionActive = false,
  bool firstProofPayoffVisible = false,
  bool proEvidenceSheetOpenedThisSession = false,
  bool patternReviewInboxHasActiveItems = false,
}) {
  return BetaFeedbackIntelligenceContext(
    surface: surface,
    entryCount: entryCount,
    betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    submittedForSession: BetaFeedbackIntelligenceStore.isSubmittedForSession(),
    firstProofPayoffSeen:
        firstProofPayoffVisible ||
        FirstProofPayoffEngine.build(entries: entries) != null,
    proEvidenceSheetOpenedThisSession: proEvidenceSheetOpenedThisSession,
    isZeroEntryState: isZeroEntryState,
    isRecordingState: isRecordingState,
    isDegradedTranscriptState: false,
    isPostSaveDegradedState: isPostSaveDegradedState,
    firstProofTruthQuestionActive: firstProofTruthQuestionActive,
    whatChangedQuestionActive: whatChangedQuestionActive,
    patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
  );
}

void main() {
  late TestStorageSandbox sandbox;
  TestWidgetsFlutterBinding.ensureInitialized();

  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    analyticsEvents.clear();
    BetaFeedbackIntelligenceAnalytics.resetForTest();
    BetaFeedbackIntelligenceAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    ArchiveBetaMissionGate.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await BetaFeedbackIntelligenceStore.resetForTest();
  });

  tearDown(() => sandbox.dispose());
  tearDown(() {
    BetaFeedbackIntelligenceAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
    analyticsEvents.clear();
  });

  group('BetaFeedbackIntelligenceCopy', () {
    test('defines required strings', () {
      expect(BetaFeedbackIntelligenceCopy.cardTitle, 'Help improve ArchiveMe');
      expect(BetaFeedbackIntelligenceCopy.sheetTitle, 'Beta feedback');
      expect(BetaFeedbackIntelligenceCopy.summaryTitle, 'Beta signal');
    });
  });

  group('BetaFeedbackIntelligenceEngine', () {
    test('card hidden when beta flag disabled', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        BetaFeedbackIntelligenceEngine.shouldShowCard(
          _context(
            surface: BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
            entryCount: 3,
            firstProofPayoffVisible: true,
          ),
        ),
        isFalse,
      );
    });

    test('card hidden at zero entries', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaFeedbackIntelligenceEngine.shouldShowCard(
          _context(
            surface: BetaFeedbackIntelligenceSurface.testingArchiveMe,
            isZeroEntryState: true,
          ),
        ),
        isFalse,
      );
    });

    test('card shows after first proof when beta enabled', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final entries = _threeRelatedEntries();
      expect(
        BetaFeedbackIntelligenceEngine.shouldShowCard(
          _context(
            surface: BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
          ),
        ),
        isTrue,
      );
    });

    test('card blocked during active review question surfaces', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final entries = _threeRelatedEntries();
      expect(
        BetaFeedbackIntelligenceEngine.shouldShowCard(
          _context(
            surface: BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
            firstProofTruthQuestionActive: true,
          ),
        ),
        isFalse,
      );
      expect(
        BetaFeedbackIntelligenceEngine.shouldShowCard(
          _context(
            surface: BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
            whatChangedQuestionActive: true,
          ),
        ),
        isFalse,
      );
      expect(
        BetaFeedbackIntelligenceEngine.shouldShowCard(
          _context(
            surface: BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
            patternReviewInboxHasActiveItems: true,
          ),
        ),
        isFalse,
      );
    });

    test('card hidden when feedback already submitted for session', () async {
      ArchiveBetaMissionGate.enabledOverride = true;
      final entries = _threeRelatedEntries();
      await BetaFeedbackIntelligenceStore.saveSubmission(
        chatGptDifferenceAnswer: BetaChatGptDifferenceAnswer.yes,
        differentiatorAnswer: BetaDifferentiatorAnswer.showedRepeats,
        wouldPayAnswer: BetaWouldPayAnswer.maybe,
        mainConfusionBucket: BetaMainConfusionBucket.nothing,
        strongestMomentBucket: BetaStrongestMomentBucket.firstProof,
      );
      expect(
        BetaFeedbackIntelligenceEngine.shouldShowCard(
          _context(
            surface: BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
          ),
        ),
        isFalse,
      );
    });

    test('card shows after pro evidence sheet opened', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final entries = _threeRelatedEntries();
      expect(
        BetaFeedbackIntelligenceEngine.shouldShowCard(
          _context(
            surface: BetaFeedbackIntelligenceSurface.afterProEvidenceSheet,
            entries: entries,
            entryCount: entries.length,
            proEvidenceSheetOpenedThisSession: true,
          ),
        ),
        isTrue,
      );
    });
  });

  group('BetaFeedbackIntelligenceStore', () {
    test('submit stores safe answers', () async {
      await BetaFeedbackIntelligenceStore.saveSubmission(
        chatGptDifferenceAnswer: BetaChatGptDifferenceAnswer.yes,
        differentiatorAnswer: BetaDifferentiatorAnswer.showedChange,
        wouldPayAnswer: BetaWouldPayAnswer.yes,
        mainConfusionBucket: BetaMainConfusionBucket.pro,
        strongestMomentBucket: BetaStrongestMomentBucket.proExplanation,
      );
      final state = BetaFeedbackIntelligenceStore.cached;
      expect(state.hasSubmittedBetaFeedback, isTrue);
      expect(state.chatGptDifferenceAnswer, BetaChatGptDifferenceAnswer.yes);
      expect(state.testerUnderstoodArchiveMe, isTrue);
      expect(state.testerWouldPay, BetaWouldPayAnswer.yes);
      expect(state.testerMainConfusion, BetaMainConfusionBucket.pro);
      expect(
        state.testerMostValuableMoment,
        BetaStrongestMomentBucket.proExplanation,
      );
      expect(state.testerPriceSignal, BetaWouldPayAnswer.yes);

      final raw = await AppServices.instance.prefs.readMap(
        BetaFeedbackIntelligenceStore.prefsKey,
      );
      final serialized = raw.toString().toLowerCase();
      expect(serialized, isNot(contains('transcript')));
      expect(serialized, isNot(contains('pattern')));
      expect(serialized, isNot(contains('entry')));
    });

    test('resetForTest clears store', () async {
      await BetaFeedbackIntelligenceStore.saveSubmission(
        chatGptDifferenceAnswer: BetaChatGptDifferenceAnswer.no,
        differentiatorAnswer: BetaDifferentiatorAnswer.didNotFeelDifferent,
        wouldPayAnswer: BetaWouldPayAnswer.no,
        mainConfusionBucket: BetaMainConfusionBucket.differenceFromChatGpt,
        strongestMomentBucket: BetaStrongestMomentBucket.nothingYet,
      );
      await BetaFeedbackIntelligenceStore.resetForTest();
      expect(
        BetaFeedbackIntelligenceStore.cached.hasSubmittedBetaFeedback,
        isFalse,
      );
      expect(BetaFeedbackIntelligenceStore.isSubmittedForSession(), isFalse);
    });

    test('feedback does not change journal entries', () async {
      final before = await AppServices.instance.journal.loadAll();
      await BetaFeedbackIntelligenceStore.saveSubmission(
        chatGptDifferenceAnswer: BetaChatGptDifferenceAnswer.notSure,
        differentiatorAnswer: BetaDifferentiatorAnswer.other,
        wouldPayAnswer: BetaWouldPayAnswer.maybe,
        mainConfusionBucket: BetaMainConfusionBucket.patterns,
        strongestMomentBucket: BetaStrongestMomentBucket.whatChanged,
      );
      final after = await AppServices.instance.journal.loadAll();
      expect(after.length, before.length);
    });
  });

  group('BetaFeedbackIntelligenceAnalytics', () {
    test('uses metadata only', () {
      BetaFeedbackIntelligenceAnalytics.submitted(
        source: 'testing_archiveme',
        entryCount: 3,
        reachedFirstProof: true,
        sawProBridge: true,
        chatGptDifferenceAnswer: BetaChatGptDifferenceAnswer.yes,
        wouldPayAnswer: BetaWouldPayAnswer.maybe,
        mainConfusionBucket: BetaMainConfusionBucket.firstProof,
        strongestMomentBucket: BetaStrongestMomentBucket.firstProof,
      );
      final event = analyticsEvents.single;
      expect(event.event, BetaFeedbackIntelligenceAnalytics.submittedEvent);
      expect(event.props.keys.toSet(), {
        'source',
        'entry_count',
        'reached_first_proof',
        'saw_pro_bridge',
        'chatgpt_difference_answer',
        'would_pay_answer',
        'main_confusion_bucket',
        'strongest_moment_bucket',
      });
      for (final value in event.props.values) {
        expect(value.toString().toLowerCase(), isNot(contains('transcript')));
      }
    });
  });

  group('BetaFeedbackIntelligenceCard', () {
    testWidgets('renders card copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BetaFeedbackIntelligenceCard(
              surface: BetaFeedbackIntelligenceSurface.testingArchiveMe,
              entryCount: 3,
              reachedFirstProof: true,
            ),
          ),
        ),
      );
      expect(find.text(BetaFeedbackIntelligenceCopy.cardTitle), findsOneWidget);
      expect(find.text(BetaFeedbackIntelligenceCopy.cardCta), findsOneWidget);
    });
  });

  group('BetaFeedbackIntelligenceSheet', () {
    testWidgets('renders all questions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BetaFeedbackIntelligenceSheet(
              source: 'test',
              entryCount: 3,
              reachedFirstProof: true,
            ),
          ),
        ),
      );

      expect(
        find.text(BetaFeedbackIntelligenceCopy.sheetTitle),
        findsOneWidget,
      );
      expect(
        find.text(BetaFeedbackIntelligenceCopy.chatGptDifferenceQuestion),
        findsOneWidget,
      );
      expect(
        find.text(BetaFeedbackIntelligenceCopy.differentiatorQuestion),
        findsOneWidget,
      );
      expect(
        find.text(BetaFeedbackIntelligenceCopy.wouldPayQuestion),
        findsOneWidget,
      );
      expect(
        find.text(BetaFeedbackIntelligenceCopy.mainConfusionQuestion),
        findsOneWidget,
      );
      expect(
        find.text(BetaFeedbackIntelligenceCopy.strongestMomentQuestion),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('beta_feedback_intelligence_submit')),
        findsOneWidget,
      );
    });
  });

  group('BetaFeedbackIntelligenceEngine summary', () {
    test('buildSummary renders safe buckets', () async {
      await BetaFeedbackIntelligenceStore.saveSubmission(
        chatGptDifferenceAnswer: BetaChatGptDifferenceAnswer.yes,
        differentiatorAnswer: BetaDifferentiatorAnswer.showedRepeats,
        wouldPayAnswer: BetaWouldPayAnswer.maybe,
        mainConfusionBucket: BetaMainConfusionBucket.patterns,
        strongestMomentBucket: BetaStrongestMomentBucket.quietSignal,
      );
      final summary = BetaFeedbackIntelligenceEngine.buildSummary(
        entries: _threeRelatedEntries(),
      );
      expect(
        summary.chatGptDifferenceLabel,
        BetaFeedbackIntelligenceCopy.summaryYes,
      );
      expect(summary.proValueLabel, BetaFeedbackIntelligenceCopy.summaryMaybe);
      expect(
        summary.mainConfusionLabel,
        BetaFeedbackIntelligenceCopy.confusionPatterns,
      );
      expect(
        summary.strongestMomentLabel,
        BetaFeedbackIntelligenceCopy.strongestQuietSignal,
      );
      expect(
        summary.feedbackSubmittedLabel,
        BetaFeedbackIntelligenceCopy.summaryYes,
      );
      expect(summary.stillToTestItems, isNot(contains('Submit beta feedback')));
    });
  });
}