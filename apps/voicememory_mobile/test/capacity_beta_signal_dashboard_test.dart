import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_signal_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_signal_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_signal_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_copy.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_models.dart';
import 'package:voicememory_mobile/features/pro_interest/pro_interest_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capacity_beta_signal_card.dart';

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
  'archiveme knows',
  'product-market fit',
  'product market fit',
  'pmf',
];

const _privateSnippet = 'felt pressure at work before saying yes';

JournalEntry _capacityEntry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      transcript ??
      'I $_privateSnippet again and said yes with no capacity left.',
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

CapacityBetaSignalInput _input({
  int capacityMomentCount = 0,
  int capacityEvidenceCount = 0,
  bool capacityWedgeActive = true,
  String fitResponseLabel = CapacityBetaSignalCopy.notAnsweredLabel,
  bool fitIsPositive = false,
  bool fitIsUnclear = true,
  int pullReasonRecordCount = 0,
  int outcomeRecordCount = 0,
  int laterCostRecordCount = 0,
  bool weeklyReviewAvailable = false,
  bool boundaryResponseSelected = false,
  bool boundaryResponseCopied = false,
  bool proInterestCaptured = false,
  bool paidIntentStrongWtp = false,
  bool paidIntentSoftWtp = false,
  bool dailyChangeAvailable = false,
  bool trackPaymentSignal = true,
}) => CapacityBetaSignalInput(
  capacityMomentCount: capacityMomentCount,
  capacityEvidenceCount: capacityEvidenceCount,
  capacityWedgeActive: capacityWedgeActive,
  activationTarget: 3,
  fitResponseLabel: fitResponseLabel,
  fitIsPositive: fitIsPositive,
  fitIsUnclear: fitIsUnclear,
  pullReasonRecordCount: pullReasonRecordCount,
  outcomeRecordCount: outcomeRecordCount,
  laterCostRecordCount: laterCostRecordCount,
  weeklyReviewAvailable: weeklyReviewAvailable,
  boundaryResponseSelected: boundaryResponseSelected,
  boundaryResponseCopied: boundaryResponseCopied,
  proInterestCaptured: proInterestCaptured,
  paidIntentRecord: paidIntentStrongWtp
      ? const PaidIntentConfirmationRecord(
          responseId: PaidIntentConfirmationResponseIds.yes999,
          status: PaidIntentConfirmationStatus.answered,
        )
      : paidIntentSoftWtp
      ? const PaidIntentConfirmationRecord(
          responseId: PaidIntentConfirmationResponseIds.maybe,
          status: PaidIntentConfirmationStatus.answered,
        )
      : null,
  dailyChangeAvailable: dailyChangeAvailable,
  trackPaymentSignal: trackPaymentSignal,
  quickCaptureFrictionRecord: null,
);

CapacityActivationFitRecord _fitRecord(String responseId) =>
    CapacityActivationFitRecord(
      responseId: responseId,
      source: CapacityActivationFitSource.capacityLoopActivation,
      activationEntryCount: 3,
      status: CapacityActivationFitStatus.answered,
      createdAt: DateTime(2026, 6, 12),
      updatedAt: DateTime(2026, 6, 12),
    );

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
  }
}

