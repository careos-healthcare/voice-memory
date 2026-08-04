import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/freeze_drift_scanner/freeze_drift_scanner.dart';
import 'package:voicememory_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_copy.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/widget_release_risk/widget_release_risk_gate.dart';
import 'package:voicememory_mobile/features/widget_release_risk/widget_release_risk_gate_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

const _docsPath = 'docs/widget_release_risk_gate.md';

WidgetReleaseRiskGateInput _input({
  bool extensionTargetPresent = false,
  bool appGroupConfigured = true,
  bool widgetOpensCorrectRoute = true,
  bool noPrivateTranscriptShown = true,
  bool testFlightInstallWorks = true,
  bool signingPasses = true,
  bool noCrashOnLaunch = true,
  bool noStaleBrokenDefaultState = true,
}) => WidgetReleaseRiskGateInput(
  extensionTargetPresent: extensionTargetPresent,
  appGroupConfigured: appGroupConfigured,
  widgetOpensCorrectRoute: widgetOpensCorrectRoute,
  noPrivateTranscriptShown: noPrivateTranscriptShown,
  testFlightInstallWorks: testFlightInstallWorks,
  signingPasses: signingPasses,
  noCrashOnLaunch: noCrashOnLaunch,
  noStaleBrokenDefaultState: noStaleBrokenDefaultState,
);

WidgetReleaseRiskGateCheck _check(
  WidgetReleaseRiskGateResult result,
  WidgetReleaseRiskGateCheckId id,
) => result.checks.firstWhere((check) => check.id == id);

