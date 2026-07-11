import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/action_items_v1_gate/action_items_v1_secondary_gate.dart';
import 'package:voicememory_mobile/features/action_items_v1_gate/action_items_v1_secondary_gate_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/no_dashboard_positioning/no_dashboard_positioning_guard.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/features/product_language_consistency/product_language_consistency_guard.dart';
import 'package:voicememory_mobile/features/product_language_consistency/product_language_consistency_guard_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/proof_trail_positioning/proof_trail_positioning.dart';
import 'package:voicememory_mobile/features/pro_single_promise/pro_single_promise_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

void main() {
  group('ProductLanguageConsistencyGuard.evaluate', () {
    test('proof trail language preferred', () {
      const copy = 'Save one repeat. One sentence is enough. ArchiveMe compares later.';
      final result = ProductLanguageConsistencyGuard.evaluate(copy);
      expect(result.action, ProductLanguageConsistencyAction.preferredAligned);
      expect(
        ProductLanguageConsistencyGuard.containsPreferredProofTrailLanguage(copy),
        isTrue,
      );
    });

    test('longer proof trail language preferred', () {
      const copy = 'Pro keeps the longer proof trail as repeats return, change, or fade.';
      final result = ProductLanguageConsistencyGuard.evaluate(copy);
      expect(result.action, ProductLanguageConsistencyAction.preferredAligned);
    });

    test('full timeline blocked', () {
      final result = ProductLanguageConsistencyGuard.evaluate(
        'Pro keeps the full timeline as it grows.',
      );
      expect(result.action, ProductLanguageConsistencyAction.highRiskBlocked);
      expect(result.reason, ProductLanguageConsistencyReason.blockedFullTimeline);
    });

    test('longer story blocked', () {
      final result = ProductLanguageConsistencyGuard.evaluate(
        'ArchiveMe tells your longer story over time.',
      );
      expect(result.action, ProductLanguageConsistencyAction.highRiskBlocked);
      expect(result.reason, ProductLanguageConsistencyReason.blockedLongerStory);
    });

    test('dashboard positioning blocked', () {
      final result = ProductLanguageConsistencyGuard.evaluate(
        'ArchiveMe is your life dashboard.',
      );
      expect(result.action, ProductLanguageConsistencyAction.highRiskBlocked);
      expect(result.reason, ProductLanguageConsistencyReason.blockedDashboard);
    });

    test('second brain blocked', () {
      final result = ProductLanguageConsistencyGuard.evaluate(
        'Build your second brain inside ArchiveMe.',
      );
      expect(result.action, ProductLanguageConsistencyAction.highRiskBlocked);
      expect(result.reason, ProductLanguageConsistencyReason.blockedSecondBrain);
    });

    test('storage promise blocked', () {
      final result = ProductLanguageConsistencyGuard.evaluate(
        'Upgrade for unlimited storage and backup.',
      );
      expect(result.action, ProductLanguageConsistencyAction.highRiskBlocked);
      expect(result.reason, ProductLanguageConsistencyReason.blockedStorage);
    });

    test('full pattern timeline warns', () {
      final result = ProductLanguageConsistencyGuard.evaluate(
        'Unlock the full pattern timeline with Pro.',
      );
      expect(result.action, ProductLanguageConsistencyAction.riskyLanguageWarn);
      expect(result.reason, ProductLanguageConsistencyReason.warnedFullTimeline);
    });

    test('monthly private report warns', () {
      final result = ProductLanguageConsistencyGuard.evaluate(
        'Pro includes a monthly private report.',
      );
      expect(
        result.action,
        ProductLanguageConsistencyAction.riskyLanguageWarn,
      );
      expect(
        result.reason,
        ProductLanguageConsistencyReason.warnedReportPrimaryValue,
      );
    });

    test('anti-risk instructional copy allowed', () {
      expect(
        ProductLanguageConsistencyGuard.evaluate(
          ProSinglePromiseCopy.notStorageLine,
        ).action,
        ProductLanguageConsistencyAction.preferredAligned,
      );
      expect(
        ProductLanguageConsistencyGuard.evaluate(
          ProductLanguageConsistencyGuardCopy.riskyLanguageLine,
        ).action,
        ProductLanguageConsistencyAction.preferredAligned,
      );
    });
  });

  group('High-risk surface scans', () {
    test('first journey copy passes guard', () {
      final offenders = <String>[];
      for (final text in ProductLanguageConsistencyGuard.firstJourneyCopyBlocks()) {
        if (!ProductLanguageConsistencyGuard.passesFirstJourney(text)) {
          offenders.add(text);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('pro promise copy passes guard', () {
      final offenders = <String>[];
      for (final text in ProductLanguageConsistencyGuard.proPromiseCopyBlocks()) {
        if (!ProductLanguageConsistencyGuard.passesProPromise(text)) {
          offenders.add(text);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('paywall alignment bullets use proof-trail language', () {
      for (final bullet in PaywallAlignmentCopy.benefitBullets) {
        expect(
          ProductLanguageConsistencyGuard.passesProPromise(bullet),
          isTrue,
          reason: bullet,
        );
      }
    });
  });

  group('ProductLanguageConsistencyGuardCopy', () {
    test('preferredLanguageLine includes proof trail phrases', () {
      final line =
          ProductLanguageConsistencyGuardCopy.preferredLanguageLine.toLowerCase();
      expect(line, contains('repeat'));
      expect(line, contains('proof trail'));
      expect(line, contains('longer proof trail'));
      expect(line, contains('one sentence'));
      expect(line, contains('compares later'));
    });

    test('riskyLanguageLine lists dashboard story storage language', () {
      final line =
          ProductLanguageConsistencyGuardCopy.riskyLanguageLine.toLowerCase();
      expect(line, contains('full timeline'));
      expect(line, contains('longer story'));
      expect(line, contains('dashboard'));
      expect(line, contains('storage'));
      expect(line, contains('second brain'));
    });

    test('guardrail says copy guard only', () {
      expect(
        ProductLanguageConsistencyGuardCopy.guardrail,
        contains('Copy guard only'),
      );
      expect(
        ProductLanguageConsistencyGuardCopy.guardrail,
        contains('No new features'),
      );
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text
          in ProductLanguageConsistencyGuardCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements', () {
      for (final path in [
        'lib/features/product_language_consistency/product_language_consistency_guard.dart',
        'lib/features/product_language_consistency/product_language_consistency_guard_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('proof_surface_advice_guard registers product language consistency copy', () {
      final source =
          File('lib/features/archive_proof/proof_surface_advice_guard.dart')
              .readAsStringSync();
      expect(source, contains('product_language_consistency_guard_copy.dart'));
      expect(
        source,
        contains('ProductLanguageConsistencyGuardCopy.allVisibleStrings()'),
      );
    });

    test('validate_core.sh includes product language consistency guard bundle', () {
      final source = File('tool/validate_core.sh').readAsStringSync();
      expect(source, contains('run_product_language_consistency_guard.sh'));
    });

    test('action items secondary gate regressions unchanged', () {
      expect(
        ActionItemsV1SecondaryGate.evaluateCopy(
          'Save one repeat when something stands out.',
        ).action,
        ActionItemsV1SecondaryGateCopyAction.allowed,
      );
    });

    test('no dashboard positioning guard regressions unchanged', () {
      expect(
        NoDashboardPositioningGuard.evaluate(
          'ArchiveMe keeps your proof trail over time.',
        ).action,
        NoDashboardPositioningGuardAction.allowed,
      );
    });

    test('proof trail positioning still blocks dashboard maintenance', () {
      expect(
        ProofTrailPositioning.resolve(
          const ProofTrailPositioningInput(
            userThinksChatBox: false,
            userThinksStorageApp: false,
            userThinksSecondBrain: false,
            userThinksDashboardToMaintain: true,
            userUnderstandsProofTrail: true,
            userUnderstandsMeaningfulResurfacing: true,
            userUnderstandsSaveARepeat: true,
            userUnderstandsLowEffort: true,
            wouldPayYes: true,
            wouldPayMaybe: false,
          ),
        ).decision,
        ProofTrailPositioningDecision.clarifyNotDashboard,
      );
    });

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
    });

    test('record screen remains capture-first without stacking extra cards', () {
      final audit = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
          archiveTimelineSpine: false,
          timelinePositioning: false,
          currentRelevance: false,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
          betaProofLift: true,
        ),
      );
      expect(audit.proofCardKey, 'timelineProofMoment');
      expect(audit.guidanceCardKey, isNull);
    });
  });
}