void main() {
  const engine = CapacityBetaSignalEngine();

  group('CapacityBetaSignalEngine', () {
    test('dashboard unavailable with no capacity evidence', () {
      final snapshot = engine.build(_input());
      expect(snapshot.hasCapacityEvidence, isFalse);
      expect(snapshot.capacityMomentCount, 0);
      expect(snapshot.verdict, CapacityBetaSignalVerdict.weak);
    });

    test('appears when capacity signals exist', () {
      final snapshot = engine.build(
        _input(capacityMomentCount: 1, capacityEvidenceCount: 2),
      );
      expect(snapshot.hasCapacityEvidence, isTrue);
    });

    test('computes activation progress 0/3 through 3/3', () {
      for (final count in [0, 1, 2, 3]) {
        final snapshot = engine.build(
          _input(capacityMomentCount: count, capacityEvidenceCount: count),
        );
        expect(
          CapacityBetaSignalCopy.savedYesMomentsValue(
            snapshot.capacityMomentCount,
            snapshot.activationTarget,
          ),
          '$count/3',
        );
        expect(snapshot.activationReached, count >= 3);
      }
    });

    test('computes fit response safely', () {
      final partly = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        fitRecord: _fitRecord(CapacityActivationFitResponseIds.partly),
      );
      expect(partly.fitResponseLabel, 'partly');

      final skipped = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        fitRecord: CapacityActivationFitRecord(
          responseId: '',
          source: CapacityActivationFitSource.capacityLoopActivation,
          activationEntryCount: 3,
          status: CapacityActivationFitStatus.skipped,
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
        ),
      );
      expect(skipped.fitResponseLabel, CapacityBetaSignalCopy.skippedLabel);
    });

    test('computes pull/outcome/cost counts safely', () {
      final now = DateTime(2026, 6, 12);
      final pullRecords = [
        CapacityPullReasonRecord(
          sourceEntryId: 'e0',
          reasonIds: [CapacityPullReasonIds.feltResponsible],
          status: CapacityPullReasonStatus.answered,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final outcomeRecords = [
        CapacityDecisionOutcomeRecord(
          sourceEntryId: 'e0',
          outcomeId: CapacityDecisionOutcomeIds.saidNo,
          status: CapacityDecisionOutcomeStatus.answered,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final costRecords = [
        CapacityCostRecord(
          sourceEntryId: 'e0',
          costTypeIds: [CapacityCostTypeIds.energy],
          status: CapacityCostRecordStatus.answered,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final snapshot = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        pullReasonRecords: pullRecords,
        outcomeRecords: outcomeRecords,
        costRecords: costRecords,
      );

      expect(snapshot.pullReasonRecordCount, 1);
      expect(snapshot.outcomeRecordCount, 1);
      expect(snapshot.laterCostRecordCount, 1);
    });

    test('computes boundary selected and copied when available', () {
      final snapshot = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        boundarySelection: CapacityBoundaryResponseSelection(
          responseId: CapacityBoundaryResponseIds.checkCapacityComeBack,
          selectedAt: DateTime(2026, 6, 12),
          lastCopiedAt: DateTime(2026, 6, 13),
        ),
      );
      expect(snapshot.boundaryResponseSelected, isTrue);
      expect(snapshot.boundaryResponseCopied, isTrue);
    });

    test('computes weak verdict below activation', () {
      final snapshot = engine.build(
        _input(capacityMomentCount: 2, capacityEvidenceCount: 2),
      );
      expect(snapshot.verdict, CapacityBetaSignalVerdict.weak);
      expect(snapshot.verdictLabel, CapacityBetaSignalCopy.verdictWeak);
    });

    test('computes promising verdict at activation with positive fit', () {
      final snapshot = engine.build(
        _input(
          capacityMomentCount: 3,
          capacityEvidenceCount: 3,
          fitResponseLabel: 'partly',
          fitIsPositive: true,
          fitIsUnclear: false,
        ),
      );
      expect(snapshot.verdict, CapacityBetaSignalVerdict.promising);
      expect(snapshot.verdictLabel, CapacityBetaSignalCopy.verdictPromising);
    });

    test('computes strong verdict with depth and boundary', () {
      final snapshot = engine.build(
        _input(
          capacityMomentCount: 3,
          capacityEvidenceCount: 3,
          fitResponseLabel: 'fits',
          fitIsPositive: true,
          fitIsUnclear: false,
          outcomeRecordCount: 1,
          laterCostRecordCount: 1,
          boundaryResponseSelected: true,
        ),
      );
      expect(snapshot.verdict, CapacityBetaSignalVerdict.strong);
      expect(snapshot.verdictLabel, CapacityBetaSignalCopy.verdictStrong);
    });

    test('computes unclear verdict when fit is not_yet', () {
      final snapshot = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        fitRecord: _fitRecord(CapacityActivationFitResponseIds.notYet),
      );
      expect(snapshot.verdict, CapacityBetaSignalVerdict.unclear);
      expect(snapshot.verdictLabel, CapacityBetaSignalCopy.verdictUnclear);
    });

    test('export summary uses counts only', () {
      final snapshot = engine.build(
        _input(
          capacityMomentCount: 3,
          capacityEvidenceCount: 3,
          fitResponseLabel: 'partly',
          fitIsPositive: true,
          fitIsUnclear: false,
          outcomeRecordCount: 2,
          laterCostRecordCount: 1,
          boundaryResponseSelected: true,
        ),
      );
      expect(
        snapshot.exportSummary,
        'ArchiveMe capacity beta signal: 3 yes moments, fit response partly, '
        '2 outcomes, 1 later costs, boundary response selected.',
      );
    });

    test('export summary does not include transcript text', () {
      final snapshot = engine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        fitRecord: _fitRecord(CapacityActivationFitResponseIds.partly),
      );
      expect(
        snapshot.exportSummary.toLowerCase(),
        isNot(contains(_privateSnippet)),
      );
    });

    test(
      'payment signal uses pro interest when tracked and no paid intent',
      () {
        final captured = engine.build(
          _input(
            capacityMomentCount: 3,
            capacityEvidenceCount: 3,
            proInterestCaptured: true,
          ),
        );
        expect(
          captured.paymentSignalLabel,
          CapacityBetaSignalCopy.proInterestFallbackLabel,
        );

        final paidIntent = engine.build(
          _input(
            capacityMomentCount: 3,
            capacityEvidenceCount: 3,
            paidIntentStrongWtp: true,
          ),
        );
        expect(
          paidIntent.paymentSignalLabel,
          PaidIntentConfirmationCopy.paymentSignalStrong,
        );

        final notTracked = engine.build(
          _input(
            capacityMomentCount: 3,
            capacityEvidenceCount: 3,
            trackPaymentSignal: false,
          ),
        );
        expect(
          notTracked.paymentSignalLabel,
          CapacityBetaSignalCopy.paymentNotTrackedLabel,
        );
      },
    );

    test('copy passes language guard', () {
      _expectNoBannedCopy(CapacityBetaSignalCopy.allVisibleStrings());
      _expectNoBannedCopy([
        engine.build(_input(capacityMomentCount: 3)).exportSummary,
        engine.build(_input(capacityMomentCount: 3)).verdictLabel,
      ]);
    });

    test('does not claim product-market fit is proven', () {
      for (final text in CapacityBetaSignalCopy.allVisibleStrings()) {
        expect(text.toLowerCase(), isNot(contains('proven')));
        expect(text.toLowerCase(), isNot(contains('success')));
        expect(text.toLowerCase(), isNot(contains('failure')));
      }
    });
  });

  group('CapacityBetaSignalCard widget', () {
    testWidgets('renders beta card copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CapacityBetaSignalCard()),
        ),
      );

      expect(
        find.byKey(const Key('capacity_beta_signal_card')),
        findsOneWidget,
      );
      expect(find.text(CapacityBetaSignalCopy.cardTitle), findsOneWidget);
      expect(find.text(CapacityBetaSignalCopy.cardBody), findsOneWidget);
      expect(
        find.text(CapacityBetaSignalCopy.openDashboardButton),
        findsOneWidget,
      );
    });
  });

  group('Routing and privacy', () {
    test('capacity beta signals route is sensitive', () {
      expect(
        SensitiveRoutes.isSensitiveRoute(CapacityBetaSignalCopy.route),
        isTrue,
      );
    });
  });
}

List<JournalEntry> _entries(int count) =>
    List.generate(count, (i) => _capacityEntry('real_$i'));
