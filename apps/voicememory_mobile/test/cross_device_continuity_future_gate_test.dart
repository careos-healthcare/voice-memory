import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/cross_device_continuity_future/cross_device_continuity_future_copy.dart';
import 'package:voicememory_mobile/features/cross_device_continuity_future/cross_device_continuity_future_gate.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/CROSS_DEVICE_CONTINUITY_FUTURE.md';

CrossDeviceContinuityFutureGateInput _input({
  bool? accountIdentityProof = true,
  bool? restoreProof = true,
  bool? backupProof = true,
  bool? privacyProof = true,
  bool? migrationProof = true,
  bool? v1ContinuitySurfacingRequested,
}) => CrossDeviceContinuityFutureGateInput(
  accountIdentityProof: accountIdentityProof,
  restoreProof: restoreProof,
  backupProof: backupProof,
  privacyProof: privacyProof,
  migrationProof: migrationProof,
  v1ContinuitySurfacingRequested: v1ContinuitySurfacingRequested,
);

CrossDeviceContinuityFuturePrereq _prereq(
  CrossDeviceContinuityFutureGateResult result,
  CrossDeviceContinuityFuturePrereqId id,
) => result.prereqs.firstWhere((prereq) => prereq.id == id);

CrossDeviceContinuityFutureRule _rule(
  CrossDeviceContinuityFutureGateResult result,
  CrossDeviceContinuityFutureRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('CrossDeviceContinuityFutureGate.build', () {
    test('gate tracks five rules and five prerequisites in order', () {
      final result = CrossDeviceContinuityFutureGate.build(_input());
      expect(result.rules.length, CrossDeviceContinuityFutureGate.ruleCount);
      expect(
        result.prereqs.length,
        CrossDeviceContinuityFutureGate.prereqCount,
      );
      expect(
        result.ruleOrder,
        CrossDeviceContinuityFutureGate.canonicalRuleOrder,
      );
      expect(
        result.prereqOrder,
        CrossDeviceContinuityFutureGate.canonicalPrereqOrder,
      );
    });

    test('technical proof complete -> futureContinuityDocumented', () {
      final result = CrossDeviceContinuityFutureGate.build(_input());
      expect(
        result.decision,
        CrossDeviceContinuityFutureGateDecision.futureContinuityDocumented,
      );
      expect(result.technicalProofComplete, isTrue);
      expect(result.v1SurfacingBlocked, isFalse);
      expect(result.cloudPromiseBlocked, isTrue);
      expect(result.accessEverywherePromiseBlocked, isTrue);
      expect(result.neverLoseArchivePromiseBlocked, isTrue);
      expect(result.earliestPrereqGap, isNull);
      expect(result.earliestRuleFailure, isNull);
    });

    test('pending migration proof -> continuityFrozen', () {
      final result = CrossDeviceContinuityFutureGate.build(
        _input(migrationProof: null),
      );
      expect(
        result.decision,
        CrossDeviceContinuityFutureGateDecision.continuityFrozen,
      );
      expect(
        result.earliestPrereqGap,
        CrossDeviceContinuityFuturePrereqId.migrationProof,
      );
      expect(
        _prereq(
          result,
          CrossDeviceContinuityFuturePrereqId.migrationProof,
        ).status,
        CrossDeviceContinuityFuturePrereqStatus.pending,
      );
    });

    test('missing backup proof fails technicalProofBeforeLaunch', () {
      final result = CrossDeviceContinuityFutureGate.build(
        _input(backupProof: false),
      );
      expect(
        _rule(
          result,
          CrossDeviceContinuityFutureRuleId.technicalProofBeforeLaunch,
        ).status,
        CrossDeviceContinuityFutureRuleStatus.fail,
      );
      expect(
        result.decision,
        CrossDeviceContinuityFutureGateDecision.continuityFrozen,
      );
    });

    test('v1 surfacing requested without proof fails futureOnly', () {
      final result = CrossDeviceContinuityFutureGate.build(
        _input(migrationProof: false, v1ContinuitySurfacingRequested: true),
      );
      expect(
        _rule(result, CrossDeviceContinuityFutureRuleId.futureOnly).status,
        CrossDeviceContinuityFutureRuleStatus.fail,
      );
    });

    test('canonical rules pass for gate copy', () {
      final result = CrossDeviceContinuityFutureGate.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          CrossDeviceContinuityFutureRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects cloud backup promise copy', () {
      expect(
        CrossDeviceContinuityFutureGate.evaluateCopyPassesRules(
          'Automatic cloud backup keeps your archive safe.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects access everywhere promise copy', () {
      expect(
        CrossDeviceContinuityFutureGate.evaluateCopyPassesRules(
          'Access everywhere with Pro.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects never lose archive promise copy', () {
      expect(
        CrossDeviceContinuityFutureGate.evaluateCopyPassesRules(
          'You will never lose your archive.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = CrossDeviceContinuityFutureGate.report(
        CrossDeviceContinuityFutureGate.build(_input()),
      );
      expect(report.headline, CrossDeviceContinuityFutureCopy.headline);
      expect(report.positioning, CrossDeviceContinuityFutureCopy.positioning);
      expect(report.guardrail, CrossDeviceContinuityFutureCopy.guardrail);
    });
  });

  group('CrossDeviceContinuityFutureGate.composeInput', () {
    test('bridges launch checklist restore and privacy proof', () {
      final input = CrossDeviceContinuityFutureGate.composeInput(
        accountIdentityProof: true,
        backupProof: true,
        migrationProof: true,
        launchChecklist: const SingleLaunchChecklistInput(
          productionApiWorks: true,
          restoreWorks: true,
          supportPrivacyTermsWork: true,
        ),
      );
      expect(input.restoreProof, isTrue);
      expect(input.privacyProof, isTrue);
      expect(input.accountIdentityProof, isTrue);
    });
  });

  group('CrossDeviceContinuityFutureGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;
    late String syncGuardSource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/cross_device_continuity_future/cross_device_continuity_future_copy.dart',
      ).readAsStringSync();
      syncGuardSource = File(
        'lib/features/sync_expectation_safety/sync_expectation_safety_guard.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(
        CrossDeviceContinuityFutureGate.detectDocListsRules(docsSource),
        isTrue,
      );
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        CrossDeviceContinuityFutureGate.detectGuardrailPresentInCopy(
          gateCopySource,
        ),
        isTrue,
      );
    });

    test('detectSyncExpectationSafetyAligned matches sync guard', () {
      expect(
        CrossDeviceContinuityFutureGate.detectSyncExpectationSafetyAligned(
          syncGuardSource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to continuityFrozen', () {
      final result = CrossDeviceContinuityFutureGate.build(
        CrossDeviceContinuityFutureGate.fromRepoSignals(
          crossDeviceContinuityFutureDocSource: docsSource,
          gateCopySource: gateCopySource,
          syncExpectationSafetyGuardSource: syncGuardSource,
        ),
      );
      expect(
        result.decision,
        CrossDeviceContinuityFutureGateDecision.continuityFrozen,
      );
    });
  });

  group('protected regression', () {
    test('docs describe future continuity scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('cross device continuity'));
      expect(doc, contains('future only'));
      expect(doc, contains('no cloud backup promise'));
      expect(doc, contains('no access everywhere promise'));
      expect(doc, contains('never lose your archive'));
      expect(doc, contains('migration proof'));
    });

    test('guardrail blocks cloud and sync promises', () {
      final guardrail = CrossDeviceContinuityFutureCopy.guardrail.toLowerCase();
      expect(guardrail, contains('future only'));
      expect(guardrail, contains('no cloud backup promise'));
      expect(guardrail, contains('no access everywhere promise'));
      expect(guardrail, contains('no never lose your archive promise'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in CrossDeviceContinuityFutureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import paywall or sync backend', () {
      for (final path in [
        'lib/features/cross_device_continuity_future/cross_device_continuity_future_gate.dart',
        'lib/features/cross_device_continuity_future/cross_device_continuity_future_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('sync_service.dart'), isFalse);
        expect(source.contains('cloud_backup_service.dart'), isFalse);
      }
    });

    test('advice guard registers cross device continuity future copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('CrossDeviceContinuityFutureCopy.allVisibleStrings()'),
      );
    });
  });
}
