import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_response_copy.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_response_engine.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_response_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_signal_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_signal_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_signal_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/low_effort_yes_capture_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/low_effort_yes_capture_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/quick_capture_friction_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/quick_capture_friction_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/quick_capture_friction_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/quick_capture_friction_store.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_entries.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/quick_capture_friction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'subscribe now',
  'buy now',
  'pro is active',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'guilt',
  'streak',
];

const _privateSnippet = 'felt pressure at work before explaining everything';

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
    expect(lower, isNot(contains('archiveme knows')));
    expect(lower, isNot(contains(_privateSnippet)));
  }
}

Future<void> _resetStore(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_quick_capture_friction_journal_$stamp.json',
    prefsPath: '/tmp/vm_quick_capture_friction_prefs_$stamp.json',
  );
  await QuickCaptureFrictionStore.resetForTest();
}

JournalEntry _quickCaptureEntry(String id) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 15, 12),
  transcript: '',
  durationSeconds: 0,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: 'Quick yes moment saved.',
    repeatedSignal: '',
  ),
  captureContextTag: LowEffortYesCaptureIds.contextTag,
);

QuickCaptureFrictionResult _visibleAfterSave({
  String entryId = 'quick_yes_1',
}) => const QuickCaptureFrictionEngine().buildAfterQuickSave(
  relatedEntryId: entryId,
  capacityWedgeActive: true,
);

