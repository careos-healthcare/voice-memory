import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_copy.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_engine.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/beta_next_build_decision_card.dart';

BetaTesterOutcome _outcome(String id, Set<BetaDecisionSignal> signals) =>
    BetaTesterOutcome(testerId: id, signals: signals);

Future<void> _pumpCard(
  WidgetTester tester, {
  required BetaDecisionResult result,
}) async {
  ArchiveBetaMissionGate.enabledOverride = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BetaNextBuildDecisionCard(resultOverride: result),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(ArchiveBetaMissionGate.resetForTest);
  tearDown(ArchiveBetaMissionGate.resetForTest);

  group('BetaDecisionEngine', () {
    test('misunderstanding recommends Record/onboarding copy', () {
      final result = BetaDecisionEngine.build(
        outcomes: [
          _outcome('t1', {BetaDecisionSignal.misunderstoodAsGenericJournal}),
        ],
      );
      expect(
        result.primaryRecommendation,
        BetaNextBuildRecommendation.fixRecordOnboardingCopy,
      );
      expect(result.nextActionCopy, BetaDecisionCopy.nextFixRecordOnboarding);
    });

    test('understands but no record recommends capture friction', () {
      final result = BetaDecisionEngine.build(
        outcomes: [
          _outcome('t1', {
            BetaDecisionSignal.understoodPromise,
            BetaDecisionSignal.confusedWhatToWrite,
          }),
        ],
      );
      expect(
        result.primaryRecommendation,
        BetaNextBuildRecommendation.fixCaptureFriction,
      );
      expect(result.nextActionCopy, BetaDecisionCopy.nextFixCaptureFriction);
    });

    test('records once but no return recommends return reason', () {
      final result = BetaDecisionEngine.build(
        outcomes: [
          _outcome('t1', {
            BetaDecisionSignal.understoodPromise,
            BetaDecisionSignal.tappedRecord,
            BetaDecisionSignal.savedFirstMoment,
          }),
        ],
      );
      expect(
        result.primaryRecommendation,
        BetaNextBuildRecommendation.addReturnReason,
      );
      expect(result.nextActionCopy, BetaDecisionCopy.nextAddReturnReason);
    });

    test(
      'reaches proof but does not care recommends proof emotional clarity',
      () {
        final result = BetaDecisionEngine.build(
          outcomes: [
            _outcome('t1', {
              BetaDecisionSignal.understoodPromise,
              BetaDecisionSignal.savedFirstMoment,
              BetaDecisionSignal.returnedDay2,
              BetaDecisionSignal.reachedThreeMoments,
              BetaDecisionSignal.sawFirstProof,
            }),
          ],
        );
        expect(
          result.primaryRecommendation,
          BetaNextBuildRecommendation.improveProofEmotionalClarity,
        );
        expect(result.nextActionCopy, BetaDecisionCopy.nextImproveProofClarity);
      },
    );

    test('cares but will not pay recommends Pro packaging', () {
      final result = BetaDecisionEngine.build(
        outcomes: [
          _outcome('t1', {
            BetaDecisionSignal.understoodPromise,
            BetaDecisionSignal.savedFirstMoment,
            BetaDecisionSignal.returnedDay2,
            BetaDecisionSignal.reachedThreeMoments,
            BetaDecisionSignal.proofFeltMeaningful,
          }),
        ],
      );
      expect(
        result.primaryRecommendation,
        BetaNextBuildRecommendation.sharpenProPackaging,
      );
      expect(result.nextActionCopy, BetaDecisionCopy.nextSharpenProPackaging);
    });

    test(
      'asks for history/export/report after caring recommends Pro utility expansion',
      () {
        final result = BetaDecisionEngine.build(
          outcomes: [
            _outcome('t1', _caringWithUtilityAsk()),
            _outcome('t2', _caringWithUtilityAsk()),
            _outcome('t3', _caringWithUtilityAsk()),
          ],
        );
        expect(
          result.primaryRecommendation,
          BetaNextBuildRecommendation.expandProUtility,
        );
        expect(result.nextActionCopy, BetaDecisionCopy.nextExpandProUtility);
        expect(result.expansionAllowed, isTrue);
      },
    );

    test(
      'expansion blocked when users ask for reports but have not reached/cared about proof',
      () {
        final result = BetaDecisionEngine.build(
          outcomes: [
            _outcome('t1', {
              BetaDecisionSignal.understoodPromise,
              BetaDecisionSignal.savedFirstMoment,
              BetaDecisionSignal.returnedDay2,
              BetaDecisionSignal.askedForReport,
            }),
          ],
        );
        expect(
          result.primaryRecommendation,
          BetaNextBuildRecommendation.holdDoNotExpand,
        );
        expect(result.nextActionCopy, BetaDecisionCopy.holdDoNotExpand);
        expect(result.expansionAllowed, isFalse);
      },
    );

    test('priority order works when multiple signals exist', () {
      final result = BetaDecisionEngine.build(
        outcomes: [
          _outcome('misunderstood', {
            BetaDecisionSignal.misunderstoodAsChatbot,
          }),
          _outcome('capture', {
            BetaDecisionSignal.understoodPromise,
            BetaDecisionSignal.hesitatedAtCapture,
          }),
          _outcome('return', {
            BetaDecisionSignal.understoodPromise,
            BetaDecisionSignal.savedFirstMoment,
          }),
        ],
      );
      expect(
        result.primaryRecommendation,
        BetaNextBuildRecommendation.fixRecordOnboardingCopy,
      );
      expect(result.failingBranchCounts.length, greaterThan(1));
    });

    test('empty outcomes returns insufficient data', () {
      final result = BetaDecisionEngine.build(outcomes: const []);
      expect(
        result.primaryRecommendation,
        BetaNextBuildRecommendation.insufficientData,
      );
    });
  });

  group('BetaDecisionCopy safety', () {
    test(
      'copy contains no therapy/diagnosis/treatment/chatbot positioning',
      () {
        final blob = BetaDecisionCopy.allVisibleStrings()
            .join(' ')
            .toLowerCase();
        expect(blob, isNot(contains('therapy')));
        expect(blob, isNot(contains('diagnosis')));
        expect(blob, isNot(contains('treatment')));
        expect(blob, isNot(contains('chatbot')));
        for (final line in BetaDecisionCopy.allVisibleStrings()) {
          expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
        }
      },
    );
  });

  group('BETA_DECISION_SYSTEM doc', () {
    test('contains exact decision tree and interview questions', () {
      final doc = File('docs/BETA_DECISION_SYSTEM.md').readAsStringSync();
      for (final question in BetaTesterOutcomeChecklist.interviewQuestions) {
        expect(doc, contains(question));
      }
      expect(doc, contains('### A. Users do not understand the app'));
      expect(doc, contains('### B. Users understand but do not record'));
      expect(doc, contains('### C. Users record once but do not return'));
      expect(doc, contains('### D. Users reach proof but do not care'));
      expect(doc, contains('### E. Users care but will not pay'));
      expect(doc, contains('### F. Users ask for history/export/report'));
      expect(doc, contains('Fix Record/onboarding copy only'));
      expect(doc, contains('Fix capture friction'));
      expect(doc, contains('Expand Pro utility'));
      expect(
        doc,
        contains('Build only the **highest-priority failing branch**'),
      );
      expect(doc, contains('Do not build Ask Archive'));
      expect(doc.toLowerCase(), contains('20-person beta threshold'));
      expect(
        doc,
        contains(BetaTesterOutcomeChecklist.fivePersonRound.toString()),
      );
      expect(
        doc,
        contains(BetaTesterOutcomeChecklist.twentyPersonThreshold.toString()),
      );
    });
  });

  group('BetaNextBuildDecisionCard', () {
    testWidgets('hidden when beta mission gate is off', (
      WidgetTester tester,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: BetaNextBuildDecisionCard()),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('beta_next_build_decision_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('renders recommendation when beta mission enabled', (
      WidgetTester tester,
    ) async {
      final result = BetaDecisionEngine.build(
        outcomes: [
          _outcome('t1', {BetaDecisionSignal.misunderstoodAsTherapy}),
        ],
      );
      await _pumpCard(tester, result: result);
      expect(
        find.byKey(const Key('beta_next_build_decision_card')),
        findsOneWidget,
      );
      expect(
        find.text(BetaDecisionCopy.nextFixRecordOnboarding),
        findsOneWidget,
      );
    });

    test('testing screen includes beta outcome log and decision cards', () {
      final source = File(
        'lib/screens/testing_archiveme_screen.dart',
      ).readAsStringSync();
      expect(source, contains('BetaNextBuildDecisionCard'));
      expect(source, contains('BetaTesterOutcomeLogCard'));
      expect(source, contains('BetaTesterOutcomeStore'));
    });
  });
}

Set<BetaDecisionSignal> _caringWithUtilityAsk() => {
  BetaDecisionSignal.understoodPromise,
  BetaDecisionSignal.savedFirstMoment,
  BetaDecisionSignal.returnedDay2,
  BetaDecisionSignal.reachedThreeMoments,
  BetaDecisionSignal.proofFeltMeaningful,
  BetaDecisionSignal.willingToPayForLongerTrail,
  BetaDecisionSignal.askedForExport,
};