void main() {
  group('WidgetReleaseRiskGate.build', () {
    test('gate has eight canonical checks', () {
      final result = WidgetReleaseRiskGate.build(_input());
      expect(result.checks.length, WidgetReleaseRiskGate.checkCount);
      expect(result.checks.map((check) => check.id).toList(), [
        WidgetReleaseRiskGateCheckId.extensionTargetPresent,
        WidgetReleaseRiskGateCheckId.appGroupConfigured,
        WidgetReleaseRiskGateCheckId.widgetOpensCorrectRoute,
        WidgetReleaseRiskGateCheckId.noPrivateTranscriptShown,
        WidgetReleaseRiskGateCheckId.testFlightInstallWorks,
        WidgetReleaseRiskGateCheckId.signingPasses,
        WidgetReleaseRiskGateCheckId.noCrashOnLaunch,
        WidgetReleaseRiskGateCheckId.noStaleBrokenDefaultState,
      ]);
    });

    test(
      'missing extension target -> widgetDisableForRelease not TF blocker',
      () {
        final result = WidgetReleaseRiskGate.build(_input());
        expect(
          result.decision,
          WidgetReleaseRiskGateDecision.widgetDisableForRelease,
        );
        expect(result.testFlightBlockedByWidget, isFalse);
        expect(result.widgetShouldBeDisabled, isTrue);
        expect(
          _check(
            result,
            WidgetReleaseRiskGateCheckId.extensionTargetPresent,
          ).detailLabel,
          WidgetReleaseRiskGateCopy.detailDefer,
        );
      },
    );

    test('extension present with signing failure -> widgetBlocksRelease', () {
      final result = WidgetReleaseRiskGate.build(
        _input(extensionTargetPresent: true, signingPasses: false),
      );
      expect(
        result.decision,
        WidgetReleaseRiskGateDecision.widgetBlocksRelease,
      );
      expect(result.testFlightBlockedByWidget, isTrue);
    });

    test('extension present with launch crash -> widgetBlocksRelease', () {
      final result = WidgetReleaseRiskGate.build(
        _input(extensionTargetPresent: true, noCrashOnLaunch: false),
      );
      expect(
        result.decision,
        WidgetReleaseRiskGateDecision.widgetBlocksRelease,
      );
    });

    test(
      'extension present but App Group missing -> widgetDisableForRelease',
      () {
        final result = WidgetReleaseRiskGate.build(
          _input(extensionTargetPresent: true, appGroupConfigured: false),
        );
        expect(
          result.decision,
          WidgetReleaseRiskGateDecision.widgetDisableForRelease,
        );
        expect(result.testFlightBlockedByWidget, isFalse);
      },
    );

    test(
      'extension configured but route policy fails -> manual Xcode check',
      () {
        final result = WidgetReleaseRiskGate.build(
          _input(extensionTargetPresent: true, widgetOpensCorrectRoute: false),
        );
        expect(
          result.decision,
          WidgetReleaseRiskGateDecision.widgetNeedsManualXcodeCheck,
        );
        expect(result.testFlightBlockedByWidget, isFalse);
      },
    );

    test('all checks pass with extension present -> widgetSafe', () {
      final result = WidgetReleaseRiskGate.build(
        _input(extensionTargetPresent: true),
      );
      expect(result.decision, WidgetReleaseRiskGateDecision.widgetSafe);
      expect(result.widgetShouldBeDisabled, isFalse);
      expect(result.earliestRisk, isNull);
    });

    test('signing failure without extension does not block TestFlight', () {
      final result = WidgetReleaseRiskGate.build(_input(signingPasses: false));
      expect(
        result.decision,
        WidgetReleaseRiskGateDecision.widgetDisableForRelease,
      );
      expect(result.testFlightBlockedByWidget, isFalse);
    });
  });

  group('WidgetReleaseRiskGate.fromRepoSignals', () {
    late String pbxproj;
    late String runnerEntitlements;
    late String extensionEntitlements;
    late String objectiveStorage;
    late String todayCheckWidget;
    late String widgetExporter;
    late String widgetPrep;

    setUpAll(() {
      pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      runnerEntitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      extensionEntitlements = File(
        'ios/ArchiveMeWidgets/ArchiveMeWidgets.entitlements',
      ).readAsStringSync();
      objectiveStorage = File(
        'ios/Runner/ObjectiveWidgetStorage.swift',
      ).readAsStringSync();
      todayCheckWidget = File(
        'ios/SharedIntegration/SecureAppGroupStore.swift',
      ).readAsStringSync();
      widgetExporter = File(
        'lib/features/objective/current_objective_widget_exporter.dart',
      ).readAsStringSync();
      widgetPrep = File('docs/WIDGET_SHORTCUT_PREP.md').readAsStringSync();
    });

    test('repo signals detect active ArchiveMeWidgets target', () {
      expect(
        WidgetReleaseRiskGate.detectExtensionTargetPresent(pbxproj),
        isTrue,
      );
      final result = WidgetReleaseRiskGate.build(
        WidgetReleaseRiskGate.fromRepoSignals(
          pbxprojContents: pbxproj,
          runnerEntitlements: runnerEntitlements,
          extensionEntitlements: extensionEntitlements,
          objectiveWidgetStorageSwift: objectiveStorage,
          todayCheckWidgetSwift: todayCheckWidget,
          widgetExporterDart: widgetExporter,
          widgetPrepDoc: widgetPrep,
        ),
      );
      expect(result.decision, WidgetReleaseRiskGateDecision.widgetSafe);
    });

    test('repo signals detect App Group parity', () {
      expect(
        WidgetReleaseRiskGate.detectAppGroupConfigured(
          runnerEntitlements: runnerEntitlements,
          extensionEntitlements: extensionEntitlements,
          objectiveWidgetStorageSwift: objectiveStorage,
          todayCheckWidgetSwift: todayCheckWidget,
        ),
        isTrue,
      );
    });

    test('repo signals detect /record default route', () {
      expect(
        WidgetReleaseRiskGate.detectWidgetOpensCorrectRoute(widgetExporter),
        isTrue,
      );
    });

    test('report exposes canonical copy', () {
      final report = WidgetReleaseRiskGate.report(
        WidgetReleaseRiskGate.build(_input()),
      );
      expect(report.headline, WidgetReleaseRiskGateCopy.headline);
      expect(report.guardrail, WidgetReleaseRiskGateCopy.guardrail);
    });
  });

  group('WidgetReleaseRiskGateCopy', () {
    test('guardrail blocks new widget features sizes analytics', () {
      expect(
        WidgetReleaseRiskGateCopy.guardrail.toLowerCase(),
        contains('do not add widget'),
      );
      expect(
        WidgetReleaseRiskGateCopy.guardrail.toLowerCase(),
        contains('analytics'),
      );
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in WidgetReleaseRiskGateCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });

    test('docs file exists and references decisions', () {
      final docs = File(_docsPath).readAsStringSync();
      expect(docs.toLowerCase(), contains('testflight'));
      expect(docs, contains('widgetDisableForRelease'));
      expect(docs.toLowerCase(), contains('app group'));
    });
  });

  group('Protected areas', () {
    test('module does not import widget SDKs or analytics', () {
      for (final path in [
        'lib/features/widget_release_risk/widget_release_risk_gate.dart',
        'lib/features/widget_release_risk/widget_release_risk_gate_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('WidgetKit'), isFalse);
        expect(source.contains('AppWidgetProvider'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('purchases_flutter'), isFalse);
      }
    });

    test('validate_core.sh includes widget release risk gate bundle', () {
      final source = File('tool/validate_core.sh').readAsStringSync();
      expect(source, contains('run_widget_release_risk_gate.sh'));
    });

    test('freeze drift scanner still blocks risky drift during freeze', () {
      final result = FreezeDriftScanner.scan(
        const FreezeDriftScannerInput(
          freezeActive: true,
          category: FreezeDriftCategory.newDashboard,
        ),
      );
      expect(result.decision, FreezeDriftDecision.blocked);
    });

    test('pro access enforcement audit regressions unchanged', () {
      expect(ProAccessEnforcementAuditCopy.headline, isNotEmpty);
    });

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
      expect(
        ProofDetailRepairCopy.whyThisOneLine,
        contains('clearest specific repeat'),
      );
    });

    test(
      'record screen remains capture-first without stacking extra cards',
      () {
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
      },
    );
  });
}