void main() {
  const engine = QuickCaptureFrictionEngine();
  const betaEngine = CapacityBetaSignalEngine();
  const feedbackEngine = BetaFeedbackResponseEngine();

  group('QuickCaptureFrictionEngine', () {
    test('friction check appears after quick yes capture', () {
      final result = engine.buildAfterQuickSave(
        relatedEntryId: 'quick_yes_1',
        capacityWedgeActive: true,
      );
      expect(result.showCard, isTrue);
      expect(result.title, 'Was this easy enough?');
      expect(result.body, contains('Did this feel light enough to use again?'));
    });

    test('hidden if no quick capture exists', () {
      final result = engine.build(
        const QuickCaptureFrictionInput(
          capacityWedgeActive: true,
          sampleMode: false,
          screenshotMode: false,
          hasQuickCaptureEntry: false,
          showAfterQuickSave: false,
        ),
      );
      expect(result.showCard, isFalse);
    });

    test('hidden in ScreenshotMode', () {
      final result = engine.buildAfterQuickSave(
        relatedEntryId: 'quick_yes_1',
        capacityWedgeActive: true,
        screenshotMode: true,
      );
      expect(result.showCard, isFalse);
    });

    test('hidden for sample/demo-only mode', () {
      final result = engine.buildAfterQuickSave(
        relatedEntryId: 'quick_yes_1',
        capacityWedgeActive: true,
        sampleMode: true,
      );
      expect(result.showCard, isFalse);
    });

    test('hasQuickCaptureEntry detects quick capture entries', () {
      expect(
        QuickCaptureFrictionEngine.hasQuickCaptureEntry([
          _quickCaptureEntry('q1'),
        ]),
        isTrue,
      );
      expect(
        QuickCaptureFrictionEngine.hasQuickCaptureEntry(
          SampleArchiveEntries.build(),
        ),
        isFalse,
      );
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy(QuickCaptureFrictionCopy.allVisibleStrings());
    });
  });

  group('QuickCaptureFrictionStore', () {
    test('stores fixed response locally', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await QuickCaptureFrictionStore.instance().saveAnswered(
        responseId: QuickCaptureFrictionResponseIds.quickEnough,
        relatedEntryId: 'quick_yes_1',
      );

      final record = await QuickCaptureFrictionStore.instance().loadRecord();
      expect(record?.responseId, QuickCaptureFrictionResponseIds.quickEnough);
      expect(record?.source, QuickCaptureFrictionSource.quickYesCapture);
      expect(record?.relatedEntryId, 'quick_yes_1');
      expect(record?.status, QuickCaptureFrictionStatus.answered);
    });

    test('skip works', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await QuickCaptureFrictionStore.instance().saveSkipped(
        relatedEntryId: 'quick_yes_2',
      );

      final record = await QuickCaptureFrictionStore.instance().loadRecord();
      expect(record?.isSkipped, isTrue);
      expect(record?.relatedEntryId, 'quick_yes_2');
    });

    test('does not store transcript text', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _resetStore(stamp);

      await QuickCaptureFrictionStore.instance().saveAnswered(
        responseId: QuickCaptureFrictionResponseIds.stillWork,
        relatedEntryId: 'quick_yes_3',
      );

      final json = await AppServices.instance.prefs.readJsonMap(
        QuickCaptureFrictionStore.prefsKey,
      );
      expect(json.toString().toLowerCase(), isNot(contains(_privateSnippet)));
      expect(json.toString(), isNot(contains('transcript')));
    });
  });

  group('QuickCaptureFrictionCard', () {
    testWidgets('renders friction check options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: QuickCaptureFrictionCard(result: _visibleAfterSave()),
          ),
        ),
      );

      expect(
        find.byKey(const Key('quick_capture_friction_card')),
        findsOneWidget,
      );
      expect(find.text('Was this easy enough?'), findsOneWidget);
      expect(find.text('Yes — quick enough'), findsOneWidget);
      expect(find.text('Still felt like work'), findsOneWidget);
    });

    testWidgets('hidden when engine returns hidden', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: QuickCaptureFrictionCard(
              result: const QuickCaptureFrictionEngine().build(
                const QuickCaptureFrictionInput(
                  capacityWedgeActive: false,
                  sampleMode: false,
                  screenshotMode: false,
                  hasQuickCaptureEntry: false,
                  showAfterQuickSave: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('quick_capture_friction_card_hidden')),
        findsOneWidget,
      );
    });
  });

  group('CapacityBetaSignalEngine friction integration', () {
    test('beta signal dashboard reads friction response', () {
      final snapshot = betaEngine.build(
        CapacityBetaSignalInput(
          capacityMomentCount: 1,
          capacityEvidenceCount: 1,
          capacityWedgeActive: true,
          activationTarget: 3,
          fitResponseLabel: CapacityBetaSignalCopy.notAnsweredLabel,
          fitIsPositive: false,
          fitIsUnclear: true,
          pullReasonRecordCount: 1,
          outcomeRecordCount: 0,
          laterCostRecordCount: 0,
          weeklyReviewAvailable: false,
          boundaryResponseSelected: false,
          boundaryResponseCopied: false,
          proInterestCaptured: false,
          paidIntentRecord: null,
          dailyChangeAvailable: false,
          trackPaymentSignal: true,
          quickCaptureFrictionRecord: QuickCaptureFrictionRecord(
            responseId: QuickCaptureFrictionResponseIds.mostly,
            source: QuickCaptureFrictionSource.quickYesCapture,
            relatedEntryId: 'quick_yes_1',
            status: QuickCaptureFrictionStatus.answered,
            createdAt: DateTime(2026, 6, 15),
            updatedAt: DateTime(2026, 6, 15),
          ),
        ),
      );
      expect(snapshot.quickCaptureFrictionLabel, 'mostly');
    });
  });

  group('BetaFeedbackResponseEngine friction integration', () {
    test('still_work maps to quick_capture_still_work issue', () {
      QuickCaptureFrictionStore.seedForTest(
        QuickCaptureFrictionRecord(
          responseId: QuickCaptureFrictionResponseIds.stillWork,
          source: QuickCaptureFrictionSource.quickYesCapture,
          relatedEntryId: 'quick_yes_1',
          status: QuickCaptureFrictionStatus.answered,
          createdAt: DateTime(2026, 6, 15),
          updatedAt: DateTime(2026, 6, 15),
        ),
      );

      final result = feedbackEngine.build(
        const BetaFeedbackResponseInput(
          capacityWedgeActive: true,
          capacityMomentCount: 1,
          activationTarget: 3,
          fitIsPositive: false,
          fitIsUnclear: true,
          fitNotAnswered: true,
          pullReasonRecordCount: 1,
          outcomeRecordCount: 0,
          laterCostRecordCount: 0,
          weeklyReviewAvailable: false,
          boundaryResponseSelected: false,
          boundaryResponseCopied: false,
          proInterestCaptured: false,
          paidIntentStrongWtp: false,
          paidIntentSoftWtp: false,
          dailyChangeAvailable: false,
          dailyChangeDismissed: false,
          quickCaptureFrictionStillWork: true,
        ),
      );

      expect(result.issueId, BetaFeedbackIssueIds.quickCaptureStillWork);
      expect(
        result.suggestedNextFixLabel,
        BetaFeedbackResponseCopy.suggestedFixReduceCaptureWorkload,
      );
      expect(
        result.recommendedResponseSummary,
        contains('Reduce capture workload further'),
      );
    });
  });

  group('Privacy and payment guardrails', () {
    test('no RevenueCat payment call in friction copy', () {
      for (final text in QuickCaptureFrictionCopy.allVisibleStrings()) {
        expect(text.toLowerCase(), isNot(contains('revenuecat')));
        expect(text.toLowerCase(), isNot(contains('subscribe now')));
        expect(text.toLowerCase(), isNot(contains('buy now')));
      }
    });

    test('quick capture entries have no transcript', () {
      final entry = _quickCaptureEntry('q1');
      expect(entry.transcript, isEmpty);
      expect(LowEffortYesCaptureEngine.isQuickCaptureEntry(entry), isTrue);
    });
  });
}