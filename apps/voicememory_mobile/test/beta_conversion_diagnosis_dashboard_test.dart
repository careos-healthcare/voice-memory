import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_conversion_diagnosis/beta_conversion_diagnosis_copy.dart';
import 'package:voicememory_mobile/features/beta_conversion_diagnosis/beta_conversion_diagnosis_engine.dart';
import 'package:voicememory_mobile/features/beta_conversion_diagnosis/beta_conversion_diagnosis_model.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/beta_conversion_diagnosis_card.dart';

BetaConversionDiagnosisResult _resultFrom(BetaConversionDiagnosisInput input) =>
    BetaConversionDiagnosisEngine.buildFromInput(input);

bool _hasDiagnosis(BetaConversionDiagnosisResult result, String message) =>
    result.diagnoses.any((item) => item.message == message);

Future<void> _pumpCard(
  WidgetTester tester, {
  required BetaConversionDiagnosisResult result,
}) async {
  ArchiveBetaMissionGate.enabledOverride = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: BetaConversionDiagnosisCard(resultOverride: result)),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    ArchiveBetaMissionGate.resetForTest();
  });

  tearDown(ArchiveBetaMissionGate.resetForTest);

  group('BetaConversionDiagnosisEngine', () {
    test('hidden when beta/debug flag is false', () {
      expect(
        BetaConversionDiagnosisEngine.shouldShow(betaMissionEnabled: false),
        isFalse,
      );
    });

    test('first save below threshold shows first capture diagnosis', () {
      final result = _resultFrom(
        const BetaConversionDiagnosisInput(
          recordScreenSeen: 10,
          firstMomentSaved: 2,
          secondMomentSaved: 10,
          thirdMomentSaved: 10,
        ),
      );
      expect(
        _hasDiagnosis(result, BetaConversionDiagnosisCopy.firstCaptureUnclear),
        isTrue,
      );
      expect(
        result.diagnoses.any(
          (item) =>
              item.recommendedFixLabel ==
              BetaConversionDiagnosisCopy.fixFirstCapture,
        ),
        isTrue,
      );
    });

    test('second save below threshold shows return prompt diagnosis', () {
      final result = _resultFrom(
        const BetaConversionDiagnosisInput(
          recordScreenSeen: 10,
          firstMomentSaved: 10,
          secondMomentSaved: 2,
          thirdMomentSaved: 10,
        ),
      );
      expect(
        _hasDiagnosis(result, BetaConversionDiagnosisCopy.returnReasonWeak),
        isTrue,
      );
      expect(
        result.diagnoses.any(
          (item) =>
              item.recommendedFixLabel ==
              BetaConversionDiagnosisCopy.fixReturnPrompt,
        ),
        isTrue,
      );
    });

    test('third save below threshold shows three moment diagnosis', () {
      final result = _resultFrom(
        const BetaConversionDiagnosisInput(
          recordScreenSeen: 10,
          firstMomentSaved: 10,
          secondMomentSaved: 10,
          thirdMomentSaved: 1,
        ),
      );
      expect(
        _hasDiagnosis(result, BetaConversionDiagnosisCopy.notReachingProof),
        isTrue,
      );
      expect(
        result.diagnoses.any(
          (item) =>
              item.recommendedFixLabel ==
              BetaConversionDiagnosisCopy.fixThreeMomentCompletion,
        ),
        isTrue,
      );
    });

    test('useful below threshold shows proof diagnosis', () {
      final result = _resultFrom(
        const BetaConversionDiagnosisInput(
          recordScreenSeen: 10,
          firstMomentSaved: 10,
          secondMomentSaved: 10,
          thirdMomentSaved: 10,
          usefulCount: 1,
          tooVagueCount: 4,
        ),
      );
      expect(
        _hasDiagnosis(result, BetaConversionDiagnosisCopy.timelineNotUseful),
        isTrue,
      );
    });

    test('too vague above useful shows specificity diagnosis', () {
      final result = _resultFrom(
        const BetaConversionDiagnosisInput(
          recordScreenSeen: 10,
          firstMomentSaved: 10,
          secondMomentSaved: 10,
          thirdMomentSaved: 10,
          usefulCount: 2,
          tooVagueCount: 3,
        ),
      );
      expect(
        _hasDiagnosis(result, BetaConversionDiagnosisCopy.specificityWeak),
        isTrue,
      );
      expect(
        result.diagnoses.any(
          (item) =>
              item.recommendedFixLabel ==
              BetaConversionDiagnosisCopy.fixProofSpecificity,
        ),
        isTrue,
      );
    });

    test('already knew above useful shows change/delta diagnosis', () {
      final result = _resultFrom(
        const BetaConversionDiagnosisInput(
          recordScreenSeen: 10,
          firstMomentSaved: 10,
          secondMomentSaved: 10,
          thirdMomentSaved: 10,
          usefulCount: 2,
          alreadyKnewCount: 3,
        ),
      );
      expect(
        _hasDiagnosis(result, BetaConversionDiagnosisCopy.changeDeltaWeak),
        isTrue,
      );
      expect(
        result.diagnoses.any(
          (item) =>
              item.recommendedFixLabel ==
              BetaConversionDiagnosisCopy.fixChangeDeltaProof,
        ),
        isTrue,
      );
    });

    test('not relevant above useful shows relevance diagnosis', () {
      final result = _resultFrom(
        const BetaConversionDiagnosisInput(
          recordScreenSeen: 10,
          firstMomentSaved: 10,
          secondMomentSaved: 10,
          thirdMomentSaved: 10,
          usefulCount: 2,
          notRelevantCount: 3,
        ),
      );
      expect(
        _hasDiagnosis(result, BetaConversionDiagnosisCopy.relevanceWeak),
        isTrue,
      );
      expect(
        result.diagnoses.any(
          (item) =>
              item.recommendedFixLabel ==
              BetaConversionDiagnosisCopy.fixCurrentRelevance,
        ),
        isTrue,
      );
    });

    test(
      'return after proof below threshold shows return-after-proof diagnosis',
      () {
        final result = _resultFrom(
          const BetaConversionDiagnosisInput(
            recordScreenSeen: 10,
            firstMomentSaved: 10,
            secondMomentSaved: 10,
            thirdMomentSaved: 10,
            confirmedRepeatSeen: 10,
            returnedAfterFirstProof: 1,
          ),
        );
        expect(
          _hasDiagnosis(
            result,
            BetaConversionDiagnosisCopy.returnAfterProofWeak,
          ),
          isTrue,
        );
        expect(
          result.diagnoses.any(
            (item) =>
                item.recommendedFixLabel ==
                BetaConversionDiagnosisCopy.fixReturnAfterProof,
          ),
          isTrue,
        );
      },
    );

    test('paywall seen below threshold shows Pro bridge diagnosis', () {
      final result = _resultFrom(
        const BetaConversionDiagnosisInput(
          recordScreenSeen: 10,
          firstMomentSaved: 10,
          secondMomentSaved: 10,
          thirdMomentSaved: 10,
          confirmedRepeatSeen: 10,
          paywallSeenAfterProof: 2,
        ),
      );
      expect(
        _hasDiagnosis(result, BetaConversionDiagnosisCopy.proBridgeHidden),
        isTrue,
      );
      expect(
        result.diagnoses.any(
          (item) =>
              item.recommendedFixLabel ==
              BetaConversionDiagnosisCopy.fixProBridgeVisibility,
        ),
        isTrue,
      );
    });

    test(
      'purchase CTA below threshold shows paywall paid reason diagnosis',
      () {
        final result = _resultFrom(
          const BetaConversionDiagnosisInput(
            recordScreenSeen: 10,
            firstMomentSaved: 10,
            secondMomentSaved: 10,
            thirdMomentSaved: 10,
            confirmedRepeatSeen: 10,
            paywallSeenAfterProof: 10,
            purchaseTappedAfterProof: 0,
          ),
        );
        expect(
          _hasDiagnosis(result, BetaConversionDiagnosisCopy.paidReasonWeak),
          isTrue,
        );
        expect(
          result.diagnoses.any(
            (item) =>
                item.recommendedFixLabel ==
                BetaConversionDiagnosisCopy.fixPaywallPaidReason,
          ),
          isTrue,
        );
      },
    );

    test('each diagnosis includes metric current and target values', () {
      final result = _resultFrom(
        const BetaConversionDiagnosisInput(
          recordScreenSeen: 10,
          firstMomentSaved: 2,
          secondMomentSaved: 10,
          thirdMomentSaved: 10,
        ),
      );
      final diagnosis = result.diagnoses.firstWhere(
        (item) =>
            item.metricId == BetaConversionDiagnosisMetricId.firstSaveRate,
      );
      expect(diagnosis.currentValueLabel, '20%');
      expect(diagnosis.targetValueLabel, '50%');
      expect(
        diagnosis.metricLabel,
        BetaConversionDiagnosisCopy.metricFirstSaveRate,
      );
    });
  });

  group('BetaConversionDiagnosisCard', () {
    testWidgets('renders Beta diagnosis', (tester) async {
      await _pumpCard(
        tester,
        result: _resultFrom(
          const BetaConversionDiagnosisInput(
            recordScreenSeen: 10,
            firstMomentSaved: 2,
            secondMomentSaved: 10,
            thirdMomentSaved: 10,
          ),
        ),
      );

      expect(find.text('Beta diagnosis'), findsOneWidget);
      expect(
        find.text('Use this to see where the loop is breaking.'),
        findsOneWidget,
      );
      expect(
        find.text(BetaConversionDiagnosisCopy.firstCaptureUnclear),
        findsOneWidget,
      );
    });

    testWidgets('hidden when beta/debug false', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BetaConversionDiagnosisCard(
              resultOverride: _resultFrom(
                const BetaConversionDiagnosisInput(recordScreenSeen: 10),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('beta_conversion_diagnosis_hidden')),
        findsOneWidget,
      );
      expect(find.text('Beta diagnosis'), findsNothing);
    });

    testWidgets('does not render private text', (tester) async {
      await _pumpCard(
        tester,
        result: _resultFrom(
          const BetaConversionDiagnosisInput(
            recordScreenSeen: 10,
            firstMomentSaved: 2,
            secondMomentSaved: 10,
            thirdMomentSaved: 10,
          ),
        ),
      );

      expect(find.textContaining('I had no capacity'), findsNothing);
      expect(find.textContaining('entry_id'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
    });

    test('no medical claims in copy', () {
      for (final line in BetaConversionDiagnosisCopy.allVisibleStrings()) {
        if (line == BetaConversionDiagnosisCopy.title) continue;
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
      final blob = BetaConversionDiagnosisCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('treatment')));
    });
  });

  group('Protected billing areas', () {
    test('entitlement IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('diagnosis module does not touch billing constants', () {
      final engineSource = File(
        'lib/features/beta_conversion_diagnosis/beta_conversion_diagnosis_engine.dart',
      ).readAsStringSync();
      final widgetSource = File(
        'lib/widgets/beta/beta_conversion_diagnosis_card.dart',
      ).readAsStringSync();
      expect(engineSource, isNot(contains('proEntitlementId')));
      expect(widgetSource, isNot(contains('RevenueCat')));
    });
  });
}
